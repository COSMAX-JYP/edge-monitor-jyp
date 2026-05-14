import SwiftUI

struct ChatGPTView: View {
    var body: some View {
        GenericWebView(url: URL(string: "https://chatgpt.com")!)
            .ignoresSafeArea()
    }
}
