import SwiftUI

struct YouTubeMusicView: View {
    var body: some View {
        YouTubeMusicWebView(url: URL(string: "https://music.youtube.com")!)
            .ignoresSafeArea()
    }
}
