import SwiftUI

// MARK: - Hakediş İcmal Tablosu (Türk Formatı)

struct HakedisIcmalView: View {
    let hakedis: Hakedis

    private var contract: Contract? { hakedis.contract }
    private var project: Project? { contract?.project }

    // Önceki dönemler toplamı
    private var previousTotal: Double {
        guard let c = contract else { return 0 }
        let previous = c.hakedisler.filter { $0.id != hakedis.id && $0.periodEnd <= hakedis.periodStart }
        return previous.reduce(0) { $0 + $1.grossAmount }
    }

    // Bu hakediş kaçıncı
    private var hakedisNo: Int {
        guard let c = contract else { return 1 }
        let sorted = c.hakedisler.sorted { $0.createdAt < $1.createdAt }
        return (sorted.firstIndex(where: { $0.id == hakedis.id }) ?? 0) + 1
    }

    private var title: String {
        "\(hakedisNo). Hakediş — \(hakedis.periodName)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Başlık
                VStack(spacing: 4) {
                    Text("HAKEDİŞ İCMAL TABLOSU")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.hakedisOrange)

                Divider()

                // Proje Bilgileri
                IcmalInfoSection {
                    IcmalRow(label: "Proje", value: project?.name ?? "—")
                    IcmalRow(label: "Sözleşme", value: contract?.title ?? "—")
                    IcmalRow(label: "İşveren", value: contract?.employerName.isEmpty == false ? (contract?.employerName ?? "—") : "—")
                    IcmalRow(label: "Dönem", value: "\(hakedis.periodStart.shortFormatted) – \(hakedis.periodEnd.shortFormatted)")
                    if let due = hakedis.dueDate {
                        IcmalRow(label: "Vade Tarihi", value: due.shortFormatted,
                                 valueColor: hakedis.isOverdue ? .hakedisDanger : .primary)
                    }
                }

                Divider()

                // Finansal Özet
                IcmalInfoSection {
                    IcmalRow(label: "1. Brüt Hakediş Tutarı",
                             value: hakedis.effectiveGrossAmount.currencyFormatted,
                             isBold: true)

                    Text("2. Kesintiler:")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)

                    IcmalRow(label: "   a) Stopaj (%\(String(format: "%.1f", hakedis.withholdingTaxRate)))",
                             value: "−\(hakedis.withholdingTaxAmount.currencyFormatted)",
                             valueColor: hakedis.withholdingTaxAmount > 0 ? .hakedisDanger : .secondary)

                    IcmalRow(label: "   b) Damga Vergisi (%\(String(format: "%.3f", hakedis.stampTaxRate)))",
                             value: "−\(hakedis.stampTaxAmount.currencyFormatted)",
                             valueColor: hakedis.stampTaxAmount > 0 ? .hakedisDanger : .secondary)

                    IcmalRow(label: "   c) Teminat Kesintisi (%\(String(format: "%.0f", contract?.retentionRate ?? 0)))",
                             value: "−\(hakedis.retentionAmount.currencyFormatted)",
                             valueColor: hakedis.retentionAmount > 0 ? .hakedisDanger : .secondary)

                    IcmalRow(label: "   d) Avans Kesintisi (%\(String(format: "%.0f", contract?.advanceRate ?? 0)))",
                             value: "−\(hakedis.advanceDeduction.currencyFormatted)",
                             valueColor: hakedis.advanceDeduction > 0 ? .hakedisWarning : .secondary)

                    if hakedis.penaltyAmount > 0 {
                        IcmalRow(label: "   e) Gecikme Cezası (\(hakedis.penaltyDays) gün)",
                                 value: "−\(hakedis.penaltyAmount.currencyFormatted)",
                                 valueColor: .hakedisDanger)
                    }

                    Divider().padding(.vertical, 4)

                    IcmalRow(label: "3. Net Hakediş Tutarı",
                             value: hakedis.netAmount.currencyFormatted,
                             isBold: true, valueColor: .hakedisOrange)

                    if hakedis.kdvAmount > 0 {
                        IcmalRow(label: "4. KDV (%\(String(format: "%.0f", contract?.kdvRate ?? 0)))",
                                 value: "+\(hakedis.kdvAmount.currencyFormatted)",
                                 valueColor: .hakedisSuccess)
                    }

                    Divider().padding(.vertical, 4)

                    IcmalRow(label: "5. Ödenecek Tutar",
                             value: hakedis.netAmountAfterPenalty.currencyFormatted,
                             isBold: true, valueColor: .hakedisOrange)

                    if hakedis.isOverdue {
                        IcmalRow(label: "   + Gecikme Faizi (\(hakedis.daysOverdue) gün)",
                                 value: hakedis.overdueInterest.currencyFormatted,
                                 valueColor: .hakedisDanger)
                    }
                }

                Divider()

                // Kümülatif Bölüm
                IcmalInfoSection(header: "Kümülatif") {
                    IcmalRow(label: "Önceki dönemler toplamı", value: previousTotal.currencyFormatted)
                    IcmalRow(label: "Bu dönem", value: hakedis.grossAmount.currencyFormatted, valueColor: .hakedisOrange)
                    IcmalRow(label: "Genel Toplam",
                             value: (previousTotal + hakedis.grossAmount).currencyFormatted,
                             isBold: true)
                    if let contractTotal = contract?.totalContractAmount, contractTotal > 0 {
                        let progress = min(((previousTotal + hakedis.grossAmount) / contractTotal) * 100, 100)
                        IcmalRow(label: "Sözleşme İlerleme",
                                 value: progress.percentFormatted,
                                 valueColor: progress >= 100 ? .hakedisSuccess : .hakedisOrange)
                    }
                }

                Divider()

                // Ödeme durumu
                IcmalInfoSection(header: "Ödeme Durumu") {
                    IcmalRow(label: "Ödenen Tutar", value: hakedis.totalPaid.currencyFormatted, valueColor: .hakedisSuccess)
                    IcmalRow(label: "Kalan Tutar",
                             value: hakedis.remainingAmount.currencyFormatted,
                             valueColor: hakedis.remainingAmount > 0 ? .hakedisDanger : .hakedisSuccess)
                }

                Spacer(minLength: 32)
            }
        }
        .background(Color.hakedisBackground)
        .navigationTitle("İcmal Tablosu")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - İcmal Yardımcı Bileşenler

private struct IcmalInfoSection<Content: View>: View {
    var header: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let h = header {
                Text(h)
                    .font(.caption.bold().uppercaseSmallCaps())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }
            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, header == nil ? 12 : 4)
        }
        .background(Color.hakedisCard)
        .padding(.vertical, 1)
    }
}

private struct IcmalRow: View {
    let label: String
    let value: String
    var isBold: Bool = false
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(isBold ? .subheadline.bold() : .subheadline)
                .foregroundColor(isBold ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(value)
                .font(isBold ? .subheadline.bold() : .subheadline)
                .foregroundColor(valueColor)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
    }
}
