import SwiftUI
import SwiftData
import Charts

// NakitSenaryosu ve AylikProje → CashFlowEngine.swift içinde tanımlı

// MARK: - NakitSenaryosu UI Uzantısı (SwiftUI renkleri)

extension NakitSenaryosu {
    var color: Color {
        switch self {
        case .optimist:  return .hakedisSuccess
        case .gercekci:  return .hakedisOrange
        case .kotumser:  return .hakedisDanger
        }
    }
}

// MARK: - CashFlowView

struct CashFlowView: View {
    let hakedisler: [Hakedis]

    @State private var senaryo: NakitSenaryosu = .gercekci

    // MARK: Hesaplamalar (CashFlowEngine'e devredildi)

    private var ortalamGecikmeGun: Double {
        let raw = CashFlowEngine.ortalamGecikmeGun(hakedisler: hakedisler)
        return raw > 0 ? raw : 30   // veri yoksa UI'da 30 gün varsayılan göster
    }

    private var aktifProjeksiyonlar: [AylikProje] {
        CashFlowEngine.projeksiyonlar(hakedisler: hakedisler, senaryo: senaryo)
    }

    private var toplamBeklenenTahsilat: Double {
        CashFlowEngine.toplamBeklenenTahsilat(projeksiyonlar: aktifProjeksiyonlar)
    }

