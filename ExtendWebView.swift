import SwiftUI
import WebKit
import Foundation

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var accessToken: String

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var timer: Timer?

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startPollingJavaScript(in: webView)
        }

        func startPollingJavaScript(in webView: WKWebView) {
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.executeJavaScript(in: webView)
            }
        }

        func executeJavaScript(in webView: WKWebView) {
            let jsScript = """
            function lookup(suffix) {
              const key = Object.keys(localStorage).find(
                (key) =>
                  key.startsWith("CognitoIdentityServiceProvider") && key.endsWith(suffix)
              );
              if (!key) return null;
              return localStorage[key];
            }
            var accessToken = lookup("accessToken");
            JSON.stringify({
                accessToken: accessToken
            });
            """

            webView.evaluateJavaScript(jsScript) { result, error in
                if let error = error {
                    print("JavaScript Error: \(error.localizedDescription)")
                    return
                }

                if let resultString = result as? String,
                   let jsonData = resultString.data(using: .utf8) {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] {
                            let accessToken = json["accessToken"] ?? ""
                            if !accessToken.isEmpty {
                                webView.evaluateJavaScript("document.location.href") { (result, _) in
                                    if let urlString = result as? String {
                                        if urlString != "https://app.paywithextend.com/signin" {
                                            self.parent.accessToken = accessToken
                                            self.timer?.invalidate()
                                            self.timer = nil
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        print("Failed to parse JSON: \(error.localizedDescription)")
                    }
                }
            }
        }

        deinit {
            timer?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) { }
}
