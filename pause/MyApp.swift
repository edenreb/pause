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
    
    func startTimer() {
        stopTimer()
        secondsRemaining = selectedDuration * 60
        
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
        
        // Directly launch the window using AppKit on the main thread
        DispatchQueue.main.async {
            WindowManager.shared.showWindow(with: self)
        }
    }
}

// A borderless window that is still allowed to take focus
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

// A dedicated helper to manage the window instance safely
class WindowManager {
    static let shared = WindowManager()
    private var window: NSWindow?
    
    func showWindow(with manager: BreakManager) {
        // Use the screen the user is currently working on
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        
        // Only build the window the first time
        if window == nil {
            // Create the SwiftUI view hierarchy
            let contentView = PauseView().environmentObject(manager)
            
            // Configure the native NSWindow instance
            let newWindow = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            
            newWindow.contentView = NSHostingView(rootView: contentView)
            newWindow.backgroundColor = .black
            newWindow.isOpaque = true
            newWindow.hasShadow = false
            newWindow.level = .screenSaver // Force it above the Dock and Menu Bar
            newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show on every Space, even over fullscreen apps
            
            window = newWindow
        }
        
        // Stretch the window over the entire screen
        window?.setFrame(screen.frame, display: true)
        
        // Force the app to focus and reveal the window
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    func closeWindow() {
        // Hide the window so it can be reused next break
        window?.orderOut(nil)
    }
}

@main struct MyApp: App {
    @StateObject private var breakManager = BreakManager()
    
    var body: some Scene {
        MenuBarExtra("Pause", systemImage: "heart.badge.bolt") {
            Picker("Gap Duration", selection: $breakManager.selectedDuration) {
                Text("20 minutes").tag(20)
                Text("30 minutes").tag(30)
                Text("40 minutes").tag(40)
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
