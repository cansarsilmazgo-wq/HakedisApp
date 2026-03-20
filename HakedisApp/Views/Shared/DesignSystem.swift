import SwiftUI

// MARK: - Theme
extension Color {
    static let hakedisOrange = Color(red: 0.96, green: 0.45, blue: 0.13)
    static let hakedisBackground = Color(UIColor.systemGroupedBackground)
    static let hakedisCard = Color(UIColor.secondarySystemGroupedBackground)
    static let hakedisSuccess = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let hakedisWarning = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let hakedisDanger = Color(red: 0.95, green: 0.23, blue: 0.23)
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    let icon: String

    init(title: String, value: String, subtitle: String? = nil, color: Color = .hakedisOrange, icon: String) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Progress Bar
struct ProgressBarView: View {
    let progress: Double // 0-100
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(min(progress / 100, 1.0)), height: 6)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?

    init(_ title: String, action: (() -> Void)? = nil) {
        self.title = title
        self.action = action
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if let action {
                Button("Tümü", action: action)
                    .font(.subheadline)
                    .foregroundStyle(.hakedisOrange)
            }
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(icon: String, title: String, subtitle: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.5))
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.hakedisOrange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Currency Formatter
extension Double {
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₺"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: self)) ?? "₺0"
    }

    var percentFormatted: String {
        String(format: "%.1f%%", self)
    }

    var quantityFormatted: String {
        if self == floor(self) {
            return String(format: "%.0f", self)
        }
        return String(format: "%.2f", self)
    }
}

// MARK: - Date Formatter
extension Date {
    var shortFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: self)
    }

    var monthYear: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: self)
    }
}
