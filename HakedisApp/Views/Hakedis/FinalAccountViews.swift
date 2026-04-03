import SwiftUI
import SwiftData

// MARK: - FinalAccountView

struct FinalAccountView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Query private var finalAccounts: [FinalAccount]
    @State private var showingCreate = false
    @State private var showingPDF = false
    @State private var pdfData: Data?

    private var contractAccounts: [FinalAccount] {
        finalAccounts.filter { $0.contract?.id == contract.id }
    }

    var body: some View {
        Group {
            if contractAccounts.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 48)).foregroundColor(.secondary)
                    Text("Kesin Hesap Yok").font(.headline)
                    Text("Bu sözleşme için henüz kesin hesap oluşturulmadı").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    Button("Kesin Hesap Oluştur") { showingCreate = true }
                        .buttonStyle(.borderedProminent).tint(.hakedisOrange)
                        .accessibilityLabel("Kesin hesap oluştur")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(contractAccounts, id: \.id) { account in
                        NavigationLink(destination: FinalAccountDetailView(account: account)) {
                            FinalAccountRow(account: account)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { modelContext.delete(contractAccounts[i]) }
                        try? modelContext.save()
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Kesin Hesap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingCreate = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Yeni kesin hesap")
            }
        }
        .sheet(isPresented: $showingCreate) { FinalAccountForm(contract: contract) }
        .sheet(isPresented: $showingPDF) {
            if let data = pdfData {
                SafetyPDFShareSheet(data: data, fileName: "kesin_hesap.pdf")
            }
        }
    }
}

private struct FinalAccountRow: View {
    let account: FinalAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: account.status.icon).foregroundColor(.hakedisOrange)
                Text("Kesin Hesap").font(.subheadline.bold())
                Spacer()
                StatusBadge(text: account.status.rawValue, color: .hakedisOrange)
            }
            Text(account.calculationDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
            HStack {
                Text("Bakiye:").font(.caption).foregroundColor(.secondary)
                Text(account.finalBalance.currencyFormatted)
                    .font(.caption.bold())
                    .foregroundColor(account.finalBalance >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Kesin hesap, bakiye \(account.finalBalance.currencyFormatted)")
    }
}

// MARK: - FinalAccountDetailView

struct FinalAccountDetailView: View {
    let account: FinalAccount
    @Environment(\.modelContext) private var modelContext
    @State private var showingPDF = false
    @State private var pdfData: Data?

    var body: some View {
        List {
            Section("Hesap Bilgileri") {
                LabeledContent("Hesaplama Tarihi", value: account.calculationDate.shortFormatted)
                HStack {
                    Text("Durum")
                    Spacer()
                    StatusBadge(text: account.status.rawValue, color: .hakedisOrange)
                }
                if let proj = account.contract?.project { LabeledContent("Proje", value: proj.name) }
            }

            Section("Kesin Hesap Tablosu") {
                FinalAccountRow2(label: "Sözleşme Bedeli", value: account.totalContractAmount, isTotal: false)
                FinalAccountRow2(label: "Toplam Hakedişlenen", value: account.totalHakedisAmount, isTotal: false)
                if account.totalWorkIncrease > 0 {
                    FinalAccountRow2(label: "İş Artışı", value: account.totalWorkIncrease, isTotal: false, color: .hakedisSuccess)
                }
                if account.totalWorkDecrease > 0 {
                    FinalAccountRow2(label: "İş Eksilişi", value: -account.totalWorkDecrease, isTotal: false, color: .hakedisDanger)
                }
                if account.totalPriceDifference != 0 {
                    FinalAccountRow2(label: "Fiyat Farkı", value: account.totalPriceDifference, isTotal: false, color: .hakedisInfo)
                }
                FinalAccountRow2(label: "Kesilen Teminat", value: account.totalRetentionAccrued, isTotal: false)
                FinalAccountRow2(label: "İade Edilen Teminat", value: account.totalRetentionReleased, isTotal: false, color: .hakedisSuccess)
                FinalAccountRow2(label: "Kalan Teminat", value: account.retentionBalance, isTotal: false)
                if account.totalPenalty > 0 {
                    FinalAccountRow2(label: "Gecikme Cezası", value: -account.totalPenalty, isTotal: false, color: .hakedisDanger)
                }
                FinalAccountRow2(label: "Toplam Ödemeler", value: account.totalPayments, isTotal: false, color: .hakedisSuccess)
                Divider()
                FinalAccountRow2(
                    label: account.finalBalance >= 0 ? "Yüklenici Alacağı" : "İdare Alacağı",
                    value: abs(account.finalBalance),
                    isTotal: true,
                    color: account.finalBalance >= 0 ? .hakedisSuccess : .hakedisDanger
                )
            }

            if let notes = account.notes, !notes.isEmpty {
                Section("Notlar") { Text(notes) }
            }

            Section("İşlemler") {
                if account.status == .draft {
                    Button {
                        account.status = .submitted
                        try? modelContext.save()
                    } label: { Label("Gönder", systemImage: "paperplane.fill") }
                        .foregroundColor(.hakedisOrange).accessibilityLabel("Kesin hesabı gönder")
                }
                if account.status == .submitted {
                    Button {
                        account.status = .approved
                        try? modelContext.save()
                    } label: { Label("Onayla", systemImage: "checkmark.seal.fill") }
                        .foregroundColor(.hakedisSuccess).accessibilityLabel("Kesin hesabı onayla")
                }
                Button {
                    pdfData = FinalAccountPDFGenerator.generate(account: account)
                    showingPDF = true
                } label: { Label("PDF İndir", systemImage: "doc.fill") }
                    .accessibilityLabel("PDF indir")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kesin Hesap Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPDF) {
            if let data = pdfData {
                SafetyPDFShareSheet(data: data, fileName: "kesin_hesap_\(account.id.uuidString.prefix(8)).pdf")
            }
        }
    }
}

private struct FinalAccountRow2: View {
    let label: String
    let value: Double
    var isTotal: Bool = false
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(isTotal ? .body.bold() : .body)
            Spacer()
            Text(value.currencyFormatted)
                .font(isTotal ? .body.bold() : .body)
                .foregroundColor(color)
        }
        .padding(.vertical, isTotal ? 4 : 0)
    }
}

