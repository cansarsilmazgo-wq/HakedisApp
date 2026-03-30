import SwiftUI
import SwiftData

// MARK: - Garanti Süresi / Talep Takibi

struct WarrantyClaimSection: View {
    let acceptanceRecord: AcceptanceRecord

    @Environment(\.modelContext) private var context
    @State private var showAdd = false

    private var openClaims: [WarrantyClaim] {
        acceptanceRecord.warrantyClaims.filter { $0.isOpen }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Garanti Talepleri")

            if !acceptanceRecord.warrantyClaims.isEmpty {
                HStack(spacing: 12) {
                    StatCard(title: "Açık", value: "\(openClaims.count)", color: .hakedisDanger, icon: "exclamationmark.circle.fill")
                    StatCard(title: "Toplam", value: "\(acceptanceRecord.warrantyClaims.count)", color: .hakedisOrange, icon: "list.bullet")
                }
            }

            if acceptanceRecord.warrantyClaims.isEmpty {
                EmptyStateView(icon: "shield.fill", title: "Talep Yok", subtitle: "Henüz garanti talebi bulunmuyor.")
            } else {
                ForEach(acceptanceRecord.warrantyClaims.sorted { $0.claimDate > $1.claimDate }) { claim in
                    WarrantyClaimRow(claim: claim)
                }
            }

            Button {
                showAdd = true
            } label: {
                Label("Talep Ekle", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(.hakedisOrange)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddWarrantyClaimView(acceptanceRecord: acceptanceRecord)
        }
    }
}

struct WarrantyClaimRow: View {
    let claim: WarrantyClaim

    private var severityColor: Color {
        switch claim.severity {
        case .kritik:  return .hakedisDanger
        case .yuksek:  return .hakedisOrange
        case .orta:    return .hakedisWarning
        case .dusuk:   return .hakedisSuccess
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(claim.category.rawValue, systemImage: "shield.fill")
                    .font(.caption.bold())
                    .foregroundColor(severityColor)
                Spacer()
                StatusBadge(
                    text: claim.status.rawValue,
                    color: claim.status == .kapatildi ? .hakedisSuccess :
                           claim.isOverdue ? .hakedisDanger : .hakedisWarning
                )
            }
            Text(claim.claimDescription)
                .font(.subheadline)
                .lineLimit(2)
            HStack {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(claim.claimDate, style: .date)
                    .font(.caption2)
                if claim.isOverdue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.hakedisDanger)
                    Text("Gecikmiş")
                        .font(.caption2)
                        .foregroundColor(.hakedisDanger)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(claim.isOverdue ? Color.hakedisDanger.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct AddWarrantyClaimView: View {
    let acceptanceRecord: AcceptanceRecord

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var claimDescription = ""
    @State private var category: ClaimCategory = .diger
    @State private var severity: ClaimSeverity = .orta
    @State private var location = ""
    @State private var hasDeadline = false
    @State private var responseDeadline = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Talep") {
                    TextEditor(text: $claimDescription).frame(height: 80)
                    TextField("Konum", text: $location)
                }
                Section("Sınıflandırma") {
                    Picker("Kategori", selection: $category) {
                        ForEach(ClaimCategory.allCases, id: \.self) { c in Text(c.rawValue).tag(c) }
                    }
                    Picker("Önem", selection: $severity) {
                        ForEach(ClaimSeverity.allCases, id: \.self) { s in Text(s.rawValue).tag(s) }
                    }
                }
                Section("Son Tarih") {
                    Toggle("Cevap Tarihi Belirt", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Son Tarih", selection: $responseDeadline, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Garanti Talebi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(claimDescription.isEmpty)
                }
            }
        }
    }

    private func save() {
        let claim = WarrantyClaim(
            claimDescription: claimDescription,
            category: category,
            severity: severity,
            location: location
        )
        if hasDeadline { claim.responseDeadline = responseDeadline }
        claim.acceptanceRecord = acceptanceRecord
        context.insert(claim)
        acceptanceRecord.warrantyClaims.append(claim)
        dismiss()
    }
}
