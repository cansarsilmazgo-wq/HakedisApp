import SwiftUI
import SwiftData
import Charts

// MARK: - LaborTrackingSection

struct LaborTrackingSection: View {
    let contract: Contract
    @State private var showAddSheet = false
    @State private var showAllList = false

    private var sortedRecords: [LaborRecord] {
        contract.laborRecords.sorted { $0.date > $1.date }
    }

    private var totalManDays: Double {
        contract.laborRecords.reduce(0) { $0 + $1.totalManDays }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("İşçilik Puantajı")
                        .font(.headline)
                    Text("Toplam \(totalManDays.quantityFormatted) adam-gün")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if !contract.laborRecords.isEmpty {
                    Button("Tümünü Gör") { showAllList = true }
                        .font(.subheadline)
                        .foregroundColor(.hakedisOrange)
                }
            }

            if sortedRecords.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: "Puantaj Yok",
                    subtitle: "Henüz işçilik kaydı girilmemiş.",
                    actionTitle: "Puantaj Ekle",
                    action: { showAddSheet = true }
                )
                .padding(.vertical, 8)
            } else {
                ForEach(sortedRecords.prefix(3)) { record in
                    LaborRecordRow(record: record)
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("Puantaj Ekle", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.hakedisOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.hakedisOrange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .navigationDestination(isPresented: $showAllList) {
            LaborRecordListView(contract: contract)
        }
        .sheet(isPresented: $showAddSheet) {
            AddLaborRecordView(contract: contract)
        }
    }
}

// MARK: - LaborRecordRow

private struct LaborRecordRow: View {
    let record: LaborRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.date.shortFormatted)
                    .font(.subheadline.bold())
                if let supervisor = record.supervisorName, !supervisor.isEmpty {
                    Text(supervisor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(record.totalWorkers) işçi")
                    .font(.subheadline.bold())
                Text("\(record.totalManDays.quantityFormatted) adam-gün")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if record.sgkNotified {
                StatusBadge(text: "SGK", color: .hakedisSuccess)
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - LaborRecordListView

struct LaborRecordListView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @State private var showWeeklySummary = false

    private var sortedRecords: [LaborRecord] {
        contract.laborRecords.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if sortedRecords.isEmpty {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: "Puantaj Kaydı Yok",
                    subtitle: "Henüz hiç işçilik puantaj kaydı eklenmemiş."
                )
            } else {
                List {
                    ForEach(sortedRecords) { record in
                        NavigationLink(destination: LaborRecordDetailView(record: record)) {
                            LaborRecordListRow(record: record)
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Puantaj Kayıtları")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showWeeklySummary = true
                } label: {
                    Label("Haftalık Özet", systemImage: "calendar.badge.clock")
                }
                .disabled(sortedRecords.isEmpty)
            }
        }
        .navigationDestination(isPresented: $showWeeklySummary) {
            LaborWeeklySummaryView(contract: contract)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            let record = sortedRecords[index]
            modelContext.delete(record)
        }
    }
}

// MARK: - LaborRecordListRow

private struct LaborRecordListRow: View {
    let record: LaborRecord

    private var workerTypeSummary: String {
        let entries = record.laborEntries
        if entries.isEmpty { return "—" }
        let parts = entries.map { "\($0.count) \($0.workerType.rawValue)" }
        return parts.prefix(3).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.date.shortFormatted)
                    .font(.subheadline.bold())
                Spacer()
                if record.sgkNotified {
                    StatusBadge(text: "SGK Bildirildi", color: .hakedisSuccess)
                }
            }

            HStack(spacing: 16) {
                Label("\(record.totalWorkers) İşçi", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(record.totalManDays.quantityFormatted) Adam-Gün", systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if record.totalLaborCost > 0 {
                Text(record.totalLaborCost.currencyFormatted)
                    .font(.caption)
                    .foregroundColor(.hakedisOrange)
            }

            if !workerTypeSummary.isEmpty {
                Text(workerTypeSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - LaborRecordDetailView

private struct LaborRecordDetailView: View {
    let record: LaborRecord

    var body: some View {
        List {
            Section("Genel Bilgiler") {
                LabeledContent("Tarih", value: record.date.shortFormatted)
                if let supervisor = record.supervisorName, !supervisor.isEmpty {
                    LabeledContent("Şef/Nezaretçi", value: supervisor)
                }
                if let weather = record.weather, !weather.isEmpty {
                    LabeledContent("Hava Durumu", value: weather)
                }
                LabeledContent("SGK Bildirimi") {
                    StatusBadge(
                        text: record.sgkNotified ? "Yapıldı" : "Yapılmadı",
                        color: record.sgkNotified ? .hakedisSuccess : .hakedisWarning
                    )
                }
            }

            Section("Özet") {
                LabeledContent("Toplam İşçi", value: "\(record.totalWorkers) kişi")
                LabeledContent("Adam-Gün", value: record.totalManDays.quantityFormatted)
                if record.totalLaborCost > 0 {
                    LabeledContent("Toplam Maliyet", value: record.totalLaborCost.currencyFormatted)
                }
            }

            if !record.laborEntries.isEmpty {
                Section("Personel Detayı") {
                    ForEach(record.laborEntries) { entry in
                        LaborEntryDetailRow(entry: entry)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Puantaj Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LaborEntryDetailRow: View {
    let entry: LaborEntryData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.workerType.icon)
                .foregroundColor(.hakedisOrange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.workerType.rawValue)
                    .font(.subheadline.bold())
                HStack(spacing: 8) {
                    Text("\(entry.hoursWorked.quantityFormatted) saat")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    StatusBadge(text: entry.shiftType.rawValue, color: shiftColor(entry.shiftType))
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.count) kişi")
                    .font(.subheadline.bold())
                Text("\(entry.manDays.quantityFormatted) a-g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if let cost = entry.dailyCost {
                    Text(cost.currencyFormatted)
                        .font(.caption2)
                        .foregroundColor(.hakedisOrange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func shiftColor(_ shift: WorkShiftType) -> Color {
        switch shift {
        case .gunduz: return .hakedisSuccess
        case .gece:   return .hakedisWarning
        case .mesai:  return .hakedisDanger
        }
    }
}

// MARK: - AddLaborRecordView

struct AddLaborRecordView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var entries: [LaborEntryData] = []
    @State private var weather: String = ""
    @State private var supervisorName: String = ""
    @State private var sgkNotified: Bool = false

    private var totalWorkers: Int { entries.reduce(0) { $0 + $1.count } }
    private var totalManDays: Double { entries.reduce(0) { $0 + $1.manDays } }
    private var totalCost: Double { entries.compactMap { $0.dailyCost }.reduce(0, +) }

    var body: some View {
        NavigationStack {
            Form {
                // Tarih
                Section("Tarih") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                }

                // Personel Girişleri
                Section {
                    ForEach($entries) { $entry in
                        LaborEntryFormRow(entry: $entry)
                            .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        entries.remove(atOffsets: offsets)
                    }

                    Button {
                        let newEntry = LaborEntryData(
                            id: UUID(),
                            workerType: .usta,
                            count: 1,
                            hoursWorked: 8,
                            shiftType: .gunduz
                        )
                        entries.append(newEntry)
                    } label: {
                        Label("Personel Türü Ekle", systemImage: "plus.circle.fill")
                            .foregroundColor(.hakedisOrange)
                    }
                } header: {
                    Text("Personel")
                } footer: {
                    if !entries.isEmpty {
                        Text("Satırı silmek için sola kaydırın.")
                            .font(.caption2)
                    }
                }

                // Genel Bilgiler
                Section("Saha Bilgileri") {
                    HStack {
                        Label("Hava Durumu", systemImage: "cloud.sun.fill")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                        TextField("Güneşli, Yağmurlu…", text: $weather)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                    }

                    HStack {
                        Label("Nezaretçi", systemImage: "person.badge.shield.checkmark.fill")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                        TextField("Ad Soyad", text: $supervisorName)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline)
                    }

                    Toggle(isOn: $sgkNotified) {
                        Label("SGK Bildirimi Yapıldı", systemImage: "checkmark.seal.fill")
                    }
                    .tint(.hakedisSuccess)
                }

                // Canlı Önizleme
                if !entries.isEmpty {
                    Section("Özet Önizleme") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Toplam İşçi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalWorkers) kişi")
                                    .font(.title3.bold())
                                    .foregroundColor(.hakedisOrange)
                            }
                            Spacer()
                            VStack(alignment: .center, spacing: 4) {
                                Text("Adam-Gün")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(totalManDays.quantityFormatted)
                                    .font(.title3.bold())
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Maliyet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(totalCost > 0 ? totalCost.currencyFormatted : "—")
                                    .font(.title3.bold())
                                    .foregroundColor(.hakedisSuccess)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Puantaj Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .bold()
                        .disabled(entries.isEmpty)
                }
            }
        }
    }

    private func save() {
        let record = LaborRecord(date: date)
        record.weather = weather.isEmpty ? nil : weather
        record.supervisorName = supervisorName.isEmpty ? nil : supervisorName
        record.sgkNotified = sgkNotified
        record.contract = contract

        let encoded = try? JSONEncoder().encode(entries)
        record.laborEntriesJSON = encoded.flatMap { String(data: $0, encoding: .utf8) }

        modelContext.insert(record)
        dismiss()
    }
}

// MARK: - LaborEntryFormRow

private struct LaborEntryFormRow: View {
    @Binding var entry: LaborEntryData

    private let hourOptions: [Double] = [6, 8, 10, 12]
    @State private var costText: String = ""
    @State private var notesText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // İşçi Tipi
            HStack {
                Image(systemName: entry.workerType.icon)
                    .foregroundColor(.hakedisOrange)
                    .frame(width: 20)
                Text("Tür:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $entry.workerType) {
                    ForEach(WorkerType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .font(.subheadline)
            }

            // Sayı & Mesai
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kişi Sayısı")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Stepper("\(entry.count) kişi", value: $entry.count, in: 1...100)
                        .font(.subheadline)
                }
            }

            // Çalışma Saati
            VStack(alignment: .leading, spacing: 4) {
                Text("Çalışma Saati")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Picker("", selection: $entry.hoursWorked) {
                    ForEach(hourOptions, id: \.self) { h in
                        Text("\(Int(h)) saat").tag(h)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Vardiya
            VStack(alignment: .leading, spacing: 4) {
                Text("Vardiya")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Picker("", selection: $entry.shiftType) {
                    ForEach(WorkShiftType.allCases, id: \.self) { shift in
                        Text(shift.rawValue).tag(shift)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Günlük Maliyet (opsiyonel)
            HStack {
                Text("Günlük Maliyet (₺)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("Opsiyonel", text: $costText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline)
                    .frame(width: 120)
                    .onChange(of: costText) { _, newVal in
                        let normalized = newVal.replacingOccurrences(of: ",", with: ".")
                        entry.dailyCost = Double(normalized)
                    }
            }

            // Notlar
            HStack {
                Text("Not")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                TextField("Opsiyonel", text: $notesText)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline)
                    .onChange(of: notesText) { _, newVal in
                        entry.notes = newVal.isEmpty ? nil : newVal
                    }
            }

            // Adam-Gün hesabı
            HStack {
                Spacer()
                Text("Adam-Gün: \(entry.manDays.quantityFormatted)")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if let cost = entry.dailyCost { costText = String(cost) }
            notesText = entry.notes ?? ""
        }
    }
}

// MARK: - LaborWeeklySummaryView

struct LaborWeeklySummaryView: View {
    let contract: Contract

    struct WeekData: Identifiable {
        let id = UUID()
        let weekLabel: String
        let weekStart: Date
        let records: [LaborRecord]

        var totalManDays: Double { records.reduce(0) { $0 + $1.totalManDays } }
        var totalWorkers: Int { records.reduce(0) { $0 + $1.totalWorkers } }
        var totalCost: Double { records.reduce(0) { $0 + $1.totalLaborCost } }
        var sgkCount: Int { records.filter { $0.sgkNotified }.count }
    }

    private struct DailyChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let workerCount: Int
        let weekLabel: String
    }

    private var weeklyData: [WeekData] {
        let cal = Calendar.current
        let sorted = contract.laborRecords.sorted { $0.date > $1.date }
        guard !sorted.isEmpty else { return [] }

        var weeks: [WeekData] = []
        for weekOffset in 0..<4 {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: cal.startOfWeek(for: Date())),
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)
            else { continue }

            let weekRecords = sorted.filter { $0.date >= weekStart && $0.date <= weekEnd }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "d MMM"
            let label = "\(formatter.string(from: weekStart))–\(formatter.string(from: weekEnd))"
            weeks.append(WeekData(weekLabel: label, weekStart: weekStart, records: weekRecords))
        }
        return weeks.reversed()
    }

    private var chartPoints: [DailyChartPoint] {
        weeklyData.flatMap { week in
            week.records.map { record in
                DailyChartPoint(
                    date: record.date,
                    workerCount: record.totalWorkers,
                    weekLabel: week.weekLabel
                )
            }
        }
    }

    private var sgkSummaryText: String {
        var lines: [String] = []
        lines.append("SGK İŞÇİLİK ÖZET RAPORU")
        lines.append("Sözleşme: \(contract.title)")
        lines.append("Oluşturma Tarihi: \(Date().shortFormatted)")
        lines.append("")
        for week in weeklyData {
            lines.append("Hafta: \(week.weekLabel)")
            lines.append("  Toplam İşçi: \(week.totalWorkers)")
            lines.append("  Adam-Gün: \(week.totalManDays.quantityFormatted)")
            lines.append("  SGK Bildirilen Gün: \(week.sgkCount)")
            if week.totalCost > 0 {
                lines.append("  Tahmini Maliyet: \(week.totalCost.currencyFormatted)")
            }
            lines.append("")
        }
        let grandManDays = weeklyData.reduce(0) { $0 + $1.totalManDays }
        let grandCost = weeklyData.reduce(0) { $0 + $1.totalCost }
        lines.append("GENEL TOPLAM")
        lines.append("  Adam-Gün: \(grandManDays.quantityFormatted)")
        if grandCost > 0 {
            lines.append("  Toplam Maliyet: \(grandCost.currencyFormatted)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if weeklyData.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.exclamationmark",
                        title: "Veri Yok",
                        subtitle: "Son 4 haftaya ait puantaj kaydı bulunamadı."
                    )
                } else {
                    // Grafik
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Günlük İşçi Sayısı (Son 4 Hafta)")

                        if !chartPoints.isEmpty {
                            Chart(chartPoints) { point in
                                BarMark(
                                    x: .value("Tarih", point.date, unit: .day),
                                    y: .value("İşçi", point.workerCount)
                                )
                                .foregroundStyle(by: .value("Hafta", point.weekLabel))
                                .cornerRadius(4)
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisValueLabel(format: .dateTime.day())
                                }
                            }
                            .chartForegroundStyleScale(range: [.hakedisOrange, .hakedisSuccess, .hakedisWarning, Color.blue.opacity(0.7)])
                            .frame(height: 200)
                            .padding(.horizontal, 4)
                        } else {
                            Text("Grafik için günlük kayıt gerekli.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)
                        }
                    }
                    .padding(16)
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Haftalık Tablo
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Haftalık Özet Tablosu")

                        ForEach(weeklyData) { week in
                            WeekSummaryCard(week: week)
                        }
                    }

                    // Paylaş Butonu
                    ShareLink(
                        item: sgkSummaryText,
                        subject: Text("SGK İşçilik Özeti"),
                        message: Text("Sözleşme: \(contract.title)")
                    ) {
                        Label("SGK Özeti Oluştur", systemImage: "square.and.arrow.up.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.hakedisOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(16)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Haftalık Özet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WeekSummaryCard

private struct WeekSummaryCard: View {
    let week: LaborWeeklySummaryView.WeekData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(week.weekLabel)
                    .font(.subheadline.bold())
                Spacer()
                if week.sgkCount > 0 {
                    StatusBadge(text: "SGK: \(week.sgkCount) gün", color: .hakedisSuccess)
                }
            }

            if week.records.isEmpty {
                Text("Bu hafta kayıt yok.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 0) {
                    WeekStatItem(label: "İşçi", value: "\(week.totalWorkers)")
                    Divider().frame(height: 30)
                    WeekStatItem(label: "Adam-Gün", value: week.totalManDays.quantityFormatted)
                    if week.totalCost > 0 {
                        Divider().frame(height: 30)
                        WeekStatItem(label: "Maliyet", value: week.totalCost.shortFormatted)
                    }
                }

                // Gün bazında mini tablo
                VStack(spacing: 4) {
                    ForEach(week.records.sorted { $0.date < $1.date }) { record in
                        HStack {
                            Text(record.date.shortFormatted)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text("\(record.totalWorkers) kişi")
                                .font(.caption2)
                            Spacer()
                            Text("\(record.totalManDays.quantityFormatted) a-g")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            if record.sgkNotified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundColor(.hakedisSuccess)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct WeekStatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - LaborAnalysisSection

struct LaborAnalysisSection: View {
    let contracts: [Contract]

    private struct WeekTrend: Identifiable {
        let id = UUID()
        let weekLabel: String
        let weekStart: Date
        let totalWorkers: Int
        let totalManDays: Double
    }

    private var allRecords: [LaborRecord] {
        contracts.flatMap { $0.laborRecords }
    }

    private var totalManDays: Double {
        allRecords.reduce(0) { $0 + $1.totalManDays }
    }

    private var avgDailyWorkers: Double {
        guard !allRecords.isEmpty else { return 0 }
        return Double(allRecords.reduce(0) { $0 + $1.totalWorkers }) / Double(allRecords.count)
    }

    private var workerTypeDistribution: [(type: WorkerType, count: Int)] {
        var dist: [WorkerType: Int] = [:]
        for record in allRecords {
            for entry in record.laborEntries {
                dist[entry.workerType, default: 0] += entry.count
            }
        }
        return WorkerType.allCases
            .compactMap { type -> (WorkerType, Int)? in
                guard let count = dist[type], count > 0 else { return nil }
                return (type, count)
            }
            .sorted { $0.1 > $1.1 }
    }

    private var topWorkerType: WorkerType? { workerTypeDistribution.first?.type }

    private var weeklyTrend: [WeekTrend] {
        let cal = Calendar.current
        var trends: [WeekTrend] = []
        for weekOffset in (0..<8).reversed() {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: cal.startOfWeek(for: Date())),
                  let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)
            else { continue }

            let weekRecords = allRecords.filter { $0.date >= weekStart && $0.date <= weekEnd }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "d MMM"
            let label = formatter.string(from: weekStart)

            trends.append(WeekTrend(
                weekLabel: label,
                weekStart: weekStart,
                totalWorkers: weekRecords.reduce(0) { $0 + $1.totalWorkers },
                totalManDays: weekRecords.reduce(0) { $0 + $1.totalManDays }
            ))
        }
        return trends
    }

    private var totalSgkDays: Int {
        allRecords.filter { $0.sgkNotified }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader("İşçilik Analizi")

            if allRecords.isEmpty {
                EmptyStateView(
                    icon: "person.3.sequence.fill",
                    title: "Puantaj Verisi Yok",
                    subtitle: "Henüz hiç işçilik puantaj kaydı girilmemiş."
                )
            } else {
                // 4 Stat Kart
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        title: "Toplam Adam-Gün",
                        value: totalManDays.quantityFormatted,
                        subtitle: "\(allRecords.count) kayıt",
                        color: .hakedisOrange,
                        icon: "clock.fill"
                    )
                    StatCard(
                        title: "Ort. Günlük İşçi",
                        value: String(format: "%.1f kişi", avgDailyWorkers),
                        subtitle: "Tüm sözleşmeler",
                        color: .hakedisSuccess,
                        icon: "person.fill"
                    )
                    StatCard(
                        title: "En Çok Kullanılan",
                        value: topWorkerType?.rawValue ?? "—",
                        subtitle: topWorkerType.map { _ in
                            let count = workerTypeDistribution.first?.count ?? 0
                            return "\(count) kişi-gün"
                        },
                        color: .hakedisWarning,
                        icon: topWorkerType?.icon ?? "person.fill"
                    )
                    StatCard(
                        title: "SGK Bildirilen",
                        value: "\(totalSgkDays) gün",
                        subtitle: allRecords.count > 0 ? String(format: "%.0f%% oranında", Double(totalSgkDays) / Double(allRecords.count) * 100) : "—",
                        color: .hakedisSuccess,
                        icon: "checkmark.seal.fill"
                    )
                }

                // İşçi Tipi Dağılımı
                if !workerTypeDistribution.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personel Tipi Dağılımı")
                            .font(.subheadline.bold())

                        let totalCount = workerTypeDistribution.reduce(0) { $0 + $1.count }
                        ForEach(workerTypeDistribution, id: \.type) { item in
                            HStack(spacing: 10) {
                                Image(systemName: item.type.icon)
                                    .foregroundColor(.hakedisOrange)
                                    .frame(width: 20)
                                Text(item.type.rawValue)
                                    .font(.subheadline)
                                    .frame(width: 80, alignment: .leading)
                                ProgressBarView(
                                    progress: totalCount > 0 ? Double(item.count) / Double(totalCount) * 100 : 0,
                                    color: .hakedisOrange
                                )
                                Text("\(item.count)")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.hakedisCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Haftalık Trend Grafiği
                VStack(alignment: .leading, spacing: 8) {
                    Text("Son 8 Hafta Trendi")
                        .font(.subheadline.bold())

                    let hasData = weeklyTrend.contains { $0.totalWorkers > 0 }
                    if hasData {
                        Chart(weeklyTrend) { week in
                            BarMark(
                                x: .value("Hafta", week.weekLabel),
                                y: .value("İşçi", week.totalWorkers)
                            )
                            .foregroundStyle(Color.hakedisOrange.gradient)
                            .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel()
                                    .font(.system(size: 9))
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisValueLabel()
                                    .font(.caption2)
                            }
                        }
                        .frame(height: 180)
                    } else {
                        Text("Son 8 haftada kayıt bulunamadı.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    }
                }
                .padding(14)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Calendar Extension

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        var components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = firstWeekday
        return self.date(from: components) ?? date
    }
}

// MARK: - Double shortFormatted (local extension guard)

private extension Double {
    var shortFormatted: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM ₺", self / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK ₺", self / 1_000)
        } else {
            return currencyFormatted
        }
    }
}
