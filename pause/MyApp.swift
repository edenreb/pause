import SwiftUI
import Combine
import Foundation
import AppKit

class BreakManager: ObservableObject {
    @Published var selectedDuration: Int = 30
    @Published var secondsRemaining: Int = 30 * 60
    @Published var isBreakActive: Bool = false
    
    private var timer: Timer?
    
    // Start the countdown as soon as the app launches
    init() {
        startTimer()
    }
    
    func startTimer(seconds: Int? = nil) {
        stopTimer()
        
        // 'seconds' lets a snooze delay the next pause without changing the chosen gap
        secondsRemaining = seconds ?? selectedDuration * 60
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
            } else {
                self.triggerPause()
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func triggerPause() {
        stopTimer()
        isBreakActive = true
        
        // Directly launch the window
        DispatchQueue.main.async {
            WindowManager.shared.showWindow(with: self)
        }
    }
}

//Making it a borderless window (not using standard fullscreen)
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// A dedicated helper to manage the window instance safely
class WindowManager {
    static let shared = WindowManager()
    // Making the window show up on all monitors
    private var windows: [NSWindow] = []

    func showWindow(with manager: BreakManager) {
        // Rebuild every break so newly plugged-in monitors are covered
        windows.forEach { $0.orderOut(nil) }
        let mainScreen = NSScreen.main ?? NSScreen.screens.first

        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.backgroundColor = .clear
            window.isOpaque = false
            // Force it above the Dock and Menu Bar, and show it on all spaces
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let blur = NSVisualEffectView()
            blur.material = .fullScreenUI
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.appearance = NSAppearance(named: .darkAqua)
            window.contentView = blur

            // Only the main screen gets the prompt/breathing UI; others just blur + tint,
            // so there is one countdown and one set of buttons
            let host: NSView = screen == mainScreen
                ? NSHostingView(rootView: PauseView().environmentObject(manager))
                : NSHostingView(rootView: Color.black.opacity(0.4).ignoresSafeArea())
            host.frame = blur.bounds
            host.autoresizingMask = [.width, .height]
            blur.addSubview(host)

            window.setFrame(screen.frame, display: true)
            window.alphaValue = 0
            return window
        }

        // Reveal invisibly, focus the main screen's window, then slowly fade all in together
        NSApp.activate(ignoringOtherApps: true)
        for window in windows {
            if window.screen == mainScreen { window.makeKeyAndOrderFront(nil) } else { window.orderFrontRegardless() }
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 2.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            windows.forEach { $0.animator().alphaValue = 1 }
        }
    }

    func closeWindow() {
        let closing = windows
        // Fade out, then hide the windows
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.8
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })
    }
}

@main struct MyApp: App {
    @StateObject private var breakManager = BreakManager()
    
    var body: some Scene {
        MenuBarExtra("Pause", systemImage: "pause") {
            Picker("Gap Duration", selection: $breakManager.selectedDuration) {
                Text("25 minutes").tag(25)
                Text("30 minutes").tag(30)
                Text("45 minutes").tag(45)
                Text("50 minutes").tag(50)
                Text("60 minutes").tag(60)
            }
            .pickerStyle(.inline)
            .onChange(of: breakManager.selectedDuration) { _, _ in breakManager.startTimer() }
            
            Divider()
            
            Button("Pause now") {
                breakManager.triggerPause()
            }
            
            Divider()
            
            Button("Quit App"){
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
