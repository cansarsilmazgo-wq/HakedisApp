import SwiftUI
import SwiftData

// MARK: - Geçici / Kesin Kabul

struct AcceptanceSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Geçici / Kesin Kabul")

            if contract.acceptanceRecords.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "Kabul Tutanağı Yok",
                    subtitle: "Henüz kabul tutanağı bulunmuyor."
                )
            } else {
                ForEach(contract.acceptanceRecords.sorted { $0.acceptanceDate > $1.acceptanceDate }) { record in
                    AcceptanceRow(record: record)
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Kabul Tutanağı Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAcceptanceView(contract: contract)
        }
    }
}

struct AcceptanceRow: View {
    let record: AcceptanceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(record.acceptanceType.rawValue, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.hakedisOrange)
                Spacer()
                StatusBadge(
                    text: record.isWarrantyActive ? "Garanti Aktif" : "Garanti Sona Erdi",
                    color: record.isWarrantyActive ? .hakedisSuccess : .secondary
                )
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kabul Tarihi").font(.caption2).foregroundColor(.secondary)
                    Text(record.acceptanceDate, style: .date).font(.caption.bold())
                }
                if let end = record.warrantyEndDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Garanti Sonu").font(.caption2).foregroundColor(.secondary)
                        Text(end, style: .date)
                            .font(.caption.bold())
                            .foregroundColor(record.isWarrantyActive ? .hakedisSuccess : .secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kalan").font(.caption2).foregroundColor(.secondary)
                    Text("\(record.warrantyDaysLeft) gün")
                        .font(.caption.bold())
                        .foregroundColor(record.warrantyDaysLeft < 30 ? .hakedisDanger : .hakedisSuccess)
                }
            }
            if !record.warrantyClaims.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.hakedisWarning)
                    Text("\(record.warrantyClaims.filter { $0.isOpen }.count) açık garanti talebi")
                        .font(.caption2)
                        .foregroundColor(.hakedisWarning)
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddAcceptanceView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var acceptanceType: AcceptanceType = .gecici
    @State private var acceptanceDate = Date()
    @State private var warrantyMonths = "24"
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Kabul Türü") {
                    Picker("Tür", selection: $acceptanceType) {
                        ForEach(AcceptanceType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Tarih") {
                    DatePicker("Kabul Tarihi", selection: $acceptanceDate, displayedComponents: .date)
                }
                Section("Garanti") {
                    HStack {
                        TextField("Garanti Süresi (ay)", text: $warrantyMonths).keyboardType(.numberPad)
                        Text("ay").foregroundColor(.secondary)
                    }
                    if let months = Int(warrantyMonths) {
                        let endDate = Calendar.current.date(byAdding: .month, value: months, to: acceptanceDate)
                        if let end = endDate {
                            HStack {
                                Text("Garanti Bitiş")
                                Spacer()
                                Text(end, style: .date).foregroundColor(.hakedisSuccess)
                            }
                        }
                    }
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(height: 70)
                }
            }
            .navigationTitle("Kabul Tutanağı")
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
        let months = Int(warrantyMonths) ?? 24
        let record = AcceptanceRecord(
            acceptanceType: acceptanceType,
            acceptanceDate: acceptanceDate,
            warrantyMonths: months
        )
        record.notes = notes
        record.contract = contract
        context.insert(record)
        contract.acceptanceRecords.append(record)
        dismiss()
    }
}
