import SwiftUI
import SwiftData
import Charts

// MARK: - Onay Durumu Hesaplama Yardımcıları

private extension Hakedis {
    /// Tüm adımlar onaylandıysa tam onay, herhangi biri reddedildiyse red, aksi bekliyor
    var approvalOutcome: ApprovalOutcome {
        guard !approvalSteps.isEmpty else { return .bekliyor }
        if approvalSteps.allSatisfy({ $0.status == .onaylandi }) { return .tamOnay }
        if approvalSteps.contains(where: { $0.status == .reddedildi }) { return .reddedildi }
        return .bekliyor
    }

    var approvedStepCount: Int { approvalSteps.filter { $0.status == .onaylandi }.count }
    var rejectedStepCount: Int { approvalSteps.filter { $0.status == .reddedildi }.count }
    var pendingStepCount:  Int { approvalSteps.filter { $0.status == .bekliyor }.count }

    var lastRevisionVersion: String {
        revisions.sorted { $0.createdAt < $1.createdAt }.last?.version ?? "v1.0"
    }

    var rejectedSteps: [ApprovalStep] {
        approvalSteps.filter { $0.status == .reddedildi }
    }
}

enum ApprovalOutcome {
    case tamOnay, bekliyor, reddedildi

    var label: String {
        switch self {
        case .tamOnay:    return "Tam Onay"
        case .bekliyor:   return "Bekliyor"
        case .reddedildi: return "Reddedildi"
        }
    }

    var color: Color {
        switch self {
        case .tamOnay:    return .hakedisSuccess
        case .bekliyor:   return .hakedisWarning
        case .reddedildi: return .hakedisDanger
        }
    }

    var icon: String {
        switch self {
        case .tamOnay:    return "checkmark.seal.fill"
        case .bekliyor:   return "clock.fill"
        case .reddedildi: return "xmark.seal.fill"
        }
    }
}

// MARK: - HakedisApprovalAnalysisView
// (Tek bir hakedişin onay durumu ve idare kararı analizi — dönem karşılaştırması
//  için ComparisonAndGallery.swift içindeki HakedisComparisonView'e bakın)

struct HakedisApprovalAnalysisView: View {
    let hakedis: Hakedis

    @State private var showItirazAlert = false
    @State private var selectedItirazStep: ApprovalStep?

    // MARK: Hesaplamalar

    private var outcome: ApprovalOutcome { hakedis.approvalOutcome }

    private var idareSonucu: String {
        let a = hakedis.approvedStepCount
        let r = hakedis.rejectedStepCount
        let total = hakedis.approvalSteps.count
        if total == 0 { return "Adım yok" }
        return "\(a) onay / \(r) red"
    }

    private var onayDurumu: String {
        let approved = hakedis.approvedStepCount
        let total    = hakedis.approvalSteps.count
        return "\(approved)/\(total)"
    }

    private var last5Hakedisler: [Hakedis] {
        guard let contract = hakedis.contract else { return [hakedis] }
        return contract.hakedisler
            .sorted { $0.periodEnd < $1.periodEnd }
            .suffix(5)
            .map { $0 }
    }

    private var hasMultiplePeriods: Bool { last5Hakedisler.count > 1 }

    // MARK: Share Text

