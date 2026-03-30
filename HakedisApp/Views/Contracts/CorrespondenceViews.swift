import SwiftUI
import SwiftData

// MARK: - Yazışma / Evrak Takibi

struct CorrespondenceSection: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var overdueRecords: [CorrespondenceRecord] {
        contract.correspondenceRecords.filter { $0.isSureDoldu }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Yazışma / Evrak Takibi")

            if !overdueRecords.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge.fill")
                        .foregroundColor(.hakedisDanger)
                    Text("\(overdueRecords.count) yazışmada cevap süresi doldu")
                        .font(.caption.bold())
                        .foregroundColor(.hakedisDanger)
                }
                .padding(10)
                .background(Color.hakedisDanger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if contract.correspondenceRecords.isEmpty {
                EmptyStateView(
                    icon: "envelope.fill",
                    title: "Yazışma Yok",
                    subtitle: "Henüz kayıtlı yazışma bulunmuyor."
                )
            } else {
                ForEach(contract.correspondenceRecords.sorted { $0.documentDate > $1.documentDate }) { record in
                    CorrespondenceRow(record: record)
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Yazışma Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddCorrespondenceView(contract: contract)
        }
    }
}

struct CorrespondenceRow: View {
    let record: CorrespondenceRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.direction == .gelen ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundColor(record.direction == .gelen ? .blue : .hakedisOrange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.recordNo)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    StatusBadge(
                        text: record.isReplied ? "Cevaplandı" : (record.isOverdue ? "Gecikmiş" : "Bekliyor"),
                        color: record.isReplied ? .hakedisSuccess : (record.isOverdue ? .hakedisDanger : .hakedisWarning)
                    )
                }
                Text(record.subject)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                HStack {
                    Text(record.direction.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(record.category.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let daysLeft = record.daysLeft, !record.isReplied {
                        Spacer()
                        Text("\(daysLeft) gün kaldı")
                            .font(.caption2)
                            .foregroundColor(daysLeft <= 3 ? .hakedisDanger : .secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(record.isOverdue ? Color.hakedisDanger.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct AddCorrespondenceView: View {
    let contract: Contract

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var recordNo = ""
    @State private var subject = ""
    @State private var direction: CorrespondenceDirection = .gelen
    @State private var category: CorrespondenceCategory = .idari
    @State private var senderName = ""
    @State private var receiverName = ""
    @State private var hasDeadline = false
    @State private var replyDeadline = Date()
    @State private var summary = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel Bilgiler") {
                    TextField("Evrak No (YZ-2026-001)", text: $recordNo)
                    TextField("Konu", text: $subject)
                    Picker("Yön", selection: $direction) {
                        ForEach(CorrespondenceDirection.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    Picker("Kategori", selection: $category) {
                        ForEach(CorrespondenceCategory.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }
                Section("Taraflar") {
                    TextField("Gönderen", text: $senderName)
                    TextField("Alıcı", text: $receiverName)
                }
                Section("Cevap") {
                    Toggle("Cevap Gerektiriyor", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Son Tarih", selection: $replyDeadline, displayedComponents: .date)
                    }
                }
                Section("Özet") {
                    TextEditor(text: $summary).frame(height: 80)
                }
            }
            .navigationTitle("Yazışma Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(recordNo.isEmpty || subject.isEmpty)
                }
            }
        }
    }

    private func save() {
        let record = CorrespondenceRecord(
            recordNo: recordNo,
            subject: subject,
            direction: direction,
            category: category,
            senderName: senderName,
            receiverName: receiverName
        )
        record.summary = summary
        if hasDeadline { record.replyDeadline = replyDeadline }
        record.contract = contract
        context.insert(record)
        contract.correspondenceRecords.append(record)
        dismiss()
    }
}
