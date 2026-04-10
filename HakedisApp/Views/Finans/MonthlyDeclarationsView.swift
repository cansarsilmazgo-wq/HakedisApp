import SwiftUI
import SwiftData

// MARK: - SGK Hesaplama Sabitleri

private enum SGKRates {
    static let workerShare   = 0.14   // İşçi SGK payı %14
    static let employerShare = 0.205  // İşveren SGK payı %20.5
    static let workerUnemp   = 0.01   // İşsizlik işçi %1
    static let employerUnemp = 0.02   // İşsizlik işveren %2
    static let totalWorker   = workerShare + workerUnemp     // %15
    static let totalEmployer = employerShare + employerUnemp // %22.5
}

// MARK: - MonthlyDeclarationsView

struct MonthlyDeclarationsView: View {
    @Query private var workers: [Worker]
    @Query private var attendances: [Attendance]
    @Query private var hakedisler: [Hakedis]
    @AppStorage("indirilecekKDVManuel") private var indirilecekKDVManuelBase: Double = 0

    @State private var selectedMonth: Date = {
        let cal = Calendar.current
        return cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    @State private var showSGK = false
    @State private var showMuhtasar = false
    @State private var showKDV = false
    @AppStorage("minimumDailyWage") private var minimumDailyWage: Double = 934.0  // 2026 asgari ücret günlük

    private var monthlyAttendances: [Attendance] {
        let cal = Calendar.current
        return attendances.filter { cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var monthlyHakedisler: [Hakedis] {
        let cal = Calendar.current
        return hakedisler.filter {
            cal.isDate($0.periodStart, equalTo: selectedMonth, toGranularity: .month) ||
            cal.isDate($0.periodEnd, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    // SGK hesaplama
    struct WorkerSGK {
        let worker: Worker
        let presentDays: Int
        let earnings: Double
        let workerSGK: Double
        let employerSGK: Double
        let workerUnemp: Double
        let employerUnemp: Double
        let isBelowMinWage: Bool
    }

    private var workerSGKList: [WorkerSGK] {
        workers.filter { $0.isActive }.map { worker in
            let workerAtt = monthlyAttendances.filter { $0.worker?.id == worker.id && $0.isPresent }
            let days = workerAtt.count
            let earnings = max(Double(days) * worker.dailyCost, Double(days) * minimumDailyWage)
            let isBelowMinWage = worker.dailyCost < minimumDailyWage && days > 0
            return WorkerSGK(
                worker: worker,
                presentDays: days,
                earnings: earnings,
                workerSGK: earnings * SGKRates.workerShare,
                employerSGK: earnings * SGKRates.employerShare,
                workerUnemp: earnings * SGKRates.workerUnemp,
                employerUnemp: earnings * SGKRates.employerUnemp,
                isBelowMinWage: isBelowMinWage
            )
        }.filter { $0.presentDays > 0 }
    }

    // Muhtasar hesaplama
    private var totalStopaj: Double {
        monthlyHakedisler.reduce(0) { $0 + $1.withholdingTaxAmount }
    }
    private var totalDamgaVergisi: Double {
        monthlyHakedisler.reduce(0) { $0 + $1.stampTaxAmount }
    }

    // KDV hesaplama
    private var hesaplananKDV: Double {
        monthlyHakedisler.reduce(0) { $0 + ($1.grossAmount * ($1.contract?.kdvRate ?? 18) / 100) }
    }
    private var indirilecekKDV: Double {
        // Manuel girilen KDV değeri (malzeme alımlarından)
        indirilecekKDVManuelBase
    }
    private var odenecekKDV: Double { max(0, hesaplananKDV - indirilecekKDV) }

    var body: some View {
        NavigationStack {
            List {
                // Ay seçimi
                Section("Dönem") {
                    DatePicker("Ay", selection: $selectedMonth, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }

                // SGK Bildirge
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.hakedisOrange)
                            Text("SGK Bildirge Hazırla")
                                .font(.headline)
                        }
                        Text("\(workerSGKList.count) işçi — \(workerSGKList.filter { $0.isBelowMinWage }.count) asgari ücret altı uyarısı")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Button("Görüntüle") { showSGK = true }
                                .foregroundColor(.hakedisOrange)
                                .accessibilityLabel("SGK Bildirge Görüntüle")
                            Spacer()
                            shareButton(for: sgkSummaryText())
                        }
                    }
                }

                // Muhtasar
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.hakedisInfo)
                            Text("Muhtasar Hazırla")
                                .font(.headline)
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Stopaj: \(totalStopaj.currencyFormatted)")
                                    .font(.caption)
                                Text("Damga V.: \(totalDamgaVergisi.currencyFormatted)")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        HStack {
                            Button("Görüntüle") { showMuhtasar = true }
                                .foregroundColor(.hakedisOrange)
                                .accessibilityLabel("Muhtasar Görüntüle")
                            Spacer()
                            shareButton(for: muhtasarSummaryText())
                        }
                    }
                }

                // KDV
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack {
                            Image(systemName: "percent")
                                .foregroundColor(.hakedisSuccess)
                            Text("KDV Özet Hazırla")
                                .font(.headline)
                        }
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Hesaplanan KDV: \(hesaplananKDV.currencyFormatted)")
                                    .font(.caption)
                                Text("İndirilecek KDV: \(indirilecekKDV.currencyFormatted)")
                                    .font(.caption)
                                Text("Ödenecek KDV: \(odenecekKDV.currencyFormatted)")
                                    .font(.caption.bold())
                                    .foregroundColor(odenecekKDV > 0 ? .hakedisDanger : .hakedisSuccess)
                            }
                            Spacer()
                        }
                        HStack {
                            Button("Görüntüle") { showKDV = true }
                                .foregroundColor(.hakedisOrange)
                                .accessibilityLabel("KDV Özet Görüntüle")
                            Spacer()
                            shareButton(for: kdvSummaryText())
                        }
                    }
                }

                // KDV giriş
                Section("İndirilecek KDV") {
                    HStack {
                        Text("Malzeme Alım KDV'si (₺)")
                        Spacer()
                        TextField("₺", value: $indirilecekKDVManuelBase, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    Text("Malzeme ve hizmet alımlarında ödediğiniz toplam KDV tutarını girin.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Asgari ücret ayarı
                Section("Asgari Ücret") {
                    HStack {
                        Text("Günlük Asgari Ücret")
                        Spacer()
                        TextField("₺", value: $minimumDailyWage, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Beyannameler")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSGK) {
                SGKBildirgeView(workerSGKList: workerSGKList, month: selectedMonth)
            }
            .sheet(isPresented: $showMuhtasar) {
                MuhtasarView(stopaj: totalStopaj, damga: totalDamgaVergisi, month: selectedMonth)
            }
            .sheet(isPresented: $showKDV) {
                KDVView(hesaplanan: hesaplananKDV, indirilecek: indirilecekKDV, month: selectedMonth)
            }
        }
    }

    private func shareButton(for text: String) -> some View {
        Button {
            let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(av, animated: true)
            }
        } label: {
            Label("Muhasebeciye Gönder", systemImage: "square.and.arrow.up")
                .font(.caption)
        }
        .foregroundColor(.hakedisOrange)
        .accessibilityLabel("Muhasebeciye Gönder")
    }

    private func sgkSummaryText() -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"; df.locale = Locale(identifier: "tr_TR")
        var text = "SGK BİLDİRGE ÖZETİ — \(df.string(from: selectedMonth))\n\n"
        let totalEarnings = workerSGKList.reduce(0) { $0 + $1.earnings }
        let totalWorkerSGK = workerSGKList.reduce(0) { $0 + $1.workerSGK }
        let totalEmpSGK = workerSGKList.reduce(0) { $0 + $1.employerSGK }
        text += "İşçi Sayısı: \(workerSGKList.count)\n"
        text += "Toplam Kazanç Matrahı: \(totalEarnings.currencyFormatted)\n"
        text += "İşçi SGK (%14): \(totalWorkerSGK.currencyFormatted)\n"
        text += "İşveren SGK (%20.5): \(totalEmpSGK.currencyFormatted)\n"
        text += "Toplam SGK: \((totalWorkerSGK + totalEmpSGK).currencyFormatted)\n"
        return text
    }

    private func muhtasarSummaryText() -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"; df.locale = Locale(identifier: "tr_TR")
        var text = "MUHTASAR BEYANNAME ÖZETİ — \(df.string(from: selectedMonth))\n\n"
        text += "Hakediş Stopaj Toplamı: \(totalStopaj.currencyFormatted)\n"
        text += "Damga Vergisi: \(totalDamgaVergisi.currencyFormatted)\n"
        text += "TOPLAM: \((totalStopaj + totalDamgaVergisi).currencyFormatted)\n"
        return text
    }

    private func kdvSummaryText() -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM yyyy"; df.locale = Locale(identifier: "tr_TR")
        var text = "KDV BEYANNAMESİ ÖZETİ — \(df.string(from: selectedMonth))\n\n"
        text += "Hesaplanan KDV: \(hesaplananKDV.currencyFormatted)\n"
        text += "İndirilecek KDV: \(indirilecekKDV.currencyFormatted)\n"
        text += "Ödenecek KDV: \(odenecekKDV.currencyFormatted)\n"
        return text
    }
}