    private var shareText: String {
        var lines: [String] = []
        lines.append("HAKEDİŞ KARŞILAŞTIRMA RAPORU")
        lines.append("==============================")
        lines.append("Dönem       : \(hakedis.periodName)")
        lines.append("Sözleşme    : \(hakedis.contract?.title ?? "—")")
        lines.append("Tarih Aralığı: \(hakedis.periodStart.shortFormatted) – \(hakedis.periodEnd.shortFormatted)")
        lines.append("")
        lines.append("ÖZET")
        lines.append("------")
        lines.append("Toplam Talep  : \(hakedis.grossAmount.currencyFormatted)")
        lines.append("İdare Kararı  : \(idareSonucu)")
        lines.append("Onay Durumu   : \(onayDurumu)")
        lines.append("Son Versiyon  : \(hakedis.lastRevisionVersion)")
        lines.append("")
        lines.append("KALEMLERfark")
        lines.append("------")
        for item in hakedis.items.sorted(by: { $0.workItemCode < $1.workItemCode }) {
            let durum: String
            switch outcome {
            case .tamOnay:    durum = "Tam Onay"
            case .reddedildi: durum = "Reddedildi"
            case .bekliyor:   durum = "Bekliyor"
            }
            lines.append("[\(item.workItemCode)] \(item.workItemName)")
            lines.append("  Talep: \(item.currentQuantity.quantityFormatted) \(item.unit) — \(item.periodAmount.currencyFormatted) | Durum: \(durum)")
        }
        lines.append("")
        lines.append("Oluşturuldu: \(Date().shortFormatted)")
        return lines.joined(separator: "\n")
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ozzetSection
                kalemTablodSection
                if hasMultiplePeriods { gecmisKarsilastirmaSection }
                itirazOneriSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Hakediş Analizi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: shareText,
                    subject: Text("Hakediş Raporu – \(hakedis.periodName)"),
                    message: Text("Hakediş karşılaştırma raporu ektedir.")
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("İtiraz Başlat", isPresented: $showItirazAlert, presenting: selectedItirazStep) { step in
            Button("Başlat", role: .destructive) { }
            Button("İptal", role: .cancel) { }
        } message: { step in
            Text("'\(step.role.rawValue)' adımındaki red kararına itiraz akışı başlatılsın mı? Red gerekçesi: \(step.rejectionReason ?? "Belirtilmemiş")")
        }
    }

    // MARK: - Section 1: Özet

