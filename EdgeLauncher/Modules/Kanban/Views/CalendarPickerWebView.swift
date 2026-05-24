import SwiftUI
import WebKit

/// WKWebView 기반 flatpickr inline 캘린더.
/// - airbnb 테마 (모던 / 큼지막 / 한국어 locale)
/// - 시간 포함 (`enableTime`, 24시간)
/// - 선택 시 JS bridge 로 Swift 의 Binding<Date> 갱신
///
/// 외부 의존성: flatpickr (MIT) — https://flatpickr.js.org
struct CalendarPickerWebView: NSViewRepresentable {
    @Binding var date: Date
    var minDate: Date? = nil
    var enableTime: Bool = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "swiftCal")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        webView.loadHTMLString(htmlBody(initial: dateString(date)), baseURL: URL(string: "https://flatpickr.js.org"))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.isReady, !context.coordinator.suppressExternalUpdate else { return }
        let value = dateString(date)
        nsView.evaluateJavaScript("window.__setDate && window.__setDate('\(value)');")
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private func dateString(_ d: Date) -> String { Self.formatter.string(from: d) }

    private func htmlBody(initial: String) -> String {
        let timeFlag = enableTime ? "true" : "false"
        let minDateExpr: String = {
            guard let m = minDate else { return "null" }
            return "'\(Self.formatter.string(from: m))'"
        }()
        return """
        <!doctype html>
        <html><head>
          <meta charset="utf-8">
          <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
          <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/themes/airbnb.css">
          <style>
            html, body { margin: 0; padding: 0; background: transparent; font-family: -apple-system, "SF Pro Text", "Apple SD Gothic Neo", sans-serif; }
            body { padding: 10px; }
            /* inline 모드에서 input 은 숨김 */
            #dp { display: none !important; }
            .flatpickr-calendar.inline { box-shadow: none; border-radius: 16px; padding: 12px; width: 100% !important; max-width: none !important; }
            .flatpickr-calendar { font-size: 17px; width: 100% !important; max-width: none !important; }
            .flatpickr-innerContainer, .flatpickr-rContainer { width: 100% !important; display: block !important; }
            .flatpickr-weekdays { width: 100% !important; }
            .flatpickr-weekdaycontainer { width: 100% !important; display: flex !important; }
            .flatpickr-weekday { flex: 1 1 14.2857%; max-width: 14.2857%; font-size: 14px; font-weight: 700; color: #6b7280; padding: 8px 0; text-align: center; }
            .flatpickr-days { width: 100% !important; }
            .dayContainer { width: 100% !important; min-width: 0 !important; max-width: none !important; display: flex !important; flex-wrap: wrap !important; }
            .flatpickr-day { flex: 0 0 14.2857% !important; max-width: 14.2857% !important; width: 14.2857% !important; height: 52px; line-height: 52px; font-size: 17px; font-weight: 500; border-radius: 10px; margin: 0; }
            .flatpickr-day:hover { background: rgba(46,124,246,0.12); }
            .flatpickr-day.selected, .flatpickr-day.selected:hover { background: #2E7CF6 !important; border-color: #2E7CF6 !important; box-shadow: 0 4px 10px rgba(46,124,246,0.45); color: white !important; }
            .flatpickr-day.today { border-color: #2E7CF6; }
            .flatpickr-day.today:not(.selected) { background: rgba(46,124,246,0.08); }
            .flatpickr-months { padding: 6px 0 10px 0; }
            .flatpickr-current-month { font-size: 20px; padding: 6px 0; }
            .flatpickr-monthDropdown-months, .flatpickr-current-month input.cur-year { font-weight: 700; font-size: 20px; }
            .flatpickr-prev-month, .flatpickr-next-month { padding: 10px 14px; }
            .flatpickr-prev-month svg, .flatpickr-next-month svg { width: 16px; height: 16px; }
            .flatpickr-time { height: 60px; border-top: 1px solid #e5e7eb; margin-top: 10px; }
            .flatpickr-time input { font-size: 22px; font-weight: 700; }
            .flatpickr-time .flatpickr-time-separator { font-size: 22px; }
            .flatpickr-time .flatpickr-am-pm { font-size: 16px; font-weight: 600; }
          </style>
        </head>
        <body>
          <input id="dp" type="text">
          <script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
          <script src="https://cdn.jsdelivr.net/npm/flatpickr/dist/l10n/ko.js"></script>
          <script>
            const initial = '\(initial)';
            const fp = flatpickr('#dp', {
              inline: true,
              enableTime: \(timeFlag),
              time_24hr: true,
              dateFormat: 'Y-m-d H:i',
              defaultDate: initial,
              minDate: \(minDateExpr),
              locale: 'ko',
              onChange: function(_, dateStr) {
                try { window.webkit.messageHandlers.swiftCal.postMessage({ kind: 'change', date: dateStr }); } catch(_) {}
              },
              onReady: function() {
                try { window.webkit.messageHandlers.swiftCal.postMessage({ kind: 'ready' }); } catch(_) {}
              }
            });

            window.__setDate = function(value) {
              fp.setDate(value, false, 'Y-m-d H:i');
            };
          </script>
        </body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: CalendarPickerWebView
        weak var webView: WKWebView?
        var isReady: Bool = false
        var suppressExternalUpdate: Bool = false

        init(_ parent: CalendarPickerWebView) { self.parent = parent }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any], let kind = dict["kind"] as? String else { return }
            switch kind {
            case "ready":
                isReady = true
            case "change":
                guard let str = dict["date"] as? String, !str.isEmpty else { return }
                if let parsed = CalendarPickerWebView.formatter.date(from: str) {
                    suppressExternalUpdate = true
                    parent.date = parsed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.suppressExternalUpdate = false
                    }
                }
            default:
                break
            }
        }
    }
}
