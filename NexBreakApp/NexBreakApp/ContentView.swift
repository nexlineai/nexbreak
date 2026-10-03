import SwiftUI
import WebKit
import CoreMotion
import AVFoundation

struct ContentView: View {
    var body: some View {
        GameView()
            .ignoresSafeArea()
    }
}

struct GameView: UIViewRepresentable {
    class Coordinator: NSObject, WKScriptMessageHandler {
        var webView: WKWebView?
        let motionManager = CMMotionManager()
        var lastAcc: CMAcceleration?
        var shakeCooldown = false

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "haptic" {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
        }

        func startMotion() {
            guard motionManager.isAccelerometerAvailable else { return }
            motionManager.accelerometerUpdateInterval = 0.05
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
                guard let self = self, let data = data else { return }
                if self.shakeCooldown { return }
                if let last = self.lastAcc {
                    let dx = abs(data.acceleration.x - last.x)
                    let dy = abs(data.acceleration.y - last.y)
                    let dz = abs(data.acceleration.z - last.z)
                    if dx + dy + dz > 2.0 {
                        self.shakeCooldown = true
                        self.webView?.evaluateJavaScript("if(typeof activateEMP==='function' && typeof state!=='undefined' && state==='playing') activateEMP();")
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            self.shakeCooldown = false
                        }
                    }
                }
                self.lastAcc = data.acceleration
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.008, green: 0.016, blue: 0.031, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 0.008, green: 0.016, blue: 0.031, alpha: 1)

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {}

        webView.configuration.userContentController.add(context.coordinator, name: "haptic")

        context.coordinator.webView = webView
        context.coordinator.startMotion()

        if let url = Bundle.main.url(forResource: "nexbreak", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            try? AVAudioSession.sharedInstance().setActive(true)
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