// MARK: - FinalAccountForm

struct FinalAccountForm: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var calculationDate = Date()
    @State private var notes = ""
    @State private var totalWorkIncrease = ""
    @State private var totalWorkDecrease = ""
    @State private var totalPriceDifference = ""

    private var previewAccount: FinalAccount {
        let a = FinalAccount(contract: contract)
        a.totalWorkIncrease = Double(totalWorkIncrease) ?? 0
        a.totalWorkDecrease = Double(totalWorkDecrease) ?? 0
        a.totalPriceDifference = Double(totalPriceDifference) ?? 0
        return a
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hesaplama Tarihi") {
                    DatePicker("Tarih", selection: $calculationDate, displayedComponents: .date)
                        .accessibilityLabel("Kesin hesap tarihi")
                }

                Section("Sözleşme Özeti") {
                    LabeledContent("Sözleşme Bedeli", value: contract.totalContractAmount.currencyFormatted)
                    LabeledContent("Toplam Hakedişlenen") {
                        Text(contract.hakedisler.filter { $0.status == .approved || $0.status == .paid }
                            .reduce(0) { $0 + $1.effectiveGrossAmount }.currencyFormatted)
                    }
                    LabeledContent("Toplam Ödeme") {
                        Text(contract.hakedisler.reduce(0) { $0 + $1.totalPaid }.currencyFormatted)
                    }
                }

                Section("Düzeltmeler") {
                    LabeledContent("İş Artışı (₺)") {
                        TextField("0", text: $totalWorkIncrease)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("İş Eksilişi (₺)") {
                        TextField("0", text: $totalWorkDecrease)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Fiyat Farkı (₺)") {
                        TextField("0", text: $totalPriceDifference)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Hesaplanan Bakiye") {
                    HStack {
                        Text(previewAccount.finalBalance >= 0 ? "Yüklenici Alacağı" : "İdare Alacağı")
                            .font(.body.bold())
                        Spacer()
                        Text(abs(previewAccount.finalBalance).currencyFormatted)
                            .font(.body.bold())
                            .foregroundColor(previewAccount.finalBalance >= 0 ? .hakedisSuccess : .hakedisDanger)
                    }
                }

                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60).accessibilityLabel("Not")
                }
            }
            .navigationTitle("Kesin Hesap Oluştur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() }.accessibilityLabel("İptal") }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.accessibilityLabel("Kaydet") }
            }
        }
    }

    private func save() {
        let account = FinalAccount(contract: contract)
        account.calculationDate = calculationDate
        account.totalWorkIncrease = Double(totalWorkIncrease) ?? 0
        account.totalWorkDecrease = Double(totalWorkDecrease) ?? 0
        account.totalPriceDifference = Double(totalPriceDifference) ?? 0
        account.notes = notes.isEmpty ? nil : notes
        modelContext.insert(account)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - FinalAccountPDFGenerator

struct FinalAccountPDFGenerator {

    static func generate(account: FinalAccount) -> Data {
        let pageWidth: CGFloat = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)
            ]
            NSAttributedString(string: "KESİN HESAP", attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y))
            y += 28

            let subAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.darkGray]
            if let contract = account.contract {
                NSAttributedString(string: "Sözleşme: \(contract.title)", attributes: subAttrs).draw(at: CGPoint(x: margin, y: y))
                y += 16
            }
            NSAttributedString(string: "Tarih: \(account.calculationDate.shortFormatted)", attributes: subAttrs).draw(at: CGPoint(x: margin, y: y))
            y += 16
            NSAttributedString(string: "Durum: \(account.status.rawValue)", attributes: subAttrs).draw(at: CGPoint(x: margin, y: y))
            y += 24

            // Divider
            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y))
            ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            ctx.cgContext.strokePath()
            y += 12

            let rows: [(String, Double, Bool)] = [
                ("Sözleşme Bedeli", account.totalContractAmount, false),
                ("Toplam Hakedişlenen", account.totalHakedisAmount, false),
                ("İş Artışı", account.totalWorkIncrease, false),
                ("İş Eksilişi", -account.totalWorkDecrease, false),
                ("Fiyat Farkı", account.totalPriceDifference, false),
                ("Toplam Kesilen Teminat", account.totalRetentionAccrued, false),
                ("İade Edilen Teminat", account.totalRetentionReleased, false),
                ("Kalan Teminat", account.retentionBalance, false),
                ("Gecikme Cezası", -account.totalPenalty, false),
                ("Toplam Ödemeler", account.totalPayments, false),
                (account.finalBalance >= 0 ? "YÜKLENİCİ ALACAĞI" : "İDARE ALACAĞI", account.finalBalance, true)
            ]

            for (label, value, isTotal) in rows {
                if y + 20 > pageHeight - margin { ctx.beginPage(); y = margin }
                let font = isTotal ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 10)
                let keyAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
                NSAttributedString(string: label, attributes: keyAttrs).draw(at: CGPoint(x: margin, y: y))
                let valStr = String(format: "%.2f ₺", value)
                let valAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: isTotal ? (value >= 0 ? UIColor.systemGreen : UIColor.systemRed) : UIColor.black]
                let valWidth: CGFloat = 150
                NSAttributedString(string: valStr, attributes: valAttrs).draw(at: CGPoint(x: pageWidth - margin - valWidth, y: y))
                if isTotal {
                    ctx.cgContext.setStrokeColor(UIColor.darkGray.cgColor)
                    ctx.cgContext.setLineWidth(1)
                    ctx.cgContext.move(to: CGPoint(x: margin, y: y - 2))
                    ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y - 2))
                    ctx.cgContext.strokePath()
                }
                y += isTotal ? 20 : 16
            }

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.lightGray]
            NSAttributedString(string: "HakedisApp — \(Date().shortFormatted)", attributes: footerAttrs)
                .draw(at: CGPoint(x: margin, y: pageHeight - margin + 8))
        }
    }
}

