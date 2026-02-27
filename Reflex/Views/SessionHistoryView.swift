import SwiftUI
import Charts

struct SessionHistoryView: View {
    @EnvironmentObject var persistenceService: DataPersistenceService
    @State private var selectedSession: SessionData?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Session History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Button(action: exportData) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .glassButton()
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.7))
            }

            if persistenceService.sessions.isEmpty {
                emptyStateView
            } else {
                sessionsList
            }
        }
        .padding(20)
    }

    private var emptyStateView: some View {
        GlassMorphicCard {
            VStack(spacing: 12) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))

                Text("No sessions yet")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.6))

                Text("Your session history will appear here as you use Reflex Beta.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    private var sessionsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(persistenceService.sessions.reversed()) { session in
                SessionRowView(session: session, isSelected: selectedSession?.id == session.id)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSession = selectedSession?.id == session.id ? nil : session
                        }
                    }
            }
        }
    }

    private func exportData() {
        if let url = persistenceService.exportToCSV() {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: SessionData
    let isSelected: Bool

    var body: some View {
        GlassMorphicCard(tintColor: isSelected ? .reflexPurple.opacity(0.1) : .white.opacity(0.02)) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.startTime.dateString)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text("\(session.startTime.timeString) — \(session.endTime?.timeString ?? "Active")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", session.averageLoad))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color.loadColor(for: Int(session.averageLoad)))
                            Text("Avg")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }

                        VStack(spacing: 2) {
                            Text("\(session.peakLoad)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(Color.loadColor(for: session.peakLoad))
                            Text("Peak")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }

                        VStack(spacing: 2) {
                            Text(session.formattedDuration)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Duration")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }

                if isSelected && !session.loadSamples.isEmpty {
                    Divider().background(.white.opacity(0.1))

                    Chart(session.loadSamples.indices, id: \.self) { index in
                        let sample = session.loadSamples[index]
                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("Load", sample.score)
                        )
                        .foregroundStyle(Color.loadColor(for: sample.score))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 80)

                    HStack {
                        Label("\(session.breaksTaken) breaks", systemImage: "cup.and.saucer")
                        Spacer()
                        Label("\(session.totalKeystrokes) keystrokes", systemImage: "keyboard")
                    }
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }
}
