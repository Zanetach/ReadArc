#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ReadArc"
PRODUCT_NAME="ReadArc"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
PDF_DIR="$DIST_DIR/stress-pdfs"
REPORT_DIR="$DIST_DIR/stress-reports"
SAMPLE_SECONDS=20
CASES="text100,text500,text1000,chinese100,chinese500,chinese1000,scan100,scan500,image100"
GENERATE_ONLY=0
SKIP_BUILD=0
EXTERNAL_PDFS=()

usage() {
  cat <<USAGE
usage: $0 [options]

Options:
  --cases LIST          Comma-separated cases: text100,text500,text1000,chinese100,chinese500,chinese1000,scan100,scan500,image100,mixed300
  --sample-seconds N   Seconds to sample RSS after opening each PDF. Default: 20
  --generate-only      Generate stress PDFs without launching ReadArc
  --skip-build         Reuse dist/ReadArc.app instead of rebuilding it
  --pdf PATH           Also sample a real PDF file. Can be passed more than once
  --help               Show this help

Reports are written to dist/stress-reports/.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cases)
      CASES="${2:?missing --cases value}"
      shift 2
      ;;
    --sample-seconds)
      SAMPLE_SECONDS="${2:?missing --sample-seconds value}"
      shift 2
      ;;
    --generate-only)
      GENERATE_ONLY=1
      shift
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    --pdf)
      EXTERNAL_PDFS+=("${2:?missing --pdf value}")
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! [[ "$SAMPLE_SECONDS" =~ ^[0-9]+$ ]] || [[ "$SAMPLE_SECONDS" -lt 1 ]]; then
  echo "--sample-seconds must be a positive integer" >&2
  exit 2
fi

mkdir -p "$PDF_DIR" "$REPORT_DIR"

