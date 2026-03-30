import SwiftUI
import SwiftData

// MARK: - Resmi Şantiye Günlüğü

struct SiteLogSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var workdayCount: Int {
        contract.siteLogEntries.filter { $0.isWorkday }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Şantiye Günlüğü")

            if !contract.siteLogEntries.isEmpty {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Çalışma Günü",
                        value: "\(workdayCount)",
                        color: .hakedisSuccess,
                        icon: "sun.max.fill"
                    )
                    StatCard(
                        title: "Toplam Kayıt",
                        value: "\(contract.siteLogEntries.count)",
                        color: .hakedisOrange,
                        icon: "book.fill"
                    )
                }
            }

            ForEach(contract.siteLogEntries.sorted { $0.logDate > $1.logDate }.prefix(5)) { entry in
                SiteLogRow(entry: entry)
            }

            if contract.siteLogEntries.isEmpty {
                EmptyStateView(
                    icon: "book.fill",
                    title: "Günlük Yok",
                    subtitle: "Henüz şantiye günlüğü kaydı bulunmuyor."
                )
            }

            Button {
                showAdd = true
            } label: {
                Label("Günlük Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSiteLogView(contract: contract)
        }
    }
}

struct SiteLogRow: View {
    let entry: SiteLogEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.weatherCondition.icon)
                .foregroundColor(.hakedisOrange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(entry.logDate, style: .date)
                        .font(.subheadline.bold())
                    Spacer()
                    HStack(spacing: 6) {
                        if entry.isSigned { StatusBadge(text: "İmzalı", color: .hakedisSuccess) }
                        if !entry.isWorkday { StatusBadge(text: entry.isSuspended ? "Tatil Askı" : "Tatil", color: .hakedisWarning) }
                    }
                }
                if !entry.workSummary.isEmpty {
                    Text(entry.workSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddSiteLogView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var logDate = Date()
    @State private var weather: SiteWeather = .sunny
    @State private var isHoliday = false
    @State private var isSuspended = false
    @State private var suspensionReason = ""
    @State private var workSummary = ""
    @State private var contractorSig = ""
    @State private var ownerSig = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tarih") {
                    DatePicker("Tarih", selection: $logDate, displayedComponents: .date)
                }
                Section("Hava Durumu") {
                    Picker("Hava", selection: $weather) {
                        ForEach(SiteWeather.allCases, id: \.self) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Durum") {
                    Toggle("Tatil Günü", isOn: $isHoliday)
                    Toggle("Çalışma Askıya Alındı", isOn: $isSuspended)
                    if isSuspended {
                        TextField("Askı Nedeni", text: $suspensionReason)
                    }
                }
                Section("Günlük Özet") {
                    TextEditor(text: $workSummary).frame(height: 80)
                }
                Section("İmzalar") {
                    TextField("Yüklenici Temsilcisi", text: $contractorSig)
                    TextField("İdare Temsilcisi", text: $ownerSig)
                }
            }
            .navigationTitle("Günlük Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                }
            }
        }
    }

    private func save() {
        let entry = SiteLogEntry(
            logDate: logDate,
            weatherCondition: weather,
            isHoliday: isHoliday,
            isSuspended: isSuspended,
            workSummary: workSummary
        )
        if !contractorSig.isEmpty { entry.contractorSignature = contractorSig }
        if !ownerSig.isEmpty { entry.ownerSignature = ownerSig }
        if isSuspended { entry.suspensionReason = suspensionReason }
        entry.contract = contract
        context.insert(entry)
        contract.siteLogEntries.append(entry)
        dismiss()
    }
}
