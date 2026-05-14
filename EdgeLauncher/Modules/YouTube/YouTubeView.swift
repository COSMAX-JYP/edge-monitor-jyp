import SwiftUI

struct YouTubeView: View {
    var body: some View {
        YouTubeWebView(url: URL(string: "https://www.youtube.com")!)
            .ignoresSafeArea()
    }
}
