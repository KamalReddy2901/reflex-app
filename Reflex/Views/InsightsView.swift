import SwiftUI
import Charts

struct InsightsView: View {
    @EnvironmentObject var persistenceService: DataPersistenceService
    @EnvironmentObject var loadEngine: CognitiveLoadEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Insights")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Summary cards
            HStack(spacing: 12) {
                insightCard(
                    title: "7-Day Avg Load",
                    value: String(format: "%.0f", persistenceService.averageLoadForPastDays(7)),
                    icon: "chart.bar",
                    color: .reflexBlue
                )

                insightCard(
                    title: "Total Focus Time",
                    value: persistenceService.totalSessionTime(forPastDays: 7).formattedDuration,
                    icon: "clock",
                    color: .reflexTeal
                )

                insightCard(
                    title: "Best Focus Hour",
                    value: bestFocusHourString,
                    icon: "star",
                    color: .reflexPurple
                )

                insightCard(
                    title: "Sessions",
                    value: "\(persistenceService.sessions.count)",
                    icon: "list.bullet",
                    color: .reflexPink
                )
            }

            // Weekly trend chart
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Weekly Load Trend")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))

                    if !weeklyData.isEmpty {
                        Chart(weeklyData, id: \.day) { entry in
                            BarMark(
                                x: .value("Day", entry.day),
                                y: .value("Load", entry.avgLoad)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.reflexPurple, .reflexBlue],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .cornerRadius(6)
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(position: .leading) { _ in
                                AxisValueLabel()
                                    .foregroundStyle(.white.opacity(0.5))
                                AxisGridLine()
                                    .foregroundStyle(.white.opacity(0.1))
                            }
                        }
                        .chartXAxis {
                            AxisMarks { _ in
                                AxisValueLabel()
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(height: 200)
                    } else {
                        Text("Not enough data for weekly trends yet.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Hour heatmap
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Focus by Hour of Day")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))

                    hourHeatmap
                }
            }

            // Tips
            GlassMorphicCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Personalized Tips", systemImage: "lightbulb")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.7))

                    ForEach(personalizedTips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption)
                                .foregroundColor(.reflexTeal)
                            Text(tip)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private func insightCard(title: String, value: String, icon: String, color: Color) -> some View {
        GlassMorphicCard(tintColor: color.opacity(0.08)) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var hourHeatmap: some View {
        let hourData = computeHourlyAverages()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 12), spacing: 2) {
            ForEach(0..<24, id: \.self) { hour in
                let avg = hourData[hour] ?? 0
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.loadColor(for: Int(avg)).opacity(avg > 0 ? 0.6 : 0.1))
                        .frame(height: 30)

                    Text("\(hour)")
                        .font(.system(size: 8))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Computed

    struct WeeklyEntry {
        let day: String
        let avgLoad: Double
    }

    private var weeklyData: [WeeklyEntry] {
        let calendar = Calendar.current
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        return (0..<7).compactMap { daysAgo in
            let date = calendar.date(byAdding: .day, value: -(6 - daysAgo), to: .now) ?? .now
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? .now

            let daySessions = persistenceService.sessions.filter {
                $0.startTime >= dayStart && $0.startTime < dayEnd
            }

            let avg = daySessions.isEmpty ? 0 : daySessions.map(\.averageLoad).reduce(0, +) / Double(daySessions.count)
            let weekday = calendar.component(.weekday, from: date)
            let name = dayNames[(weekday + 5) % 7]

            return WeeklyEntry(day: name, avgLoad: avg)
        }
    }

    private var bestFocusHourString: String {
        if let hour = persistenceService.bestFocusHour() {
            let period = hour >= 12 ? "PM" : "AM"
            let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            return "\(displayHour) \(period)"
        }
        return "—"
    }

    private func computeHourlyAverages() -> [Int: Double] {
        var hourScores: [Int: [Double]] = [:]
        for session in persistenceService.sessions {
            for sample in session.loadSamples {
                let hour = Calendar.current.component(.hour, from: sample.timestamp)
                hourScores[hour, default: []].append(Double(sample.score))
            }
        }
        return hourScores.mapValues { $0.average }
    }

    private var personalizedTips: [String] {
        var tips: [String] = []

        let avgLoad = persistenceService.averageLoadForPastDays(7)
        if avgLoad > 60 {
            tips.append("Your average cognitive load is high. Try scheduling deep work in shorter blocks (50 min work, 10 min break).")
        }

        if let bestHour = persistenceService.bestFocusHour() {
            tips.append("Your best focus hour is around \(bestHour):00. Schedule your most demanding tasks then.")
        }

        if persistenceService.sessions.count > 5 {
            let recentBreaks = persistenceService.sessions.suffix(5).map(\.breaksTaken).reduce(0, +)
            if recentBreaks < 3 {
                tips.append("You're not taking enough breaks. Even micro-breaks (1-2 min) can significantly reduce cognitive fatigue.")
            }
        }

        if tips.isEmpty {
            tips.append("Keep using Reflex to build your cognitive load profile. Personalized insights will appear after a few sessions.")
            tips.append("Remember: the goal isn't to minimize load, but to manage it sustainably.")
        }

        return tips
    }
}
