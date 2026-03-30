import SwiftUI
import SwiftData

// MARK: - Test / Deney Sonuçları

struct TestRecordSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var failedTests: Int { contract.testRecords.filter { $0.status == .kaldi }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Test / Deney Sonuçları")

            if !contract.testRecords.isEmpty {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Geçti",
                        value: "\(contract.testRecords.filter { $0.status == .gecti }.count)",
                        color: .hakedisSuccess, icon: "checkmark.circle.fill"
                    )
                    StatCard(
                        title: "Kaldı",
                        value: "\(failedTests)",
                        color: failedTests > 0 ? .hakedisDanger : .hakedisSuccess,
                        icon: "xmark.circle.fill"
                    )
                    StatCard(
                        title: "Bekliyor",
                        value: "\(contract.testRecords.filter { $0.status == .bekliyor }.count)",
                        color: .hakedisWarning, icon: "clock.fill"
                    )
                }
            }

            if contract.testRecords.isEmpty {
                EmptyStateView(icon: "flask.fill", title: "Test Yok", subtitle: "Henüz deney/test kaydı bulunmuyor.")
            } else {
                ForEach(contract.testRecords.sorted { $0.testDate > $1.testDate }) { record in
                    TestRecordRow(record: record)
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Test Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTestRecordView(contract: contract)
        }
    }
}

struct TestRecordRow: View {
    let record: TestRecord

    var statusColor: Color {
        switch record.status {
        case .gecti:    return .hakedisSuccess
        case .kaldi:    return .hakedisDanger
        case .bekliyor: return .hakedisWarning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.testName).font(.subheadline.bold())
                    Text(record.category.rawValue).font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                StatusBadge(text: record.status.rawValue, color: statusColor)
            }
            HStack(spacing: 16) {
                if let result = record.result {
                    Label(String(format: "%.2f %@", result, record.unit), systemImage: "number")
                        .font(.caption)
                }
                if !record.laboratoryName.isEmpty {
                    Label(record.laboratoryName, systemImage: "building.2")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(record.status == .kaldi ? Color.hakedisDanger.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct AddTestRecordView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var testName = ""
    @State private var category: TestCategory = .beton
    @State private var location = ""
    @State private var sampleNo = ""
    @State private var laboratoryName = ""
    @State private var unit = ""
    @State private var minAcceptable = ""
    @State private var maxAcceptable = ""
    @State private var result = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Bilgisi") {
                    TextField("Test Adı", text: $testName)
                    Picker("Kategori", selection: $category) {
                        ForEach(TestCategory.allCases, id: \.self) { c in Text(c.rawValue).tag(c) }
                    }
                    TextField("Konum / Numune No", text: $sampleNo)
                    TextField("Laboratuvar", text: $laboratoryName)
                }
                Section("Sınır Değerler") {
                    TextField("Birim", text: $unit)
                    TextField("Min. Kabul Değeri", text: $minAcceptable).keyboardType(.decimalPad)
                    TextField("Max. Kabul Değeri", text: $maxAcceptable).keyboardType(.decimalPad)
                }
                Section("Sonuç") {
                    TextField("Ölçülen Değer", text: $result).keyboardType(.decimalPad)
                    if let r = Double(result) {
                        let minOK = Double(minAcceptable).map { r >= $0 } ?? true
                        let maxOK = Double(maxAcceptable).map { r <= $0 } ?? true
                        HStack {
                            Text("Değerlendirme")
                            Spacer()
                            Text(minOK && maxOK ? "Geçti" : "Kaldı")
                                .foregroundColor(minOK && maxOK ? .hakedisSuccess : .hakedisDanger)
                        }
                    }
                }
            }
            .navigationTitle("Test Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(testName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let record = TestRecord(testName: testName, category: category, location: location,
                                sampleNo: sampleNo, laboratoryName: laboratoryName, unit: unit)
        if let min = Double(minAcceptable) { record.minimumAcceptable = min }
        if let max = Double(maxAcceptable) { record.maximumAcceptable = max }
        if let r = Double(result) {
            record.result = r
            record.status = record.isInRange ? .gecti : .kaldi
        }
        record.contract = contract
        context.insert(record)
        contract.testRecords.append(record)
        dismiss()
    }
}
