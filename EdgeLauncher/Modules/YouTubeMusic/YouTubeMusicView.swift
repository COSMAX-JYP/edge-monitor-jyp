import SwiftUI

struct YouTubeMusicView: View {
    @AppStorage("youtubeMusic.zoom") private var zoom: Double = 0.90

    var body: some View {
        YouTubeMusicWebView(url: URL(string: "https://music.youtube.com")!, zoom: zoom)
            .ignoresSafeArea()
    }
}
