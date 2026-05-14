import SwiftUI
import WebKit

struct SlackView: View {
    var body: some View {
        GenericWebView(url: URL(string: "https://app.slack.com/client")!)
            .ignoresSafeArea()
    }
}
