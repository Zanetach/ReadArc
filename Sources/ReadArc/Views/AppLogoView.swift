import AppKit
import SwiftUI

struct AppLogoView: View {
    let size: CGFloat

    var body: some View {
        logoImage
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var logoImage: Image {
        if
            let url = Bundle.main.url(forResource: "readarc-logo", withExtension: "png"),
            let nsImage = NSImage(contentsOf: url)
        {
            return Image(nsImage: nsImage)
        }

        return Image("readarc-logo", bundle: .module)
    }
}
