import SwiftUI
import SwiftData

// MARK: - Helpers

extension WorkItem {
    /// Onaylı/ödendi hakedişlerden gelen kümülatif gerçekleşen miktar
    func approvedCumulative(in contract: Contract) -> Double {
        contract.hakedisler
            .filter { $0.status == .approved || $0.status == .paid }
            .flatMap { $0.items }
            .filter { $0.workItemCode == self.code }
            .reduce(0) { $0 + $1.currentQuantity }
    }

    func cumulativeColor(in contract: Contract) -> Color {
        let pct = contract.totalContractAmount > 0
            ? approvedCumulative(in: contract) / contractedQuantity * 100 : 0
        if pct > 100 { return .hakedisDanger }
        if pct >= 90  { return .hakedisWarning }
        if pct >= 75  { return .hakedisOrange }
        if pct > 0    { return .hakedisSuccess }
        return .secondary
    }
}

// MARK: - Cumulative Work Item Row (toggle açıkken kullanılır)

struct CumulativeWorkItemRow: View {
    let workItem: WorkItem
    let contract: Contract

    private var cumulative: Double   { workItem.approvedCumulative(in: contract) }
    private var contracted: Double   { workItem.contractedQuantity }
    private var remaining: Double    { contracted - cumulative }
    private var pct: Double          { contracted > 0 ? cumulative / contracted * 100 : 0 }
    private var isOver: Bool         { cumulative > contracted }
    private var isNear: Bool         { !isOver && pct >= 90 }
    private var rowColor: Color      { workItem.cumulativeColor(in: contract) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Başlık
            HStack(spacing: 6) {
                if isOver {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.hakedisDanger).font(.caption)
                } else if isNear {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.hakedisWarning).font(.caption)
                }
                Text("[\(workItem.code)]")
                    .font(.caption.monospaced()).foregroundColor(.secondary)
                Text(workItem.name)
                    .font(.subheadline.bold()).lineLimit(1)
                Spacer()
                Text(pct.percentFormatted)
                    .font(.caption.bold()).foregroundColor(rowColor)
            }

            // Kümülatif progress bar
            ProgressBarView(progress: pct, color: rowColor)

            // Sayısal tablo
            HStack(spacing: 0) {
                CumulativeCell(label: "Sözleşme",   value: contracted, unit: workItem.unit)
                Divider().frame(height: 30)
                CumulativeCell(label: "Kümülatif",  value: cumulative, unit: workItem.unit,
                               color: rowColor)
                Divider().frame(height: 30)
                CumulativeCell(label: "Kalan",
                               value: abs(remaining),
                               unit: workItem.unit,
                               color: isOver ? .hakedisDanger : .secondary,
                               prefix: isOver ? "+" : "")
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CumulativeCell: View {
    let label: String
    let value: Double
    let unit: String
    var color: Color = .primary
    var prefix: String = ""

    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text("\(prefix)\(value.quantityFormatted)")
                .font(.caption.bold()).foregroundColor(color)
            Text(unit).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cumulative CSV Export

struct CumulativeCSVExporter {
    static func export(_ contract: Contract) -> String {
        var lines = ["Poz Kodu,Poz Adı,Birim,Sözleşme Miktarı,Kümülatif Gerçekleşen,Kalan,Tamamlanma %"]
        for wi in contract.workItems.sorted(by: { $0.code < $1.code }) {
            let cum = wi.approvedCumulative(in: contract)
            let rem = wi.contractedQuantity - cum
            let pct = wi.contractedQuantity > 0 ? cum / wi.contractedQuantity * 100 : 0
            lines.append([
                wi.code, wi.name, wi.unit,
                wi.contractedQuantity.quantityFormatted,
                cum.quantityFormatted,
                rem.quantityFormatted,
                pct.percentFormatted
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Cumulative Toggle Header

struct CumulativeToggleHeader: View {
    @Binding var showCumulative: Bool
    let contract: Contract
    @State private var exportItem: ShareableCSV?

    var body: some View {
        HStack {
            Text("İş Kalemleri (Pozlar)")
            Spacer()
            if showCumulative {
                Button {
                    exportItem = ShareableCSV(
                        content: CumulativeCSVExporter.export(contract),
                        filename: "\(contract.title)_kumülatif.csv"
                    )
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                }
                .shareSheet(item: $exportItem)
            }
            Toggle("", isOn: $showCumulative)
                .toggleStyle(CumulativeToggleStyle())
        }
    }
}

struct CumulativeToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: configuration.isOn ? "chart.bar.fill" : "chart.bar")
                    .foregroundColor(configuration.isOn ? .hakedisOrange : .secondary)
                Text("Kümülatif")
                    .font(.caption)
                    .foregroundColor(configuration.isOn ? .hakedisOrange : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hakedis Cumulative Row (HakedisDetailView içinde)

struct HakedisItemCumulativeRow: View {
    let item: HakedisItem
    let contract: Contract?

    private var contracted: Double? {
        contract?.workItems.first { $0.code == item.workItemCode }?.contractedQuantity
    }

    private var cumPct: Double? {
        guard let c = contracted, c > 0 else { return nil }
        return item.cumulativeQuantity / c * 100
    }

    private var attachmentCount: Int {
        contract?.workItems.first { $0.code == item.workItemCode }?.attachments.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mevcut satır bilgisi
            HStack {
                Text("[\(item.workItemCode)]")
                    .font(.caption.monospaced()).foregroundColor(.secondary)
                Text(item.workItemName)
                    .font(.subheadline.bold()).lineLimit(1)
                Spacer()
                if attachmentCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "book.pages")
                            .font(.caption2)
                        Text("\(attachmentCount)")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.hakedisSuccess.opacity(0.15))
                    .foregroundColor(.hakedisSuccess)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(attachmentCount) ataşman")
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Önceki").font(.caption2).foregroundColor(.secondary)
                    Text("\(item.previousQuantity.quantityFormatted) \(item.unit)").font(.caption)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bu Dönem").font(.caption2).foregroundColor(.hakedisOrange)
                    Text("\(item.currentQuantity.quantityFormatted) \(item.unit)")
                        .font(.caption.bold()).foregroundColor(.hakedisOrange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kümülatif").font(.caption2).foregroundColor(.secondary)
                    Text("\(item.cumulativeQuantity.quantityFormatted) \(item.unit)").font(.caption)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Tutar").font(.caption2).foregroundColor(.secondary)
                    Text(item.periodAmount.currencyFormatted)
                        .font(.caption.bold())
                }
            }

            // Sözleşme kümülatif progress (varsa)
            if let pct = cumPct, let c = contracted {
                let color: Color = pct > 100 ? .hakedisDanger : pct >= 90 ? .hakedisWarning : .hakedisOrange
                VStack(alignment: .trailing, spacing: 2) {
                    ProgressBarView(progress: pct, color: color)
                    HStack {
                        Text("Kümülatif / Sözleşme")
                            .font(.caption2).foregroundColor(.secondary)
                        Spacer()
                        Text("\(item.cumulativeQuantity.quantityFormatted) / \(c.quantityFormatted) \(item.unit)  (\(pct.percentFormatted))")
                            .font(.caption2).foregroundColor(color)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
