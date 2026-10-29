//
//  NoticeHTMLView.swift
//  Notissu
//
//  Copyright © 2026 Notissu. All rights reserved.
//

import SwiftUI
import WebKit

/// 게시판 본문 HTML. 자체 스크롤 없이 내용 높이만큼 늘어나고, 링크는 브라우저로 연다.
struct NoticeHTMLView: UIViewRepresentable {
    let html: String
    let baseURL: URL
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "height")
        // 그림이 늦게 뜨거나 표가 접히면서 높이가 바뀌므로 계속 알려 준다.
        controller.addUserScript(WKUserScript(source: """
            new ResizeObserver(() => {
                window.webkit.messageHandlers.height.postMessage(document.documentElement.scrollHeight);
            }).observe(document.documentElement);
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.dataDetectorTypes = [.link, .phoneNumber]

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(Self.document(body: html), baseURL: baseURL)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "height")
    }

    /// 게시판마다 다른 글꼴·폭·색을 걷어 내고 앱 글자로 맞춘다. 표는 넘치면 가로로 밀어 본다.
    private static func document(body: String) -> String {
        """
        <!doctype html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <style>
        :root { color-scheme: light dark; }
        html, body { margin: 0; padding: 0; background: transparent; }
        body { font: -apple-system-body; font-size: 16px; line-height: 1.7; color: #121417; word-break: keep-all; overflow-wrap: anywhere; -webkit-text-size-adjust: 100%; }
        body * { font-family: inherit !important; max-width: 100% !important; box-sizing: border-box; }
        p, div, span, li, td, th { font-size: inherit !important; line-height: inherit !important; }
        img { height: auto !important; border-radius: 6px; }
        iframe, video { width: 100% !important; aspect-ratio: 16 / 9; height: auto !important; }
        table { display: block; overflow-x: auto; border-collapse: collapse; width: auto !important; font-size: 14px; }
        td, th { border: 1px solid #D6D9DE; padding: 6px 8px; min-width: 48px; }
        a { color: #5D4DE8; word-break: break-all; }
        @media (prefers-color-scheme: dark) {
          body { color: #F2F3F5; }
          body *:not(a):not(img) { color: inherit !important; background-color: transparent !important; }
          td, th { border-color: #3A3D44; }
          a { color: #B2A4EF; }
        }
        </style>
        </head><body>\(body)</body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var height: CGFloat
        var loadedHTML: String?

        init(height: Binding<CGFloat>) {
            _height = height
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let value = message.body as? Double, value > 0 else { return }
            DispatchQueue.main.async { self.height = CGFloat(value) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                if let value = result as? Double, value > 0 {
                    DispatchQueue.main.async { self.height = CGFloat(value) }
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