// MARK: - HakedisPeriodicComparisonView

struct HakedisPeriodicComparisonView: View {
    let contract: Contract

    private var hakedisler: [Hakedis] {
        contract.hakedisler.sorted { $0.periodStart < $1.periodStart }
    }

    private var workItems: [WorkItem] {
        contract.workItems.sorted { $0.code < $1.code }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if hakedisler.isEmpty || workItems.isEmpty {
                EmptyStateView(icon: "tablecells", title: "Karşılaştırma Verisi Yok", subtitle: "Hakedişler ve iş kalemleri oluşturulduktan sonra karşılaştırma görünür")
                    .frame(width: 300, height: 300)
            } else {
                matrixView
            }
        }
        .navigationTitle("Dönem Karşılaştırma")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.hakedisBackground)
    }

    private var matrixView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider()
            ForEach(Array(workItems.enumerated()), id: \.element.id) { idx, wi in
                ComparisonWorkItemRow(wi: wi, hakedisler: hakedisler, isEven: idx % 2 == 0)
                Divider()
            }
            totalsRow
        }
        .border(Color.gray.opacity(0.3), width: 0.5)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("İş Kalemi").font(.caption.bold()).frame(width: 160, alignment: .leading).padding(6)
                .background(Color.hakedisOrange.opacity(0.15))
            Text("Sözleşme").font(.caption.bold()).frame(width: 90, alignment: .trailing).padding(6)
                .background(Color.hakedisOrange.opacity(0.15))
            ForEach(hakedisler, id: \.id) { h in
                Text(h.periodName).font(.caption2.bold()).frame(width: 90, alignment: .trailing).padding(6)
                    .background(Color.hakedisOrange.opacity(0.1))
            }
            Text("Kümülatif").font(.caption.bold()).frame(width: 90, alignment: .trailing).padding(6)
                .background(Color.hakedisOrange.opacity(0.2))
        }
    }

    private var totalsRow: some View {
        let total = hakedisler.reduce(0.0) { $0 + $1.grossAmount }
        return HStack(spacing: 0) {
            Text("TOPLAM").font(.caption.bold()).frame(width: 160, alignment: .leading).padding(6)
            Text(contract.totalContractAmount.currencyFormatted).font(.caption.bold()).frame(width: 90, alignment: .trailing).padding(6)
            ForEach(hakedisler, id: \.id) { h in
                Text(h.grossAmount.currencyFormatted).font(.caption.bold()).frame(width: 90, alignment: .trailing).padding(6)
            }
            Text(total.currencyFormatted).font(.caption.bold()).frame(width: 90, alignment: .trailing).padding(6)
        }
        .background(Color.hakedisOrange.opacity(0.1))
    }
}