// MARK: - SGKBildirgeView

struct SGKBildirgeView: View {
    typealias WorkerSGK = MonthlyDeclarationsView.WorkerSGK
    let workerSGKList: [WorkerSGK]
    let month: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if workerSGKList.isEmpty {
                    EmptyStateView(
                        icon: "person.slash",
                        title: "İşçi Yok",
                        subtitle: "Bu ay için puantaj kaydı bulunamadı."
                    )
                } else {
                    Section("İşçi Listesi") {
                        ForEach(workerSGKList, id: \.worker.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.worker.fullName)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    if item.isBelowMinWage {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.hakedisDanger)
                                            .font(.caption)
                                    }
                                }
                                if let tc = item.worker.tcKimlikNo {
                                    Text("TC: \(tc)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let sgk = item.worker.sgkSicilNo {
                                    Text("SGK Sicil: \(sgk)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("Prim Gün: \(item.presentDays)")
                                    Spacer()
                                    Text("Matraha: \(item.earnings.currencyFormatted)")
                                }.font(.caption)
                                HStack {
                                    Text("İşçi SGK: \(item.workerSGK.currencyFormatted)")
                                    Spacer()
                                    Text("İşveren: \(item.employerSGK.currencyFormatted)")
                                }.font(.caption)
                                if item.isBelowMinWage {
                                    Text("⚠️ Günlük kazanç asgari ücret altında!")
                                        .font(.caption)
                                        .foregroundColor(.hakedisDanger)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section("Toplam") {
                        let totalEarnings = workerSGKList.reduce(0) { $0 + $1.earnings }
                        let totalWorkerSGK = workerSGKList.reduce(0) { $0 + $1.workerSGK }
                        let totalEmpSGK = workerSGKList.reduce(0) { $0 + $1.employerSGK }
                        let totalWorkerUnemp = workerSGKList.reduce(0) { $0 + $1.workerUnemp }
                        let totalEmpUnemp = workerSGKList.reduce(0) { $0 + $1.employerUnemp }
                        LabeledContent("İşçi Sayısı", value: "\(workerSGKList.count)")
                        LabeledContent("Kazanç Matrahı", value: totalEarnings.currencyFormatted)
                        LabeledContent("İşçi SGK (%14)", value: totalWorkerSGK.currencyFormatted)
                        LabeledContent("İşveren SGK (%20.5)", value: totalEmpSGK.currencyFormatted)
                        LabeledContent("İşçi İşsizlik (%1)", value: totalWorkerUnemp.currencyFormatted)
                        LabeledContent("İşveren İşsizlik (%2)", value: totalEmpUnemp.currencyFormatted)
                        HStack {
                            Text("TOPLAM SGK")
                                .bold()
                            Spacer()
                            Text((totalWorkerSGK + totalEmpSGK + totalWorkerUnemp + totalEmpUnemp).currencyFormatted)
                                .bold()
                                .foregroundColor(.hakedisDanger)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("SGK Bildirge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

// MARK: - MuhtasarView

struct MuhtasarView: View {
    let stopaj: Double
    let damga: Double
    let month: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Muhtasar Beyanname Özeti") {
                    LabeledContent("Hakediş Stopaj Kesintisi", value: stopaj.currencyFormatted)
                    LabeledContent("Damga Vergisi", value: damga.currencyFormatted)
                    Divider()
                    HStack {
                        Text("TOPLAM ÖDENECEK")
                            .bold()
                        Spacer()
                        Text((stopaj + damga).currencyFormatted)
                            .bold()
                            .foregroundColor(.hakedisDanger)
                    }
                }
                Section("Beyanname Bilgisi") {
                    Text("Bu özet, hakedişlerden yapılan teminat (stopaj) ve sözleşme damga vergisi tutarlarını göstermektedir. Muhasebe yazılımına girilmeden önce muhasebeci onayına sunun.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Muhtasar Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

// MARK: - KDVView

struct KDVView: View {
    let hesaplanan: Double
    let indirilecek: Double
    let month: Date
    @Environment(\.dismiss) private var dismiss

    var odenecek: Double { max(0, hesaplanan - indirilecek) }
    var iade: Double { max(0, indirilecek - hesaplanan) }

    var body: some View {
        NavigationStack {
            List {
                Section("KDV Beyannamesi Özeti") {
                    LabeledContent("Hesaplanan KDV", value: hesaplanan.currencyFormatted)
                    LabeledContent("İndirilecek KDV", value: indirilecek.currencyFormatted)
                    Divider()
                    if odenecek > 0 {
                        HStack {
                            Text("ÖDENECEK KDV")
                                .bold()
                            Spacer()
                            Text(odenecek.currencyFormatted)
                                .bold()
                                .foregroundColor(.hakedisDanger)
                        }
                    } else {
                        HStack {
                            Text("KDV İADESİ")
                                .bold()
                            Spacer()
                            Text(iade.currencyFormatted)
                                .bold()
                                .foregroundColor(.hakedisSuccess)
                        }
                    }
                }
                Section("Açıklama") {
                    Text("Hesaplanan KDV: hakedişlerden elde edilen KDV\nİndirilecek KDV: malzeme alımlarına ödenen KDV\nFark ödeme veya iade olarak beyan edilir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("KDV Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
