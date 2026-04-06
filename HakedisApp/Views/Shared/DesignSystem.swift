import SwiftUI

extension Color {
    static let hakedisOrange = Color(red: 0.96, green: 0.45, blue: 0.13)
    static let hakedisBackground = Color(UIColor.systemGroupedBackground)
    static let hakedisCard = Color(UIColor.secondarySystemGroupedBackground)
    static let hakedisSuccess = Color(red: 0.20, green: 0.78, blue: 0.35)
    static let hakedisWarning = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let hakedisDanger = Color(red: 0.95, green: 0.23, blue: 0.23)
    static let hakedisPaid = Color(UIColor.systemBlue)
    static let hakedisInfo = Color(UIColor.systemIndigo)
}

enum Spacing {
    static let xs: CGFloat = 8
    static let cardSmall: CGFloat = 12
    static let card: CGFloat = 14
    static let md: CGFloat = 16
    static let section: CGFloat = 24
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    let icon: String
    init(title: String, value: String, subtitle: String? = nil, color: Color = .hakedisOrange, icon: String) {
        self.title = title; self.value = value; self.subtitle = subtitle; self.color = color; self.icon = icon
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.subheadline).foregroundColor(color)
                Text(title).font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            Text(value).font(.title2.bold())
            if let subtitle { Text(subtitle).font(.caption2).foregroundColor(.secondary) }
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)\(subtitle.map { ", \($0)" } ?? "")")
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

struct ProgressBarView: View {
    let progress: Double
    let color: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2)).frame(height: 6)
                RoundedRectangle(cornerRadius: 4).fill(color)
                    .frame(width: geo.size.width * CGFloat(min(progress / 100, 1.0)), height: 6)
            }
        }
        .frame(height: 6)
    }
}

struct SectionHeader: View {
    let title: String
    let action: (() -> Void)?
    init(_ title: String, action: (() -> Void)? = nil) { self.title = title; self.action = action }
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            if let action { Button("Tümü", action: action).font(.subheadline).foregroundColor(.hakedisOrange) }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?
    init(icon: String, title: String, subtitle: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon; self.title = title; self.subtitle = subtitle; self.actionTitle = actionTitle; self.action = action
    }
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(.secondary.opacity(0.5))
            VStack(spacing: 6) {
                Text(title).font(.headline).foregroundColor(.secondary)
                Text(subtitle).font(.subheadline).foregroundColor(.secondary.opacity(0.7)).multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.hakedisOrange).foregroundColor(.white).clipShape(Capsule())
                }
            }
        }
        .padding(32).frame(maxWidth: .infinity)
    }
}

// MARK: - UserRole

enum UserRole: String, Codable, CaseIterable {
    case owner          = "owner"
    case projectManager = "projectManager"
    case siteEngineer   = "siteEngineer"
    case safetyOfficer  = "safetyOfficer"
    case siteForeman    = "siteForeman"
    case accountant     = "accountant"
    case subcontractor  = "subcontractor"
    case viewer         = "viewer"

    var displayName: String {
        switch self {
        case .owner:          return "Patron / Firma Sahibi"
        case .projectManager: return "Proje Müdürü"
        case .siteEngineer:   return "Şantiye Mühendisi"
        case .safetyOfficer:  return "İSG Uzmanı"
        case .siteForeman:    return "Şantiye Şefi"
        case .accountant:     return "Muhasebeci"
        case .subcontractor:  return "Taşeron"
        case .viewer:         return "İzleyici (Salt Okuma)"
        }
    }

    var icon: String {
        switch self {
        case .owner:          return "crown.fill"
        case .projectManager: return "person.badge.shield.checkmark"
        case .siteEngineer:   return "hammer.fill"
        case .safetyOfficer:  return "cross.case.fill"
        case .siteForeman:    return "wrench.and.screwdriver.fill"
        case .accountant:     return "banknote.fill"
        case .subcontractor:  return "building.2.fill"
        case .viewer:         return "eye.fill"
        }
    }

    var canSeeFinancials: Bool        { [.owner, .projectManager, .accountant].contains(self) }
    var canSeeProfitability: Bool     { self == .owner }
    var canSeeSalaries: Bool          { [.owner, .accountant].contains(self) }
    var canSeeAllProjects: Bool       { [.owner, .accountant].contains(self) }
    var canCreateHakedis: Bool        { [.owner, .projectManager, .siteEngineer, .accountant].contains(self) }
    var canApproveHakedis: Bool       { [.owner, .projectManager].contains(self) }
    var canManageWorkers: Bool        { [.owner, .projectManager, .siteEngineer, .siteForeman].contains(self) }
    var canManageSafety: Bool         { [.owner, .projectManager, .siteEngineer, .safetyOfficer].contains(self) }
    var canManageMaterials: Bool      { [.owner, .projectManager, .siteEngineer, .siteForeman].contains(self) }
    var canManageEquipment: Bool      { [.owner, .projectManager, .siteEngineer, .siteForeman].contains(self) }
    var canManageDocuments: Bool      { [.owner, .projectManager, .siteEngineer, .accountant].contains(self) }
    var canManageContracts: Bool      { [.owner, .projectManager, .accountant].contains(self) }
    var canDeleteData: Bool           { [.owner, .projectManager].contains(self) }
    var canExportData: Bool           { [.owner, .projectManager, .accountant].contains(self) }
    var canManageUsers: Bool          { self == .owner }
    var canSeeDailyEntry: Bool        { self != .accountant }
    var canSeeSiteDiary: Bool         { self != .accountant && self != .subcontractor }
    var canSeeAttendance: Bool        { [.owner, .projectManager, .siteEngineer, .siteForeman, .accountant].contains(self) }
    var canSeeBudget: Bool            { [.owner, .projectManager, .accountant].contains(self) }
    var canSeeEVM: Bool               { [.owner, .projectManager].contains(self) }
    var canSeeSubcontractorDetails: Bool { [.owner, .projectManager, .accountant].contains(self) }
    var canCreateWorkOrder: Bool      { [.owner, .projectManager, .siteEngineer, .siteForeman].contains(self) }
    var canCreateRFI: Bool            { [.owner, .projectManager, .siteEngineer].contains(self) }
}

