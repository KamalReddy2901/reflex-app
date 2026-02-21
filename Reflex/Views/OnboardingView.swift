import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @EnvironmentObject var permissionService: AccessibilityPermissionService
    @State private var currentPage = 0
    @State private var animateIn = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    HowItWorksPage()
                        .tag(1)
                    PrivacyPage()
                        .tag(2)
                    PermissionPage(permissionService: permissionService)
                        .tag(3)
                    ReadyPage()
                        .tag(4)
                }
                .tabViewStyle(.automatic)
                .animation(.easeInOut(duration: 0.4), value: currentPage)

                // Bottom bar
                bottomBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
        }
        .frame(width: 680, height: 520)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
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

            // Subtle animated orbs
            Circle()
                .fill(Color.mint.opacity(0.06))
                .frame(width: 400, height: 400)
                .offset(x: 200, y: -150)
                .blur(radius: 80)

            Circle()
                .fill(Color.purple.opacity(0.05))
                .frame(width: 350, height: 350)
                .offset(x: -180, y: 200)
                .blur(radius: 70)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Skip button (not on last page)
            if currentPage < totalPages - 1 {
                Button("Skip") {
                    completeOnboarding()
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.35))
                .font(.system(size: 14))
            } else {
                Spacer().frame(width: 60)
            }

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.mint : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.4), value: currentPage)
                }
            }

            Spacer()

            // Next / Get Started button
            Button(action: {
                if currentPage < totalPages - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    completeOnboarding()
                }
            }) {
                HStack(spacing: 6) {
                    Text(currentPage == totalPages - 1 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                    Image(systemName: currentPage == totalPages - 1 ? "checkmark" : "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 14))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
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
    }

    private func completeOnboarding() {
        withAnimation(.easeIn(duration: 0.3)) {
            isComplete = true
        }
    }
}

// MARK: - Page 1: Welcome

struct WelcomePage: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // App icon representation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.mint.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 100
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(appear ? 1.0 : 0.7)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mint, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(appear ? 1.0 : 0.5)
                    .shadow(color: .mint.opacity(0.4), radius: 20)
            }

            VStack(spacing: 14) {
                Text("Welcome to Reflex")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Your personal cognitive load monitor.\nKnow when your brain needs rest — no wearable needed.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .lineSpacing(4)
            }
            .opacity(appear ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Page 2: How It Works

struct HowItWorksPage: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("How It Works")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                OnboardingFeatureRow(
                    icon: "keyboard",
                    color: .cyan,
                    title: "Typing Patterns",
                    subtitle: "Monitors rhythm, speed, and error rate"
                )
                OnboardingFeatureRow(
                    icon: "computermouse",
                    color: .green,
                    title: "Mouse Behavior",
                    subtitle: "Tracks jitter, velocity, and scroll patterns"
                )
                OnboardingFeatureRow(
                    icon: "arrow.triangle.swap",
                    color: .orange,
                    title: "Context Switches",
                    subtitle: "Detects app switching and window changes"
                )
                OnboardingFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple,
                    title: "Real-Time Score",
                    subtitle: "Combines signals into a 0–100 load score"
                )
            }
            .frame(maxWidth: 400)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appear = true
            }
        }
    }
}

// MARK: - Page 3: Privacy

struct PrivacyPage: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.blue.opacity(0.12), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 12)
            }
            .scaleEffect(appear ? 1.0 : 0.6)

            VStack(spacing: 14) {
                Text("100% Private")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 10) {
                    PrivacyBullet(icon: "keyboard", text: "No keystrokes recorded — only timing between keys")
                    PrivacyBullet(icon: "photo", text: "No screenshots — only input event patterns")
                    PrivacyBullet(icon: "wifi.slash", text: "No network calls — zero data leaves your Mac")
                    PrivacyBullet(icon: "chart.bar.xaxis", text: "No analytics — no telemetry of any kind")
                }
                .frame(maxWidth: 440)
            }
            .opacity(appear ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Page 4: Permission

struct PermissionPage: View {
    @ObservedObject var permissionService: AccessibilityPermissionService
    @State private var appear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                permissionService.isGranted ? .green.opacity(0.15) : .orange.opacity(0.12),
                                .clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: permissionService.isGranted ? "checkmark.shield.fill" : "hand.raised.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(
                        LinearGradient(
                            colors: permissionService.isGranted
                                ? [.green, .mint]
                                : [.orange, .yellow],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: (permissionService.isGranted ? Color.green : .orange).opacity(0.3), radius: 12)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(appear ? 1.0 : 0.6)

            VStack(spacing: 14) {
                Text(permissionService.isGranted ? "Permission Granted!" : "Accessibility Permission")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.interpolate)

                Text(permissionService.isGranted
                     ? "Reflex can now monitor your input patterns.\nYou're all set!"
                     : "Reflex needs accessibility access to monitor\ntyping and mouse patterns. No personal data is recorded."
                )
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .lineSpacing(3)
            }
            .opacity(appear ? 1 : 0)

            if !permissionService.isGranted {
                Button(action: {
                    permissionService.requestPermission()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gear")
                        Text("Open System Settings")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .opacity(appear ? 1 : 0)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Page 5: Ready

struct ReadyPage: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // Animated rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.mint.opacity(0.1 - Double(i) * 0.03), lineWidth: 2)
                        .frame(width: CGFloat(120 + i * 40), height: CGFloat(120 + i * 40))
                        .scaleEffect(appear ? 1.0 : 0.5)
                        .animation(
                            .spring(response: 0.8, dampingFraction: 0.6)
                                .delay(Double(i) * 0.1),
                            value: appear
                        )
                }

                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.mint, .green, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .mint.opacity(0.4), radius: 16)
                    .scaleEffect(appear ? 1.0 : 0.3)
            }

            VStack(spacing: 14) {
                Text("You're All Set!")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Reflex lives in your menu bar.\nIt will start learning your baseline patterns\nand begin monitoring automatically.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .lineSpacing(4)
            }
            .opacity(appear ? 1 : 0)

            // Quick tips
            HStack(spacing: 20) {
                QuickTip(icon: "brain.head.profile", text: "Menu Bar", detail: "Click for status")
                QuickTip(icon: "chart.bar.xaxis", text: "Dashboard", detail: "Track trends")
                QuickTip(icon: "cup.and.saucer", text: "Breaks", detail: "Smart reminders")
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 15)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appear = true
            }
        }
    }
}

// MARK: - Supporting Views

struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
        )
    }
}

struct PrivacyBullet: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.cyan.opacity(0.7))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.55))

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

struct QuickTip: View {
    let icon: String
    let text: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.mint)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))

            Text(detail)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(width: 100)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}
