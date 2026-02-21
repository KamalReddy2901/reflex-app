import SwiftUI

struct PermissionRequestView: View {
    @EnvironmentObject var permissionService: AccessibilityPermissionService
    @Environment(\.dismiss) private var dismiss

    @State private var animateGradient = false

    var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: 32) {
                Spacer()

                // Icon with animated ring
                ZStack {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.reflexPurple, .reflexBlue, .reflexTeal, .reflexPurple],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(animateGradient ? 360 : 0))
                        .animation(
                            .linear(duration: 4).repeatForever(autoreverses: false),
                            value: animateGradient
                        )

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.reflexPurple, .reflexBlue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(spacing: 12) {
                    Text("Accessibility Access")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Reflex needs accessibility permissions to monitor your typing rhythm and mouse patterns — the core signals used to understand your cognitive state.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }

                // Privacy assurances
                GlassMorphicCard(tintColor: .reflexPurple.opacity(0.05)) {
                    VStack(alignment: .leading, spacing: 12) {
                        privacyItem(
                            icon: "keyboard",
                            title: "Keystroke Timing Only",
                            description: "We measure the rhythm between keys, never what you type."
                        )

                        Divider().background(.white.opacity(0.1))

                        privacyItem(
                            icon: "internaldrive",
                            title: "100% Local",
                            description: "All data stays on your Mac. Zero network transmissions."
                        )

                        Divider().background(.white.opacity(0.1))

                        privacyItem(
                            icon: "eye.slash",
                            title: "No Screenshots",
                            description: "We never capture screen content, only input patterns."
                        )
                    }
                }
                .frame(maxWidth: 420)

                // Action buttons
                VStack(spacing: 12) {
                    if permissionService.isGranted {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Permission Granted!")
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .transition(.scale.combined(with: .opacity))

                        Button("Get Started") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                    } else {
                        Button(action: {
                            permissionService.requestPermission()
                        }) {
                            HStack {
                                Image(systemName: "lock.open")
                                Text("Grant Accessibility Access")
                            }
                            .frame(maxWidth: 280)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.reflexPurple)
                        .controlSize(.large)

                        Button("Open System Settings Manually") {
                            permissionService.openSystemPreferences()
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                Text("You can change this anytime in System Settings → Privacy & Security → Accessibility")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
            }
            .padding(40)
        }
        .frame(width: 520, height: 620)
        .onAppear {
            animateGradient = true
        }
        .animation(.easeInOut, value: permissionService.isGranted)
    }

    private func privacyItem(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.reflexTeal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}
