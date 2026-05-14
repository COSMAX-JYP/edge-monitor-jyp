import SwiftUI

struct ClaudeView: View {
    var body: some View {
        GenericWebView(url: URL(string: "https://claude.ai")!)
            .ignoresSafeArea()
    }
}
