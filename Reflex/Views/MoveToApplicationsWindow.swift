import SwiftUI
import AppKit

// MARK: - Move-to-Applications Check

class MoveToApplicationsController {

    static func checkAndPromptIfNeeded() {
        let bundlePath = Bundle.main.bundlePath
        let applicationsDir = "/Applications/"

        // Already in /Applications — nothing to do
        if bundlePath.hasPrefix(applicationsDir) { return }

        // Also accept ~/Applications/
        let userApps = NSHomeDirectory() + "/Applications/"
        if bundlePath.hasPrefix(userApps) { return }

        // Don't nag on every launch — use UserDefaults
        let key = "hasDeclinedMoveToApplications"
        if UserDefaults.standard.bool(forKey: key) { return }

        // Show the prompt on the main thread
        DispatchQueue.main.async {
            showMovePrompt(from: bundlePath)
        }
    }

    private static func showMovePrompt(from currentPath: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.level = .floating
        window.center()

        let hostingView = NSHostingView(
            rootView: MoveToApplicationsView(
                onMove: {
                    performMove(from: currentPath)
                    window.close()
                },
                onNotNow: {
                    UserDefaults.standard.set(true, forKey: "hasDeclinedMoveToApplications")
                    window.close()
                }
            )
        )

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private static func performMove(from currentPath: String) {
        let appName = (currentPath as NSString).lastPathComponent // e.g. "Reflex Beta.app"
        let destination = "/Applications/\(appName)"

        let script = """
        do shell script "mv '\(currentPath)' '\(destination)'" with administrator privileges
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if error == nil {
                // Relaunch from new location
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = [destination]
                try? task.run()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

// MARK: - SwiftUI View

struct MoveToApplicationsView: View {
    let onMove: () -> Void
    let onNotNow: () -> Void
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Background — matches onboarding style
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                // Icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.mint.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(animateIn ? 1.0 : 0.7)

                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.mint, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateIn ? 1.0 : 0.5)
                        .shadow(color: .mint.opacity(0.4), radius: 16)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animateIn)

                // Text
                VStack(spacing: 10) {
                    Text("Move to Applications?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Reflex Beta works best from your Applications folder.\nMove it there for automatic updates and a cleaner setup.")
                        .font(.system(size: 13.5, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 360)
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.15), value: animateIn)

                Spacer()

                // Buttons
                HStack(spacing: 16) {
                    Button(action: onNotNow) {
                        Text("Not Now")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                            .frame(width: 120, height: 38)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onMove) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Move to Applications")
                                .font(.system(size: 13.5, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(height: 38)
                        .padding(.horizontal, 22)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.mint, .green.opacity(0.9)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateIn)

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 32)
        }
        .frame(width: 480, height: 320)
        .onAppear {
            withAnimation {
                animateIn = true
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.04, blue: 0.16),
                    Color(red: 0.04, green: 0.08, blue: 0.18),
                    Color(red: 0.03, green: 0.06, blue: 0.14),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle orbs
            Circle()
                .fill(Color.mint.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: 150, y: -100)
                .blur(radius: 70)

            Circle()
                .fill(Color.purple.opacity(0.05))
                .frame(width: 250, height: 250)
                .offset(x: -140, y: 150)
                .blur(radius: 60)
        }
    }
}
