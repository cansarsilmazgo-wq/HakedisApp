import SwiftUI
import SwiftData
import Charts

// MARK: - CashFlowProjectionView
// Gelir/gider kaynaklı 3/6/12 aylık projeksiyon tablosu ve grafik

struct CashFlowProjectionView: View {
    @Query private var hakedisler: [Hakedis]
    @Query private var priceDiffCalcs: [PriceDifferenceCalc]
    @Query private var stockEntries: [StockEntry]
    @Query private var attendanceRecords: [Attendance]
    @Query private var equipmentLogs: [EquipmentLog]
    @Query private var subHakedisler: [SubcontractorHakedis]
    @Query private var projects: [Project]

    @State private var ayCount: Int = 3        // 3 / 6 / 12
    @State private var selectedProjectID: UUID? = nil

    private var filteredHakedisler: [Hakedis] {
        guard let pid = selectedProjectID else { return hakedisler }
        return hakedisler.filter { $0.contract?.project?.id == pid }
    }

    private var projeksiyonlar: [AylikDetayliProje] {
        GenisletilmisCashFlowEngine.projeksiyon(
            hakedisler: filteredHakedisler,
            priceDiffCalcs: priceDiffCalcs,
            stockEntries: stockEntries,
            attendanceRecords: attendanceRecords,
            equipmentLogs: equipmentLogs,
            subHakedisler: subHakedisler,
            ayCount: ayCount
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Filtreler
                VStack(spacing: 8) {
                    Picker("Süre", selection: $ayCount) {
                        Text("3 Ay").tag(3)
                        Text("6 Ay").tag(6)
                        Text("12 Ay").tag(12)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.card)
                    .accessibilityLabel("Projeksiyon süresi")

                    if !projects.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "Tüm Projeler", isSelected: selectedProjectID == nil) {
                                    selectedProjectID = nil
                                }
                                ForEach(projects, id: \.id) { p in
                                    FilterChip(title: p.name, isSelected: selectedProjectID == p.id) {
                                        selectedProjectID = selectedProjectID == p.id ? nil : p.id
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.card)
                        }
                    }
                }
                .padding(.top, Spacing.card)

                // Grafik
                if !projeksiyonlar.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Gelir / Gider Grafiği")
                        Chart {
                            ForEach(projeksiyonlar) { p in
                                BarMark(
                                    x: .value("Ay", p.ay),
                                    y: .value("Gelir", p.toplamGelir)
                                )
                                .foregroundStyle(Color.hakedisSuccess.opacity(0.8))
                                .position(by: .value("Tür", "Gelir"))

                                BarMark(
                                    x: .value("Ay", p.ay),
                                    y: .value("Gider", p.toplamGider)
                                )
                                .foregroundStyle(Color.hakedisDanger.opacity(0.8))
                                .position(by: .value("Tür", "Gider"))

                                LineMark(
                                    x: .value("Ay", p.ay),
                                    y: .value("Kümülatif", p.kumulatif)
                                )
                                .foregroundStyle(Color.hakedisOrange)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .symbol(.circle)
                                .symbolSize(30)
                            }
                        }
                        .frame(height: 220)
                        .padding(.horizontal, Spacing.card)

                        HStack(spacing: 16) {
                            legendDot(Color.hakedisSuccess, label: "Planlanan Gelir")
                            legendDot(Color.hakedisDanger, label: "Planlanan Gider")
                            legendLine(Color.hakedisOrange, label: "Kümülatif")
                        }
                        .padding(.horizontal, Spacing.card)
                    }
                }

                // Aylık Tablo
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Aylık Tablo")

                    // Başlık
                    HStack {
                        Text("Ay").frame(width: 80, alignment: .leading).font(.caption.bold())
                        Text("Gelir").frame(maxWidth: .infinity, alignment: .trailing).font(.caption.bold())
                        Text("Gider").frame(maxWidth: .infinity, alignment: .trailing).font(.caption.bold())
                        Text("Fark").frame(maxWidth: .infinity, alignment: .trailing).font(.caption.bold())
                        Text("Kümülatif").frame(maxWidth: .infinity, alignment: .trailing).font(.caption.bold())
                    }
                    .padding(.horizontal, Spacing.card)
                    .padding(.vertical, 6)
                    .background(Color.hakedisOrange.opacity(0.1))

                    ForEach(projeksiyonlar) { p in
                        ProjectionTableRow(proje: p)
                    }
                }

                // Gider Detayı
                if !projeksiyonlar.isEmpty {
                    let totMalzeme = projeksiyonlar.reduce(0) { $0 + $1.malzemeGideri }
                    let totIscilk  = projeksiyonlar.reduce(0) { $0 + $1.iscilikGideri }
                    let totEkip    = projeksiyonlar.reduce(0) { $0 + $1.ekipmanGideri }
                    let totTaseron = projeksiyonlar.reduce(0) { $0 + $1.taseronGideri }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader("Gider Kaynakları")
                        VStack(spacing: 4) {
                            giderRow("Malzeme Alımları", value: totMalzeme, icon: "shippingbox", color: .hakedisWarning)
                            giderRow("İşçilik", value: totIscilk, icon: "person.2", color: .hakedisInfo)
                            giderRow("Ekipman", value: totEkip, icon: "wrench.adjustable", color: .hakedisOrange)
                            giderRow("Taşeron Ödemeleri", value: totTaseron, icon: "building.2", color: .hakedisDanger)
                        }
                        .padding(.horizontal, Spacing.card)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Nakit Akış Projeksiyonu")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func legendDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func legendLine(_ color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 14, height: 2)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func giderRow(_ label: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(color).frame(width: 20)
            Text(label).font(.caption)
            Spacer()
            Text(value.currencyFormatted).font(.caption.bold()).foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ProjectionTableRow

private struct ProjectionTableRow: View {
    let proje: AylikDetayliProje

    var body: some View {
        HStack {
            Text(proje.ay).frame(width: 80, alignment: .leading).font(.caption)
            Text(proje.toplamGelir.shortFormatted).frame(maxWidth: .infinity, alignment: .trailing)
                .font(.caption).foregroundColor(.hakedisSuccess)
            Text(proje.toplamGider.shortFormatted).frame(maxWidth: .infinity, alignment: .trailing)
                .font(.caption).foregroundColor(.hakedisDanger)
            Text((proje.fark >= 0 ? "+" : "") + proje.fark.shortFormatted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .font(.caption.bold())
                .foregroundColor(proje.fark >= 0 ? .hakedisSuccess : .hakedisDanger)
            Text(proje.kumulatif.shortFormatted).frame(maxWidth: .infinity, alignment: .trailing)
                .font(.caption.bold())
                .foregroundColor(proje.kumulatif >= 0 ? .primary : .hakedisDanger)
        }
        .padding(.horizontal, Spacing.card)
        .padding(.vertical, 6)
        .background(proje.kumulatif < 0 ? Color.hakedisDanger.opacity(0.05) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(proje.ay), gelir \(proje.toplamGelir.shortFormatted), gider \(proje.toplamGider.shortFormatted)")
    }
}