generate_pdfs() {
  /usr/bin/python3 - "$PDF_DIR" "$CASES" <<'PY'
import math
import os
import sys

out_dir = sys.argv[1]
requested = {case.strip() for case in sys.argv[2].split(",") if case.strip()}

CASE_SPECS = {
    "text100": ("readarc-text-100.pdf", 100, "text"),
    "text500": ("readarc-text-500.pdf", 500, "text"),
    "text1000": ("readarc-text-1000.pdf", 1000, "text"),
    "scan100": ("readarc-scan-like-100.pdf", 100, "scan"),
    "scan200": ("readarc-scan-like-200.pdf", 200, "scan"),
    "scan500": ("readarc-scan-like-500.pdf", 500, "scan"),
    "image100": ("readarc-image-100.pdf", 100, "image"),
    "mixed300": ("readarc-mixed-300.pdf", 300, "mixed"),
}

CHINESE_CASES = {"chinese100", "chinese500", "chinese1000"}
python_requested = requested - CHINESE_CASES
unknown = sorted(python_requested - set(CASE_SPECS))
if unknown:
    raise SystemExit(f"unknown cases: {', '.join(unknown)}")

os.makedirs(out_dir, exist_ok=True)

def pdf_escape(text):
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

def text_stream(page_index, line_count=48):
    lines = ["q", "BT", "/F1 8 Tf", "1 0 0 1 42 760 Tm", "10 TL"]
    for line in range(line_count):
        section = (page_index % 17) + 1
        payload = (
            f"ReadArc stress text page {page_index + 1:04d}, section {section:02d}, "
            f"line {line + 1:02d}. PDFKit extraction, search, selection, and rendering sample."
        )
        lines.append(f"({pdf_escape(payload)}) Tj")
        lines.append("T*")
    lines.extend(["ET", "Q"])
    return "\n".join(lines).encode("ascii")

def scan_stream(page_index):
    lines = [
        "q",
        "0.96 g 32 32 548 728 re f",
        "0.88 g 48 710 512 18 re f",
        "0.82 G 0.6 w",
    ]
    for row in range(36):
        y = 690 - row * 18
        wobble = math.sin((page_index + 1) * (row + 3)) * 8
        width = 410 + ((row * 37 + page_index * 11) % 95)
        lines.append(f"52 {y:.1f} m {52 + width + wobble:.1f} {y + 0.7:.1f} l S")
        if row % 4 == 0:
            block_x = 64 + ((page_index * 13 + row * 7) % 80)
            lines.append(f"0.78 g {block_x:.1f} {y - 8:.1f} 118 8 re f")
            lines.append("0.82 G")
    for mark in range(8):
        x = 55 + ((page_index * 19 + mark * 43) % 460)
        y = 62 + ((page_index * 23 + mark * 59) % 620)
        shade = 0.70 + (mark % 3) * 0.06
        lines.append(f"{shade:.2f} g {x:.1f} {y:.1f} 3 3 re f")
    lines.append("Q")
    return "\n".join(lines).encode("ascii")

def mixed_stream(page_index):
    if page_index % 3 == 0:
        return scan_stream(page_index)
    return text_stream(page_index, line_count=34)

def image_stream(page_index):
    lines = [
        "q",
        "0.98 g 28 28 556 736 re f",
        "0.78 0 0 0.78 108 242 cm /Im1 Do",
        "Q",
        "q",
        "0.20 G 1.4 w 108 242 360 360 re S",
        "0.56 g 128 620 320 18 re f",
        "0.72 g 128 594 248 10 re f",
        "0.82 g 128 570 276 10 re f",
        "Q",
        "BT /F1 11 Tf 1 0 0 1 128 188 Tm",
        f"(ReadArc image PDF stress page {page_index + 1:04d}) Tj",
        "ET",
    ]
    return "\n".join(lines).encode("ascii")

def content_for(kind, page_index):
    if kind == "text":
        return text_stream(page_index)
    if kind == "scan":
        return scan_stream(page_index)
    if kind == "image":
        return image_stream(page_index)
    return mixed_stream(page_index)

def image_xobject():
    width = 96
    height = 96
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            r = int(88 + 92 * (x / max(1, width - 1)))
            g = int(118 + 82 * (y / max(1, height - 1)))
            b = int(144 + 68 * ((x + y) / max(1, width + height - 2)))
            if 28 < x < 68 and 28 < y < 68:
                r, g, b = 170, 218, 126
            pixels.extend([r, g, b])
    encoded = pixels.hex().upper().encode("ascii") + b">"
    return (
        f"<< /Type /XObject /Subtype /Image /Width {width} /Height {height} "
        f"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /ASCIIHexDecode "
        f"/Length {len(encoded)} >>\nstream\n"
    ).encode("ascii") + encoded + b"\nendstream"

def write_pdf(path, page_count, kind):
    objects = []
    pages_id = 2
    font_id = 3
    page_ids = []

    objects.append(b"<< /Type /Catalog /Pages 2 0 R >>")
    objects.append(None)
    objects.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    image_id = None

    if kind == "image":
        image_id = len(objects) + 1
        objects.append(image_xobject())

    for page_index in range(page_count):
        content_id = len(objects) + 2
        page_id = len(objects) + 1
        page_ids.append(page_id)
        resources = f"<< /Font << /F1 {font_id} 0 R >>"
        if image_id is not None:
            resources += f" /XObject << /Im1 {image_id} 0 R >>"
        resources += " >>"
        page = (
            f"<< /Type /Page /Parent {pages_id} 0 R /MediaBox [0 0 612 792] "
            f"/Resources {resources} "
            f"/Contents {content_id} 0 R >>"
        ).encode("ascii")
        stream = content_for(kind, page_index)
        content = (
            f"<< /Length {len(stream)} >>\nstream\n".encode("ascii")
            + stream
            + b"\nendstream"
        )
        objects.append(page)
        objects.append(content)

    kids = " ".join(f"{page_id} 0 R" for page_id in page_ids)
    objects[1] = f"<< /Type /Pages /Kids [{kids}] /Count {page_count} >>".encode("ascii")

    offsets = [0]
    with open(path, "wb") as handle:
        handle.write(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        for object_id, body in enumerate(objects, start=1):
            offsets.append(handle.tell())
            handle.write(f"{object_id} 0 obj\n".encode("ascii"))
            handle.write(body)
            handle.write(b"\nendobj\n")
        xref_offset = handle.tell()
        handle.write(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
        handle.write(b"0000000000 65535 f \n")
        for offset in offsets[1:]:
            handle.write(f"{offset:010d} 00000 n \n".encode("ascii"))
        handle.write(
            (
                f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
                f"startxref\n{xref_offset}\n%%EOF\n"
            ).encode("ascii")
        )

for case in sorted(python_requested):
    filename, page_count, kind = CASE_SPECS[case]
    path = os.path.join(out_dir, filename)
    write_pdf(path, page_count, kind)
    size_mb = os.path.getsize(path) / 1024 / 1024
    print(f"{case}: {path} ({page_count} pages, {size_mb:.2f} MB)")
PY

  if [[ "$CASES" == *chinese* ]]; then
    /usr/bin/swift - "$PDF_DIR" "$CASES" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let requested = Set(CommandLine.arguments[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
let specs: [String: (String, Int)] = [
    "chinese100": ("readarc-chinese-dense-100.pdf", 100),
    "chinese500": ("readarc-chinese-dense-500.pdf", 500),
    "chinese1000": ("readarc-chinese-dense-1000.pdf", 1000)
]

let paragraph = """
ReadArc 中文文本密集压测：这一页包含连续中文段落、数字、英文术语、标点符号和长句，用于验证 PDFKit 渲染、文本提取、搜索、缩略图生成、分页缓存和 Agent 上下文摘要的稳定性。章节：客户需求、验收标准、权限配置、报价流程、项目交付、风险说明、会议纪要、版本记录。
"""

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
    .foregroundColor: NSColor.black
]
let bodyAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 8),
    .foregroundColor: NSColor.black
]

func draw(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
    (text as NSString).draw(in: rect, withAttributes: attributes)
}

func writeChinesePDF(path: URL, pageCount: Int) throws {
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(path as CFURL, mediaBox: &mediaBox, nil) else {
        throw NSError(domain: "ReadArcStress", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create PDF context"])
    }

    for pageIndex in 0..<pageCount {
        autoreleasepool {
            context.beginPDFPage(nil)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

            NSColor.white.setFill()
            CGRect(x: 0, y: 0, width: 612, height: 792).fill()

            draw("ReadArc 中文文本密集 PDF - 第 \(pageIndex + 1) / \(pageCount) 页", in: CGRect(x: 42, y: 748, width: 528, height: 24), attributes: titleAttributes)

            var y = 708.0
            for line in 0..<52 {
                let text = "\(String(format: "%03d", line + 1))  \(paragraph) 当前页：\(pageIndex + 1)，段落：\(line + 1)。"
                draw(text, in: CGRect(x: 42, y: y, width: 528, height: 13), attributes: bodyAttributes)
                y -= 13
            }

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
    }

    context.closePDF()
}

for (caseName, spec) in specs where requested.contains(caseName) {
    let path = outputDirectory.appendingPathComponent(spec.0)
    try writeChinesePDF(path: path, pageCount: spec.1)
    let size = ((try? FileManager.default.attributesOfItem(atPath: path.path)[.size] as? NSNumber)?.doubleValue ?? 0) / 1024 / 1024
    print("\(caseName): \(path.path) (\(spec.1) pages, \(String(format: "%.2f", size)) MB)")
}
SWIFT
  fi
}

build_app() {
  if [[ "$SKIP_BUILD" -eq 1 && -x "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME" ]]; then
    return
  fi

  "$ROOT_DIR/script/build_and_run.sh" --verify >/dev/null
  /usr/bin/pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true
}

app_pid() {
  /usr/bin/pgrep -x "$PRODUCT_NAME" | /usr/bin/head -n 1
}

launch_pdf() {
  local pdf_path="$1"
  /usr/bin/pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true
  sleep 1

  if ! /usr/bin/open -n -a "$APP_BUNDLE" "$pdf_path" >/dev/null 2>&1; then
    /usr/bin/open -n "$APP_BUNDLE" >/dev/null
    sleep 1
    /usr/bin/open -a "$APP_NAME" "$pdf_path" >/dev/null
  fi
}

rss_for_pid_kb() {
  local pid="$1"
  /bin/ps -o rss= -p "$pid" | /usr/bin/awk '{print $1}'
}

sample_case() {
  local case_name="$1"
  local pdf_path="$2"
  local report_path="$3"
  local peak_kb=0
  local last_kb=0
  local pid=""

  launch_pdf "$pdf_path"

  for _ in $(seq 1 30); do
    pid="$(app_pid || true)"
    if [[ -n "$pid" ]]; then
      break
    fi
    sleep 0.5
  done

  if [[ -z "$pid" ]]; then
    echo "| $case_name | $(basename "$pdf_path") | failed to launch | - | - | - |" >>"$report_path"
    return
  fi

  for second in $(seq 1 "$SAMPLE_SECONDS"); do
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      echo "| $case_name | $(basename "$pdf_path") | exited at ${second}s | - | - | - |" >>"$report_path"
      return
    fi
    last_kb="$(rss_for_pid_kb "$pid")"
    if [[ -n "$last_kb" && "$last_kb" -gt "$peak_kb" ]]; then
      peak_kb="$last_kb"
    fi
    sleep 1
  done

  local file_mb
  file_mb="$(/usr/bin/du -m "$pdf_path" | /usr/bin/awk '{print $1}')"
  local peak_mb
  local last_mb
  peak_mb="$(/usr/bin/awk -v kb="$peak_kb" 'BEGIN { printf "%.1f", kb / 1024 }')"
  last_mb="$(/usr/bin/awk -v kb="$last_kb" 'BEGIN { printf "%.1f", kb / 1024 }')"

  echo "| $case_name | $(basename "$pdf_path") | ${file_mb} MB | ${pid} | ${peak_mb} MB | ${last_mb} MB |" >>"$report_path"
}

pdf_path_for_case() {
  case "$1" in
    text100) echo "$PDF_DIR/readarc-text-100.pdf" ;;
    text500) echo "$PDF_DIR/readarc-text-500.pdf" ;;
    text1000) echo "$PDF_DIR/readarc-text-1000.pdf" ;;
    chinese100) echo "$PDF_DIR/readarc-chinese-dense-100.pdf" ;;
    chinese500) echo "$PDF_DIR/readarc-chinese-dense-500.pdf" ;;
    chinese1000) echo "$PDF_DIR/readarc-chinese-dense-1000.pdf" ;;
    scan100) echo "$PDF_DIR/readarc-scan-like-100.pdf" ;;
    scan200) echo "$PDF_DIR/readarc-scan-like-200.pdf" ;;
    scan500) echo "$PDF_DIR/readarc-scan-like-500.pdf" ;;
    image100) echo "$PDF_DIR/readarc-image-100.pdf" ;;
    mixed300) echo "$PDF_DIR/readarc-mixed-300.pdf" ;;
    *) return 1 ;;
  esac
}