    private var ozzetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Özet")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    title: "Toplam Talep",
                    value: hakedis.grossAmount.currencyFormatted,
                    subtitle: "\(hakedis.items.count) kalem",
                    color: .hakedisOrange,
                    icon: "doc.text.fill"
                )
                StatCard(
                    title: "İdare Kararı",
                    value: idareSonucu,
                    subtitle: hakedis.approvalSteps.isEmpty ? "Henüz adım yok" : "\(hakedis.approvalSteps.count) adım",
                    color: outcome.color,
                    icon: outcome.icon
                )
                StatCard(
                    title: "Onay Durumu",
                    value: onayDurumu,
                    subtitle: outcome.label,
                    color: outcome.color,
                    icon: "person.badge.clock"
                )
                StatCard(
                    title: "Son Versiyon",
                    value: hakedis.lastRevisionVersion,
                    subtitle: hakedis.revisions.isEmpty ? "İlk sunum" : "\(hakedis.revisions.count) revizyon",
                    color: hakedis.revisions.isEmpty ? .secondary : .hakedisWarning,
                    icon: "clock.arrow.2.circlepath"
                )
            }
        }
    }

    // MARK: - Section 2: Kalem Tablosu

    private var kalemTablodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Kalem Tablosu")

            if hakedis.items.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "Kalem bulunamadı",
                    subtitle: "Bu hakedişte henüz iş kalemi eklenmemiş."
                )
            } else {
                VStack(spacing: 8) {
                    // Tablo başlığı
                    HStack(spacing: 0) {
                        Text("Poz").font(.caption2.bold()).foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        Text("Kalem").font(.caption2.bold()).foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Miktar").font(.caption2.bold()).foregroundColor(.secondary)
                            .frame(width: 70, alignment: .trailing)
                        Text("Tutar").font(.caption2.bold()).foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)
                        Text("Durum").font(.caption2.bold()).foregroundColor(.secondary)
                            .frame(width: 68, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    ForEach(hakedis.items.sorted(by: { $0.workItemCode < $1.workItemCode })) { item in
                        HakedisItemComparisonRow(item: item, outcome: outcome)
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Geçmiş Karşılaştırma

    private var gecmisKarsilastirmaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Geçmiş Karşılaştırma")
            Text("Son \(last5Hakedisler.count) dönem — Brüt Talep ve Net Hakediş")
                .font(.caption).foregroundColor(.secondary)

            PeriodComparisonChart(hakedisler: last5Hakedisler)
                .frame(height: 200)
                .padding(.vertical, 4)

            // Dönem özetleri
            VStack(spacing: 6) {
                ForEach(last5Hakedisler) { h in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(h.periodName)
                                .font(.caption.bold())
                                .foregroundColor(h.id == hakedis.id ? .hakedisOrange : .primary)
                            Text(h.periodEnd.shortFormatted)
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(h.grossAmount.currencyFormatted)
                                .font(.caption.bold()).foregroundColor(.hakedisOrange)
                            Text("Net: \(h.netAmount.currencyFormatted)")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        if h.id == hakedis.id {
                            Image(systemName: "arrow.left")
                                .font(.caption2).foregroundColor(.hakedisOrange)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(
                        h.id == hakedis.id
                            ? Color.hakedisOrange.opacity(0.08)
                            : Color.hakedisCard
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Section 4: İtiraz Önerisi

    private var itirazOneriSection: some View {
        let rejectedSteps = hakedis.rejectedSteps
        guard !rejectedSteps.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("İtiraz Önerisi")

                Text("Aşağıdaki adımlarda red kararı mevcuttur. Her biri için itiraz başlatabilirsiniz.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    ForEach(rejectedSteps.sorted(by: { $0.stepOrder < $1.stepOrder })) { step in
                        ItirazOneriRow(step: step) {
                            selectedItirazStep = step
                            showItirazAlert = true
                        }
                    }
                }

                // Toplam red özeti
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.hakedisDanger)
                        .font(.caption)
                    Text("\(rejectedSteps.count) adımda red kararı — hakediş tutarı etkilenmiş olabilir.")
                        .font(.caption)
                        .foregroundColor(.hakedisDanger)
                }
                .padding(10)
                .background(Color.hakedisDanger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        )
    }
}

// MARK: - HakedisItemComparisonRow

private struct HakedisItemComparisonRow: View {
    let item: HakedisItem
    let outcome: ApprovalOutcome

    private var rowColor: Color {
        switch outcome {
        case .tamOnay:    return .hakedisSuccess
        case .bekliyor:   return .hakedisWarning
        case .reddedildi: return .hakedisDanger
        }
    }

    private var statusLabel: String {
        switch outcome {
        case .tamOnay:    return "Onaylı"
        case .bekliyor:   return "Bekliyor"
        case .reddedildi: return "Red"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(item.workItemCode)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.workItemName)
                    .font(.caption.bold())
                    .lineLimit(2)
                Text("\(item.currentQuantity.quantityFormatted) \(item.unit)")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.currentQuantity.quantityFormatted)
                .font(.caption2).foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
                .lineLimit(1)

            Text(item.periodAmount.currencyFormatted)
                .font(.caption.bold())
                .foregroundColor(.hakedisOrange)
                .frame(width: 90, alignment: .trailing)
                .lineLimit(1)

            StatusBadge(text: statusLabel, color: rowColor)
                .frame(width: 68, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - PeriodComparisonChart

private struct PeriodComparisonChart: View {
    let hakedisler: [Hakedis]

    struct BarData: Identifiable {
        let id = UUID()
        let period: String
        let type: String
        let amount: Double
        let sortIndex: Int
    }

    private var chartData: [BarData] {
        hakedisler.enumerated().flatMap { idx, h -> [BarData] in
            let label = h.periodName.count > 8
                ? String(h.periodName.prefix(8)) + "…"
                : h.periodName
            return [
                BarData(period: label, type: "Talep",  amount: h.grossAmount, sortIndex: idx),
                BarData(period: label, type: "Net",    amount: h.netAmount,   sortIndex: idx)
            ]
        }
    }

    var body: some View {
        Chart(chartData) { bar in
            BarMark(
                x: .value("Dönem", bar.period),
                y: .value("Tutar", bar.amount / 1_000),
                width: .ratio(0.4)
            )
            .foregroundStyle(by: .value("Tür", bar.type))
            .cornerRadius(4)
        }
        .chartForegroundStyleScale([
            "Talep": Color.hakedisOrange,
            "Net":   Color.hakedisSuccess
        ])
        .chartYAxis {
            AxisMarks { val in
                AxisGridLine()
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text("\(Int(v))K ₺").font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { AxisValueLabel().font(.caption2) }
        }
        .chartLegend(position: .bottom, alignment: .leading) {
            HStack(spacing: 16) {
                legendDot(color: .hakedisOrange, label: "Brüt Talep")
                legendDot(color: .hakedisSuccess, label: "Net Hakediş")
            }
            .font(.caption2)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundColor(.secondary)
        }
    }
}

// MARK: - ItirazOneriRow

private struct ItirazOneriRow: View {
    let step: ApprovalStep
    let onItiraz: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: step.role.icon)
                    .font(.subheadline)
                    .foregroundColor(.hakedisDanger)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.role.rawValue)
                        .font(.subheadline.bold())
                    Text(step.effectiveApproverName)
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if let date = step.approvedAt {
                    Text(date.shortFormatted)
                        .font(.caption2).foregroundColor(.secondary)
                }
            }

            if let reason = step.rejectionReason, !reason.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.caption2).foregroundColor(.hakedisDanger)
                    Text("'\(reason)'")
                        .font(.caption)
                        .foregroundColor(.hakedisDanger.opacity(0.85))
                        .italic()
                }
                .padding(.horizontal, 8)
            }

            Button(action: onItiraz) {
                Label("İtiraz Başlat", systemImage: "hand.raised.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.hakedisDanger)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.hakedisDanger.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - HakedisComparisonButton

/// Toolbar veya herhangi bir NavigationStack içinde kullanılabilecek,
/// HakedisApprovalAnalysisView'e yönlendiren buton bileşeni.
struct HakedisComparisonButton: View {
    let hakedis: Hakedis

    var body: some View {
        NavigationLink {
            HakedisApprovalAnalysisView(hakedis: hakedis)
        } label: {
            Image(systemName: "arrow.left.arrow.right.square.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.hakedisOrange)
        }
    }
}

// MARK: - ComparisonReportCard

/// ReportsView içinde kullanılmak üzere küçük özet kartı.
struct ComparisonReportCard: View {
    let hakedis: Hakedis

    private var outcome: ApprovalOutcome { hakedis.approvalOutcome }

    private var approvalSummary: String {
        let a = hakedis.approvedStepCount
        let r = hakedis.rejectedStepCount
        let p = hakedis.pendingStepCount
        var parts: [String] = []
        if a > 0 { parts.append("\(a) onay") }
        if r > 0 { parts.append("\(r) red") }
        if p > 0 { parts.append("\(p) bekliyor") }
        return parts.isEmpty ? "Adım yok" : parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationLink {
            HakedisApprovalAnalysisView(hakedis: hakedis)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(hakedis.periodName)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        if let contractTitle = hakedis.contract?.title {
                            Text(contractTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    StatusBadge(text: outcome.label, color: outcome.color)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Brüt Talep").font(.caption2).foregroundColor(.secondary)
                        Text(hakedis.grossAmount.currencyFormatted)
                            .font(.caption.bold()).foregroundColor(.hakedisOrange)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 3) {
                        Text("Net Hakediş").font(.caption2).foregroundColor(.secondary)
                        Text(hakedis.netAmount.currencyFormatted)
                            .font(.caption.bold()).foregroundColor(.hakedisSuccess)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Onay").font(.caption2).foregroundColor(.secondary)
                        Text(approvalSummary)
                            .font(.caption.bold())
                            .foregroundColor(outcome.color)
                            .lineLimit(1)
                    }
                }

                if hakedis.revisions.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.caption2)
                        Text("\(hakedis.revisions.count) revizyon — son: \(hakedis.lastRevisionVersion)")
                            .font(.caption2)
                    }
                    .foregroundColor(.hakedisWarning)
                }
            }
            .padding(14)
            .background(Color.hakedisCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(outcome.color.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
