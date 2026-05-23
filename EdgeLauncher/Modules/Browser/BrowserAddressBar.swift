import SwiftUI

struct BrowserAddressBar: View {
    @ObservedObject var model: BrowserViewModel
    @State private var input: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button(action: model.goBack) {
                Image(systemName: "chevron.left").frame(width: 20, height: 20)
            }
            .disabled(!model.canGoBack)
            .help("뒤로")

            Button(action: model.goForward) {
                Image(systemName: "chevron.right").frame(width: 20, height: 20)
            }
            .disabled(!model.canGoForward)
            .help("앞으로")

            Button(action: model.reload) {
                Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                    .frame(width: 20, height: 20)
            }
            .help("새로고침")

            Button(action: model.goHome) {
                Image(systemName: "house").frame(width: 20, height: 20)
            }
            .help("홈 (Google)")

            TextField("URL 또는 검색어", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    model.load(input: input)
                    focused = false
                }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.bar)
        .onAppear { input = model.displayURL }
        .onChange(of: model.displayURL) { _, new in
            if !focused { input = new }
        }
    }
}