    private var kritikAyVarMi: Bool {
        CashFlowEngine.kritikAyVarMi(projeksiyonlar: aktifProjeksiyonlar)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Senaryo Seçici
                    senaryoPicker

                    // Grafik
                    nakitGrafigi

                    // Aylık Kartlar
                    aylikKartlar

                    // Özet Satırı
                    ozetSatiri

                    // Kritik uyarı (varsa)
                    if kritikAyVarMi { kritikUyari }

                    // Metodoloji notu
                    metodoloji
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Nakit Akışı")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Senaryo Picker

    private var senaryoPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Senaryo Analizi")

            Picker("Senaryo", selection: $senaryo) {
                ForEach(NakitSenaryosu.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Image(systemName: senaryo.icon)
                    .foregroundColor(senaryo.color)
                    .font(.caption)
                Text(senaryo.aciklama)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if ortalamGecikmeGun > 0 {
                    Text("Geçmiş ort: \(Int(ortalamGecikmeGun)) gün gecikme")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private struct BarEntry: Identifiable {
        let id = UUID()
        let ay: String
        let tur: String
        let deger: Double
    }

    private struct LineEntry: Identifiable {
        let id = UUID()
        let ay: String
        let kumulatif: Double
    }

    private func barData(for projeler: [AylikProje]) -> [BarEntry] {
        projeler.flatMap {
            [BarEntry(ay: $0.ay, tur: "Hakediş",  deger: $0.beklenenHakedis / 1_000),
             BarEntry(ay: $0.ay, tur: "Tahsilat", deger: $0.beklenenTahsilat / 1_000)]
        }
    }

    private func lineData(for projeler: [AylikProje]) -> [LineEntry] {
        projeler.map { LineEntry(ay: $0.ay, kumulatif: $0.kumulatifNakit / 1_000) }
    }

    // MARK: - Nakit Grafiği

    private var nakitGrafigi: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("3 Aylık Projeksiyon")

            let projeler = aktifProjeksiyonlar
            let bars = barData(for: projeler)
            let lines = lineData(for: projeler)

            Chart {
                ForEach(bars) { entry in
                    BarMark(
                        x: .value("Ay", entry.ay),
                        y: .value("Tutar (K ₺)", entry.deger),
                        width: .ratio(0.38)
                    )
                    .foregroundStyle(by: .value("Tür", entry.tur))
                    .cornerRadius(5)
                }

                ForEach(lines) { entry in
                    LineMark(
                        x: .value("Ay", entry.ay),
                        y: .value("Kümülatif (K ₺)", entry.kumulatif)
                    )
                    .foregroundStyle(Color.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .symbol(Circle().strokeBorder(lineWidth: 2))
                    .symbolSize(36)

                    AreaMark(
                        x: .value("Ay", entry.ay),
                        y: .value("Kümülatif (K ₺)", entry.kumulatif)
                    )
                    .foregroundStyle(Color.purple.opacity(0.07))
                }

                // Sıfır çizgisi (kümülatif için referans)
                RuleMark(y: .value("Sıfır", 0))
                    .foregroundStyle(Color.hakedisDanger.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartForegroundStyleScale([
                "Hakediş":  Color.blue,
                "Tahsilat": Color.hakedisSuccess
            ])
            .chartYAxis {
                AxisMarks { val in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = val.as(Double.self) {
                            Text("\(v < 0 ? "-" : "")\(Int(abs(v)))K ₺")
                                .font(.caption2)
                                .foregroundColor(v < 0 ? .hakedisDanger : .primary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { AxisValueLabel().font(.caption) }
            }
            .chartLegend(position: .bottom, alignment: .leading) {
                HStack(spacing: 16) {
                    legendDot(color: .blue,           label: "Beklenen Hakediş")
                    legendDot(color: .hakedisSuccess, label: "Beklenen Tahsilat")
                    legendLine(color: .purple,         label: "Kümülatif Nakit")
                }
                .font(.caption2)
                .padding(.top, 4)
            }
            .frame(height: 220)
            .padding(.vertical, 4)
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundColor(.secondary)
        }
    }

    private func legendLine(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Rectangle().fill(color).frame(width: 14, height: 2)
            Text(label).foregroundColor(.secondary)
        }
    }

    // MARK: - Aylık Kartlar

    private var aylikKartlar: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Aylık Detay")

            ForEach(aktifProjeksiyonlar) { proje in
                CashFlowMonthCard(
                    month: proje.ay,
                    hakedis: proje.beklenenHakedis,
                    tahsilat: proje.beklenenTahsilat,
                    cumulative: proje.kumulatifNakit,
                    isCritical: proje.kumulatifNakit < 0
                )
            }
        }
    }

    // MARK: - Özet Satırı

    private var ozetSatiri: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Özet")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Ort. Ödeme Gecikmesi", systemImage: "clock.fill")
                        .font(.caption).foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(ortalamGecikmeGun))")
                            .font(.title2.bold())
                            .foregroundColor(ortalamGecikmeGun > 45 ? .hakedisDanger : .hakedisOrange)
                        Text("gün")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Label("3 Aylık Tahsilat (\(senaryo.rawValue))", systemImage: "banknote.fill")
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(toplamBeklenenTahsilat.currencyFormatted)
                        .font(.title3.bold())
                        .foregroundColor(.hakedisSuccess)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Kritik Uyarı

    private var kritikUyari: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.hakedisDanger)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Nakit Açığı Riski")
                    .font(.subheadline.bold())
                    .foregroundColor(.hakedisDanger)
                Text("'\(senaryo.rawValue)' senaryosunda bir veya birden fazla ayda kümülatif nakit pozisyonu negatife düşüyor. Tahsilat hızlandırılmalı veya harcamalar revize edilmelidir.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color.hakedisDanger.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.hakedisDanger.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Metodoloji Notu

    private var metodoloji: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Hesaplama Yöntemi", systemImage: "info.circle")
                .font(.caption.bold()).foregroundColor(.secondary)
            Text("• Beklenen hakediş: son 3 ayın aylık ortalaması\n• Optimist: gecikme yok, Gerçekçi: geçmiş ort. gecikme, Kötümser: 2× gecikme\n• Kümülatif nakit = Σ(tahsilat – hakediş)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }
}

// MARK: - CashFlowMonthCard

struct CashFlowMonthCard: View {
    let month: String
    let hakedis: Double
    let tahsilat: Double
    let cumulative: Double
    let isCritical: Bool

    private var fark: Double { tahsilat - hakedis }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Başlık satırı
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: isCritical ? "exclamationmark.triangle.fill" : "calendar")
                        .font(.subheadline)
                        .foregroundColor(isCritical ? .hakedisDanger : .hakedisOrange)
                    Text(month)
                        .font(.subheadline.bold())
                }
                Spacer()
                if isCritical {
                    StatusBadge(text: "Kritik Ay", color: .hakedisDanger)
                } else if tahsilat >= hakedis {
                    StatusBadge(text: "Pozitif", color: .hakedisSuccess)
                } else {
                    StatusBadge(text: "Açık", color: .hakedisWarning)
                }
            }

            Divider()

            // Değer satırları
            HStack(spacing: 0) {
                cashFlowStat(
                    label: "Beklenen Hakediş",
                    value: hakedis.currencyFormatted,
                    color: .blue,
                    icon: "doc.text"
                )
                Divider().frame(height: 36)
                cashFlowStat(
                    label: "Beklenen Tahsilat",
                    value: tahsilat.currencyFormatted,
                    color: .hakedisSuccess,
                    icon: "banknote"
                )
                Divider().frame(height: 36)
                cashFlowStat(
                    label: "Kümülatif Nakit",
                    value: (cumulative >= 0 ? "+" : "") + cumulative.currencyFormatted,
                    color: isCritical ? .hakedisDanger : cumulative >= 0 ? .hakedisSuccess : .hakedisDanger,
                    icon: isCritical ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                )
            }

            // Fark göstergesi
            HStack(spacing: 4) {
                Image(systemName: fark >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text("Dönem farkı: \(fark >= 0 ? "+" : "")\(fark.currencyFormatted)")
                    .font(.caption2)
            }
            .foregroundColor(fark >= 0 ? .hakedisSuccess : .hakedisDanger)
        }
        .padding(14)
        .background(Color.hakedisCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCritical ? Color.hakedisDanger.opacity(0.35) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    private func cashFlowStat(label: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.caption2).foregroundColor(color.opacity(0.7))
            Text(value)
                .font(.caption.bold())
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
