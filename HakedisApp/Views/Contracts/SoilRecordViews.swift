import SwiftUI
import SwiftData

// MARK: - Zemin / Kazı Tutanağı

struct SoilRecordSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var notReadyCount: Int {
        contract.soilRecords.filter { !$0.canBeIncludedInHakedis }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Zemin / Kazı Tutanakları")

            if notReadyCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.hakedisWarning)
                    Text("\(notReadyCount) tutanak hakediş için hazır değil (imza/fotoğraf eksik)")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisWarning)
                }
                .padding(10)
                .background(Color.hakedisWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if contract.soilRecords.isEmpty {
                EmptyStateView(
                    icon: "square.3.layers.3d.down.backward",
                    title: "Tutanak Yok",
                    subtitle: "Henüz zemin kazı tutanağı bulunmuyor."
                )
            } else {
                ForEach(contract.soilRecords.sorted { $0.recordDate > $1.recordDate }) { record in
                    SoilRecordRow(record: record)
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Tutanak Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddSoilRecordView(contract: contract)
        }
    }
}

struct SoilRecordRow: View {
    let record: SoilRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.location.isEmpty ? "Konum Yok" : record.location)
                    .font(.subheadline.bold())
                Spacer()
                Text(record.recordDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 16) {
                Label(String(format: "D: %.1f m", record.depth), systemImage: "arrow.down")
                    .font(.caption)
                Label(String(format: "A: %.1f m²", record.area), systemImage: "square")
                    .font(.caption)
                Label(String(format: "%.1f m³", record.calculatedVolume), systemImage: "cube")
                    .font(.caption.bold())
                    .foregroundColor(.hakedisOrange)
            }
            .foregroundColor(.secondary)
            if !record.soilType.isEmpty {
                Text("Zemin: \(record.soilType)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if !record.labTests.isEmpty {
                HStack {
                    Image(systemName: "flask.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(record.labTests.count) laboratuvar testi")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddSoilRecordView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var recordDate = Date()
    @State private var location = ""
    @State private var depth = ""
    @State private var area = ""
    @State private var soilType = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tutanak") {
                    DatePicker("Tarih", selection: $recordDate, displayedComponents: .date)
                    TextField("Konum / Aks", text: $location)
                }
                Section("Ölçüler") {
                    TextField("Derinlik (m)", text: $depth).keyboardType(.decimalPad)
                    TextField("Alan (m²)", text: $area).keyboardType(.decimalPad)
                    if let d = Double(depth), let a = Double(area) {
                        HStack {
                            Text("Hesaplanan Hacim")
                            Spacer()
                            Text(String(format: "%.2f m³", d * a))
                                .foregroundColor(.hakedisOrange)
                        }
                    }
                }
                Section("Zemin") {
                    TextField("Zemin Türü", text: $soilType)
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(height: 70)
                }
            }
            .navigationTitle("Zemin Tutanağı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(location.isEmpty || depth.isEmpty || area.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let d = Double(depth), let a = Double(area) else { return }
        let record = SoilRecord(recordDate: recordDate, location: location, depth: d, area: a, soilType: soilType)
        record.notes = notes
        record.contract = contract
        context.insert(record)
        contract.soilRecords.append(record)
        dismiss()
    }
}