// MARK: - UserProfession

enum UserProfession: String, Codable, CaseIterable {
    case civilEngineer      = "civilEngineer"
    case architect          = "architect"
    case mechanicalEngineer = "mechanicalEngineer"
    case electricalEngineer = "electricalEngineer"
    case geologicalEngineer = "geologicalEngineer"
    case surveyor           = "surveyor"
    case technician         = "technician"
    case safetySpecialist   = "safetySpecialist"
    case accountantProf     = "accountantProf"
    case contractor         = "contractor"
    case other              = "other"

    var displayName: String {
        switch self {
        case .civilEngineer:      return "İnşaat Mühendisi"
        case .architect:          return "Mimar"
        case .mechanicalEngineer: return "Makine Mühendisi"
        case .electricalEngineer: return "Elektrik Mühendisi"
        case .geologicalEngineer: return "Jeoloji Mühendisi"
        case .surveyor:           return "Harita Mühendisi"
        case .technician:         return "Tekniker"
        case .safetySpecialist:   return "İSG Uzmanı"
        case .accountantProf:     return "Mali Müşavir / Muhasebeci"
        case .contractor:         return "Müteahhit"
        case .other:              return "Diğer"
        }
    }
}

// MARK: - CurrencyManager

enum SupportedCurrency: String, CaseIterable {
    case TRY = "TRY"
    case USD = "USD"
    case EUR = "EUR"
    case GBP = "GBP"

    var symbol: String {
        switch self {
        case .TRY: return "₺"
        case .USD: return "$"
        case .EUR: return "€"
        case .GBP: return "£"
        }
    }

    var locale: Locale {
        switch self {
        case .TRY: return Locale(identifier: "tr_TR")
        case .USD: return Locale(identifier: "en_US")
        case .EUR: return Locale(identifier: "de_DE")
        case .GBP: return Locale(identifier: "en_GB")
        }
    }
}

extension Double {
    var currencyFormatted: String {
        let code = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "TRY"
        let currency = SupportedCurrency(rawValue: code) ?? .TRY
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = currency.symbol
        f.locale = currency.locale
        return f.string(from: NSNumber(value: self)) ?? "\(currency.symbol)0"
    }
    var percentFormatted: String { String(format: "%.1f%%", self) }
    var quantityFormatted: String { self == floor(self) ? String(format: "%.0f", self) : String(format: "%.2f", self) }
    /// Compact currency for table display — same as compactCurrency
    var shortFormatted: String { compactCurrency }
    /// Compact currency — e.g. ₺1,2M or ₺850B
    var compactCurrency: String {
        let code = UserDefaults.standard.string(forKey: "selectedCurrency") ?? "TRY"
        let sym = (SupportedCurrency(rawValue: code) ?? .TRY).symbol
        let abs = Swift.abs(self)
        let sign = self < 0 ? "-" : ""
        switch abs {
        case 1_000_000_000...: return "\(sign)\(sym)\(String(format: "%.1f", abs / 1_000_000_000))Mr"
        case 1_000_000...: return "\(sign)\(sym)\(String(format: "%.1f", abs / 1_000_000))M"
        case 1_000...: return "\(sign)\(sym)\(String(format: "%.0f", abs / 1_000))B"
        default: return currencyFormatted
        }
    }

    func maskedCurrency(for role: UserRole) -> String {
        guard role.canSeeFinancials else { return "₺***" }
        return currencyFormatted
    }

    func maskedSalary(for role: UserRole) -> String {
        guard role.canSeeSalaries else { return "***" }
        return currencyFormatted
    }
}

extension Date {
    var shortFormatted: String { let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: self) }
    var monthYear: String { let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "MMMM yyyy"; return f.string(from: self) }
}

// MARK: - ErrorHelper

enum ErrorHelper {
    static func userFriendlyMessage(_ error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("disk") || desc.contains("space") || desc.contains("full") {
            return "Depolama alanı yetersiz. Lütfen cihazınızda yer açın."
        } else if desc.contains("iCloud") || desc.contains("CloudKit") || desc.contains("network") || desc.contains("connection") {
            return "Ağ bağlantısı sorunu. İnternet bağlantınızı kontrol edin."
        } else if desc.contains("permission") || desc.contains("authorization") || desc.contains("denied") {
            return "İzin reddedildi. Ayarlar'dan uygulama izinlerini kontrol edin."
        } else if desc.contains("corrupt") || desc.contains("invalid") || desc.contains("format") {
            return "Dosya biçimi geçersiz veya bozuk. Farklı bir dosya deneyin."
        } else if desc.contains("SwiftData") || desc.contains("Core Data") || desc.contains("migration") {
            return "Veritabanı hatası oluştu. Uygulamayı yeniden başlatmayı deneyin."
        } else {
            return "Bir hata oluştu. Lütfen tekrar deneyin."
        }
    }
}

// MARK: - ToastView

struct ToastView: View {
    let message: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(color)
            Text(message)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    let systemImage: String
    let color: Color

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content
            if isPresented {
                ToastView(message: message, systemImage: systemImage, color: color)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { isPresented = false }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented)
    }
}

extension View {
    func toast(isPresented: Binding<Bool>, message: String, systemImage: String = "checkmark.circle.fill", color: Color = .hakedisSuccess) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message, systemImage: systemImage, color: color))
    }
}
