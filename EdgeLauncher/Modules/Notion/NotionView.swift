import SwiftUI

struct NotionView: View {
    var body: some View {
        GenericWebView(url: URL(string: "https://www.notion.so")!)
            .ignoresSafeArea()
    }
}
