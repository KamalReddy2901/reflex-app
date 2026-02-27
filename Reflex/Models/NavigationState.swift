import SwiftUI

/// Shared navigation state between MenuBarView and DashboardView.
/// Allows the menu bar tiles to deep-link into specific dashboard tabs.
@MainActor
class NavigationState: ObservableObject {
    @Published var selectedTab: DashboardTab = .overview
    @Published var pendingNavigation: DashboardTab?

    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case history = "History"
        case insights = "Insights"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .overview: return "gauge.with.dots.needle.67percent"
            case .history: return "clock.arrow.circlepath"
            case .insights: return "chart.line.uptrend.xyaxis"
            case .settings: return "gearshape"
            }
        }
    }
}
