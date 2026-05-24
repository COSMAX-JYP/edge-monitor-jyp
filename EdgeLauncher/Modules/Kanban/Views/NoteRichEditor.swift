import SwiftUI
import WebKit

/// WKWebView 기반 Quill 2.0 rich text editor.
/// - 스크린샷 클립보드 붙여넣기 (자동 base64 인라인 이미지)
/// - Excel / Sheets / Numbers 표 붙여넣기 (HTML table 보존)
/// - SwiftUI Binding<String> 으로 HTML 양방향 동기화
///
/// content 는 HTML 문자열로 저장/복원. plain text 로 저장되던 기존 notes 는 그대로
/// 렌더링되며 사용자가 편집하면 HTML 로 업그레이드됨.
struct NoteRichEditor: NSViewRepresentable {
    @Binding var html: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "swiftEditor")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        let initial = html.escapingForJSString()
        // TinyMCE 가 추가로 plugins/skins/lang 을 fetch 하므로 same-origin CORS 회피 위해
        // https origin 으로 baseURL 설정.
        webView.loadHTMLString(html(initial: initial), baseURL: URL(string: "https://cdn.jsdelivr.net"))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Swift binding 의 외부 변경(예: 카드 다른 카드로 전환) → 에디터 갱신.
        // 사용자 입력 변경은 Coordinator 가 isUpdatingFromSwift 플래그로 방지.
        guard context.coordinator.isReady, !context.coordinator.isUpdatingFromUser else { return }
        let safe = html.escapingForJSString()
        let js = "window.__setContent && window.__setContent('\(safe)');"
        nsView.evaluateJavaScript(js)
    }

    private func html(initial: String) -> String {
        // TinyMCE 6 community (GPL) via jsdelivr — full package with plugins/skins/icons.
        // 이미지 리사이즈 (object_resizing) / 표 / paste image base64 / 한국어 다 native.
        """
        <!doctype html>
        <html><head>
          <meta charset="utf-8">
          <style>
            html, body { height: 100%; margin: 0; padding: 0; background: transparent; }
            .tox-tinymce { border: none !important; height: 100% !important; }
            .tox-statusbar__branding { display: none !important; }
          </style>
        </head><body>
          <textarea id="editor"></textarea>
          <script referrerpolicy="origin" src="https://cdn.jsdelivr.net/npm/tinymce@6.8.5/tinymce.min.js"></script>
          <script>
            const initial = '\(initial)';
            tinymce.init({
              selector: '#editor',
              license_key: 'gpl',
              base_url: 'https://cdn.jsdelivr.net/npm/tinymce@6.8.5',
              suffix: '.min',
              promotion: false,
              branding: false,
              menubar: 'edit insert format table',
              plugins: 'autoresize image table lists link code paste advlist wordcount',
              toolbar: 'undo redo | blocks fontsize | bold italic underline strikethrough | forecolor backcolor | alignleft aligncenter alignright | bullist numlist outdent indent | link image table | removeformat code',
              toolbar_mode: 'sliding',
              height: '100%',
              min_height: 320,
              autoresize_bottom_margin: 16,
              image_advtab: true,
              image_caption: true,
              image_dimensions: true,
              object_resizing: true,
              paste_data_images: true,
              paste_as_text: false,
              table_default_attributes: { border: '1' },
              table_default_styles: { 'border-collapse': 'collapse', 'width': '100%' },
              content_style: 'body { font-family: -apple-system, "SF Pro Text", "Apple SD Gothic Neo", sans-serif; font-size: 15px; line-height: 1.55; padding: 14px 18px; } img { max-width: 100%; height: auto; } table { border-collapse: collapse; } table td, table th { border: 1px solid #cfd3dc; padding: 4px 8px; }',
              language: 'ko',
              language_url: 'https://cdn.jsdelivr.net/npm/tinymce-i18n@23.10.16/langs6/ko_KR.js',
              language_load: true,
              setup: function(editor) {
                editor.on('init', function() {
                  if (initial && initial.trim().length > 0) {
                    editor.setContent(initial);
                  }
                  try { window.webkit.messageHandlers.swiftEditor.postMessage({ kind: 'ready' }); } catch(_) {}
                });
                editor.on('input change keyup undo redo SetContent ExecCommand NodeChange ObjectResized', function() {
                  const html = editor.getContent();
                  try { window.webkit.messageHandlers.swiftEditor.postMessage({ kind: 'change', html: html }); } catch(_) {}
                });
              }
            });

            window.__setContent = function(value) {
              if (window.tinymce && tinymce.activeEditor) {
                tinymce.activeEditor.setContent(value || '');
              }
            };
          </script>
        </body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: NoteRichEditor
        weak var webView: WKWebView?
        var isReady: Bool = false
        var isUpdatingFromUser: Bool = false

        init(_ parent: NoteRichEditor) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any], let kind = dict["kind"] as? String else { return }
            switch kind {
            case "ready":
                isReady = true
            case "change":
                if let html = dict["html"] as? String {
                    isUpdatingFromUser = true
                    parent.html = html
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.isUpdatingFromUser = false
                    }
                }
            default:
                break
            }
        }
    }
}

private extension String {
    /// JS 문자열 리터럴 안에 안전하게 끼울 수 있게 escape.
    func escapingForJSString() -> String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }
}

extension String {
    /// notes 필드가 HTML 일 수 있는 환경에서 plain text 만 추출.
    /// 카드 미리보기·검색·요약 등 plain text 표시 자리에 사용.
    var plainTextFromHTML: String {
        guard contains("<") else { return self }
        return self
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n")
            .replacingOccurrences(of: "</li>", with: "\n")
            .replacingOccurrences(of: "</h[1-6]>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