generate_pdfs

if [[ "$GENERATE_ONLY" -eq 1 ]]; then
  echo "Generated PDFs in $PDF_DIR"
  exit 0
fi

build_app

timestamp="$(/bin/date +%Y%m%d-%H%M%S)"
REPORT_PATH="$REPORT_DIR/readarc-stress-$timestamp.md"

{
  echo "# ReadArc PDF Stress Report"
  echo
  echo "- App: $APP_BUNDLE"
  echo "- Cases: $CASES"
  if [[ "${#EXTERNAL_PDFS[@]}" -gt 0 ]]; then
    echo "- External PDFs: ${EXTERNAL_PDFS[*]}"
  fi
  echo "- Sample seconds per case: $SAMPLE_SECONDS"
  echo "- Generated at: $(/bin/date '+%Y-%m-%d %H:%M:%S %Z')"
  echo
  echo "| Case | PDF | File Size | PID | Peak RSS | Final RSS |"
  echo "| --- | --- | ---: | ---: | ---: | ---: |"
} >"$REPORT_PATH"

IFS=',' read -r -a CASE_ARRAY <<<"$CASES"
for case_name in "${CASE_ARRAY[@]}"; do
  case_name="$(echo "$case_name" | /usr/bin/sed 's/^ *//;s/ *$//')"
  [[ -z "$case_name" ]] && continue
  pdf_path="$(pdf_path_for_case "$case_name")"
  if [[ ! -f "$pdf_path" ]]; then
    echo "| $case_name | missing PDF | - | - | - | - |" >>"$REPORT_PATH"
    continue
  fi
  echo "Sampling $case_name..."
  sample_case "$case_name" "$pdf_path" "$REPORT_PATH"
done

if [[ "${#EXTERNAL_PDFS[@]}" -gt 0 ]]; then
  for pdf_path in "${EXTERNAL_PDFS[@]}"; do
    if [[ ! -f "$pdf_path" ]]; then
      echo "| external | $pdf_path | missing PDF | - | - | - |" >>"$REPORT_PATH"
      continue
    fi
    echo "Sampling external PDF: $pdf_path..."
    sample_case "external" "$pdf_path" "$REPORT_PATH"
  done
fi

/usr/bin/pkill -x "$PRODUCT_NAME" >/dev/null 2>&1 || true

{
  echo
  echo "Notes:"
  echo "- RSS is sampled with ps once per second, so very short spikes can be missed."
  echo "- scan cases are scan-like vector content without embedded OCR text; use a real scanned PDF for final PDFKit raster memory validation."
  echo "- image100 uses a repeated embedded image XObject to exercise image-heavy rendering."
} >>"$REPORT_PATH"

echo "Report: $REPORT_PATH"
