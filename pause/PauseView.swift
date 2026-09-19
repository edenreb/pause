import SwiftUI
import Combine

struct PauseView: View {
    @EnvironmentObject var breakManager: BreakManager

    private enum Phase { case prompt, breathing, done }

    private let promptSeconds = 10   // time to answer the snooze prompt
    private let breakSeconds = 30   // enforced break length
    private let steps = ["Breathe in", "Hold", "Breathe out", "Hold"]
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var phase: Phase = .prompt
        @State private var tick = 0             // seconds spent in the current phase
    @State private var boxScale: CGFloat = 0.55
    @State private var appeared = false

    private var step: Int { (tick / 4) % 4 }  // box breathing: 4s per side

    var body: some View {
        ZStack {
            // Soft dark tint over the blurred desktop
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            Group {
                if phase == .prompt {
                    promptView.transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    breathingView.transition(.opacity.combined(with: .scale(scale: 1.04)))
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Let the blur settle before the content drifts in
            withAnimation(.easeOut(duration: 1.6).delay(0.8)) { appeared = true }
        }
        .onReceive(clock) { _ in advance() }
    }

    private var promptView: some View {
        VStack(spacing: 32) {
            Text("Time to pause")
                .font(.system(size: 52, weight: .ultraLight, design: .rounded))

            VStack(spacing: 16) {
                Text("Still working? Delay Pause by:")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 12) {
                    ForEach([5, 10, 15], id: \.self) { minutes in
                        Button { snooze(minutes) } label: {
                            Text("\(minutes) minutes")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(.white.opacity(0.2)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Break starts in \(max(promptSeconds - tick, 0))s")
                .font(.system(size: 13, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var breathingView: some View {
        VStack(spacing: 44) {
            Text("Look at something far away")
                .font(.system(size: 40, weight: .ultraLight, design: .rounded))

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 220, height: 220)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .frame(width: 220, height: 220)
                    .scaleEffect(boxScale)
                Text(steps[step])
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.6), value: step)
            }

            Text("Rest your eyes on a point 20 feet away and follow the box.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            if phase == .done {
                Button {
                    WindowManager.shared.closeWindow()
                    breakManager.startTimer()
                } label: {
                    Text("Resume Work")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.9), in: Capsule())
                        .foregroundStyle(.black)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                Text("\(max(breakSeconds - tick, 0))s")
                    .font(.system(size: 13, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }
    
    private func advance() {
        tick += 1
        switch phase {
        case .prompt where tick >= promptSeconds:
            // No answer in time: start the enforced break
            tick = 0
            withAnimation(.easeInOut(duration: 1.2)) { phase = .breathing }
        case .breathing where tick >= breakSeconds:
            withAnimation(.easeInOut(duration: 1)) { phase = .done }
        default: break
        }
        // Each box side is 4s: grow on inhale, shrink on exhale, still on holds
        if phase != .prompt && tick % 4 == 0 {
            withAnimation(.easeInOut(duration: 4)) { boxScale = step < 2 ? 1 : 0.55 }
        }
    }

    private func snooze(_ minutes: Int) {
        WindowManager.shared.closeWindow()
        breakManager.startTimer(seconds: minutes * 60)
    }
}
