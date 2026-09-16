import SwiftUI
import Combine
import Foundation

class BreakManager: ObservableObject {
    
    // Setting up default values for pauses
    @Published var selectedDuration: Int = 30
    @Published var secondsRemaining: Int = 30 * 60
    @Published var isBreakActive: Bool = false
    
    private var timer: Timer?
    
    func startTimer() {
        // Stop existing timer so I don't have duplicates
        stopTimer()
        
        secondsRemaining = selectedDuration * 60
        
        // Preventing memory leaks by
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self]
            i in guard let self = self else { return }
            
            // Countdown to 0 by decrementing secondsRemaining by 1 every second
            if self.secondsRemaining > 0 {
                self.secondsRemaining -= 1
            }
            
            // Trigger the pause if 0 seconds remaining
            else {
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
        
        // TODO: Launch pause
        PauseView()
    }
}

@main struct MyApp: App {
    
    @StateObject private var breakManager = BreakManager()
    
    var body: some Scene {
        
        // Setting up the menu bar
        MenuBarExtra("Pause", systemImage: "heart.badge.bolt") {
            
            // Creating a "dropdown" list for changing the duration between pauses
            Picker("Gap Duration", selection: $breakManager.selectedDuration) {
                Text("20 minutes").tag(20)
                Text("30 minutes").tag(30)
                Text("40 minutes").tag(40)
            }
            .pickerStyle(.inline)
            .onChange(of: breakManager.selectedDuration) {
                breakManager.startTimer()
            }
            
            Divider()
            
            Button("Pause now") {
                breakManager.triggerPause()
            }
            
            Divider()
            
            // The only way to quit the app
            Button("Quit App"){
                NSApplication.shared.terminate(nil)
            }
        }
        
        WindowGroup(id: "pauseWindow") {
            PauseView()
                .environmentObject(breakManager)
        }
    }
}