private struct ComparisonWorkItemRow: View {
    let wi: WorkItem
    let hakedisler: [Hakedis]
    let isEven: Bool

    private var cumulativeQty: Double {
        hakedisler.reduce(0.0) { sum, h in
            sum + (h.items.first(where: { $0.workItemCode == wi.code })?.currentQuantity ?? 0)
        }
    }

    private func qty(for h: Hakedis) -> Double {
        h.items.first(where: { $0.workItemCode == wi.code })?.currentQuantity ?? 0
    }

    var body: some View {
        let overrun = cumulativeQty > wi.contractedQuantity
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(wi.code).font(.caption2.bold()).foregroundColor(.hakedisOrange)
                Text(wi.name).font(.caption2).lineLimit(1)
            }
            .frame(width: 160, alignment: .leading).padding(6)

            Text(wi.contractedQuantity.quantityFormatted + " " + wi.unit)
                .font(.caption2).frame(width: 90, alignment: .trailing).padding(6)

            ForEach(hakedisler, id: \.id) { h in
                let q = qty(for: h)
                Text(q > 0 ? q.quantityFormatted : "-")
                    .font(.caption2).frame(width: 90, alignment: .trailing).padding(6)
                    .foregroundColor(q > 0 ? .primary : .secondary)
            }

            HStack(spacing: 2) {
                if overrun {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8)).foregroundColor(.hakedisDanger)
                }
                Text(cumulativeQty.quantityFormatted).font(.caption2.bold())
            }
            .frame(width: 90, alignment: .trailing).padding(6)
            .foregroundColor(overrun ? .hakedisDanger : .hakedisSuccess)
        }
        .background(isEven ? Color.hakedisCard : Color.hakedisBackground)
    }
}
