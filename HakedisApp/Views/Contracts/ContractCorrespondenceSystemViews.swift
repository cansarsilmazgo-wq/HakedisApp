import SwiftUI
import SwiftData

// MARK: - CorrespondenceLogView (A8 Yazışma Defteri)

struct CorrespondenceLogView: View {
    @Query(sort: \Correspondence.date, order: .reverse) private var allItems: [Correspondence]
    @Environment(\.modelContext) private var modelContext
    var contract: Contract? = nil

    @State private var showingAdd = false
    @State private var directionFilter: CorrespondenceDirection? = nil
    @State private var categoryFilter: LetterCategory? = nil
    @State private var searchText = ""

    private var filtered: [Correspondence] {
        allItems.filter { c in
            let contractMatch = contract == nil || c.contract?.id == contract!.id
            let dirMatch = directionFilter == nil || c.direction == directionFilter!
            let catMatch = categoryFilter == nil || c.category == categoryFilter!
            let searchMatch = searchText.isEmpty ||
                c.subject.localizedCaseInsensitiveContains(searchText) ||
                c.correspondenceNo.localizedCaseInsensitiveContains(searchText)
            return contractMatch && dirMatch && catMatch && searchMatch
        }
    }

    private var overdueCount: Int { filtered.filter { $0.isOverdue }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if overdueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                        Text("\(overdueCount) cevap süresi geçmiş yazı").font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.08))
                }

                Picker("Yön", selection: $directionFilter) {
                    Text("Tümü").tag(CorrespondenceDirection?.none)
                    Text("Gelen").tag(Optional(CorrespondenceDirection.gelen))
                    Text("Giden").tag(Optional(CorrespondenceDirection.giden))
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                .background(Color.hakedisBackground)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: categoryFilter == nil) { categoryFilter = nil }
                        ForEach(LetterCategory.allCases, id: \.self) { cat in
                            FilterChip(title: cat.rawValue, isSelected: categoryFilter == cat) {
                                categoryFilter = categoryFilter == cat ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 4)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "envelope",
                        title: "Yazışma kaydı yok",
                        subtitle: "Sözleşme yazışmalarını buradan takip edin",
                        actionTitle: "Yazışma Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { item in
                            NavigationLink(destination: CorrespondenceLogDetailView(correspondence: item)) {
                                CorrespondenceLogRow(item: item)
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Konu veya yazı no ara")
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("Yazışma ekle")
        }
        .background(Color.hakedisBackground)
        .sheet(isPresented: $showingAdd) { AddCorrespondenceLogView(contract: contract) }
    }
}

// MARK: - CorrespondenceLogRow

private struct CorrespondenceLogRow: View {
    let item: Correspondence

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: item.direction == .gelen ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(item.direction == .gelen ? .hakedisInfo : .hakedisOrange)
                Text(item.correspondenceNo).font(.caption.bold()).foregroundColor(.hakedisOrange)
                Spacer()
                if item.isOverdue {
                    StatusBadge(text: "Gecikmiş", color: .hakedisDanger)
                } else if item.isResponded {
                    StatusBadge(text: "Cevaplandı", color: .hakedisSuccess)
                } else if item.isDueSoon {
                    StatusBadge(text: "Yakın Termin", color: .hakedisWarning)
                }
            }
            Text(item.subject).font(.subheadline.bold()).lineLimit(2)
            HStack {
                Image(systemName: item.category.icon).font(.caption2).foregroundColor(.secondary)
                Text(item.category.rawValue).font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text(item.senderOrRecipient).font(.caption2).foregroundColor(.secondary)
                Text("·").font(.caption2).foregroundColor(.secondary)
                Text(item.date.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.correspondenceNo), \(item.subject)")
    }
}

// MARK: - CorrespondenceLogDetailView

struct CorrespondenceLogDetailView: View {
    let correspondence: Correspondence
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddNotification = false

    var body: some View {
        List {
            Section("Yazışma Bilgileri") {
                LabeledContent("Yazı Sayısı", value: correspondence.correspondenceNo)
                LabeledContent("Tarih", value: correspondence.date.shortFormatted)
                HStack {
                    Text("Yön")
                    Spacer()
                    Label(correspondence.direction.rawValue,
                          systemImage: correspondence.direction == .gelen ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.caption).foregroundColor(correspondence.direction == .gelen ? .hakedisInfo : .hakedisOrange)
                }
                LabeledContent("Kategori", value: correspondence.category.rawValue)
                LabeledContent(correspondence.direction == .gelen ? "Gönderen" : "Alıcı",
                               value: correspondence.senderOrRecipient)
                if correspondence.attachmentCount > 0 {
                    LabeledContent("Ek Sayısı", value: "\(correspondence.attachmentCount)")
                }
            }

            Section("Konu") {
                Text(correspondence.subject).font(.body)
                if let content = correspondence.content, !content.isEmpty {
                    Text(content).font(.caption).foregroundColor(.secondary)
                }
            }

            Section("Cevap Durumu") {
                HStack {
                    Text("Cevap Verildi mi")
                    Spacer()
                    StatusBadge(text: correspondence.isResponded ? "Evet" : "Hayır",
                                color: correspondence.isResponded ? .hakedisSuccess : .hakedisDanger)
                }
                if let dl = correspondence.responseDeadline {
                    HStack {
                        Text("Cevap Süresi")
                        Spacer()
                        Text(dl.shortFormatted).font(.caption)
                            .foregroundColor(correspondence.isOverdue ? .hakedisDanger : .secondary)
                        if correspondence.isOverdue {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .foregroundColor(.hakedisDanger).font(.caption)
                        }
                    }
                }
                if let responseNo = correspondence.responseCorrespondenceNo, !responseNo.isEmpty {
                    LabeledContent("Cevap Yazı No", value: responseNo)
                }
            }

            Section("İşlemler") {
                if !correspondence.isResponded {
                    Button {
                        correspondence.isResponded = true
                        try? modelContext.save()
                    } label: { Label("Cevaplandı Olarak İşaretle", systemImage: "checkmark.circle") }
                        .foregroundColor(.hakedisSuccess)
                }
                Button { showingAddNotification = true } label: {
                    Label("Tebliğ/Tebellüğ Kaydı Oluştur", systemImage: "person.badge.shield.checkmark")
                }
                .foregroundColor(.hakedisOrange)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(correspondence.correspondenceNo)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddNotification) {
            AddOfficialNotificationView(contract: correspondence.contract,
                                        relatedNo: correspondence.correspondenceNo)
        }
    }
}

// MARK: - AddCorrespondenceLogView

struct AddCorrespondenceLogView: View {
    var contract: Contract? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCorrespondences: [Correspondence]
    @Query private var contracts: [Contract]

    @State private var direction: CorrespondenceDirection = .gelen
    @State private var subject = ""
    @State private var senderOrRecipient = ""
    @State private var category: LetterCategory = .general
    @State private var content = ""
    @State private var date = Date()
    @State private var attachmentCount = ""
    @State private var hasResponseDeadline = false
    @State private var responseDeadline = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
    @State private var selectedContract: Contract? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Yazışma Bilgileri") {
                    Picker("Yön", selection: $direction) {
                        Text("Gelen").tag(CorrespondenceDirection.gelen)
                        Text("Giden").tag(CorrespondenceDirection.giden)
                    }.pickerStyle(.segmented)
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    Picker("Kategori", selection: $category) {
                        ForEach(LetterCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    TextField("Konu *", text: $subject).accessibilityLabel("Konu")
                    TextField(direction == .gelen ? "Gönderen kurum/kişi *" : "Alıcı kurum/kişi *",
                              text: $senderOrRecipient)
                    if contract == nil {
                        Picker("Sözleşme", selection: $selectedContract) {
                            Text("Seçilmedi").tag(Optional<Contract>.none)
                            ForEach(contracts, id: \.id) { c in Text(c.title).tag(Optional(c)) }
                        }
                    }
                    LabeledContent("Ek Sayısı") {
                        TextField("0", text: $attachmentCount)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                }
                Section("İçerik Özeti") {
                    TextEditor(text: $content).frame(minHeight: 80).accessibilityLabel("İçerik")
                }
                Section("Cevap Süresi") {
                    Toggle("Cevap süresi belirle", isOn: $hasResponseDeadline).tint(.hakedisOrange)
                    if hasResponseDeadline {
                        DatePicker("Cevap tarihi", selection: $responseDeadline, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Yazışma Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(subject.isEmpty || senderOrRecipient.isEmpty)
                }
            }
            .onAppear { selectedContract = contract }
        }
    }

    private func save() {
        let c = contract ?? selectedContract
        let existingCount = allCorrespondences.filter { $0.contract?.id == c?.id }.count
        let no = Correspondence.generateNo(existingCount: existingCount)
        let item = Correspondence(correspondenceNo: no, direction: direction,
                                  subject: subject, senderOrRecipient: senderOrRecipient,
                                  category: category, date: date)
        item.content = content.isEmpty ? nil : content
        item.attachmentCount = Int(attachmentCount) ?? 0
        item.responseDeadline = hasResponseDeadline ? responseDeadline : nil
        item.contract = c
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - OfficialNotificationListView

struct OfficialNotificationListView: View {
    @Query(sort: \OfficialNotification.notificationDate, order: .reverse) private var allItems: [OfficialNotification]
    @Environment(\.modelContext) private var modelContext
    var contract: Contract? = nil
    @State private var showingAdd = false

    private var filtered: [OfficialNotification] {
        allItems.filter { contract == nil || $0.contract?.id == contract!.id }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if filtered.isEmpty {
                    EmptyStateView(icon: "person.badge.shield.checkmark",
                                   title: "Tebliğ kaydı yok",
                                   subtitle: "Tebliğ ve tebellüğ kayıtlarını buradan takip edin",
                                   actionTitle: "Kayıt Ekle",
                                   action: { showingAdd = true })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { item in
                            OfficialNotificationRow(item: item)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(filtered[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("Tebliğ kaydı ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Tebliğ / Tebellüğ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { AddOfficialNotificationView(contract: contract) }
    }
}

private struct OfficialNotificationRow: View {
    let item: OfficialNotification
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StatusBadge(text: item.notificationType.rawValue, color: .hakedisOrange)
                Spacer()
                Text(item.notificationDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
            Text(item.subject).font(.subheadline.bold()).lineLimit(2)
            HStack {
                Text("Veren: \(item.givenBy)").font(.caption2).foregroundColor(.secondary)
                Text("·").font(.caption2).foregroundColor(.secondary)
                Text("Alan: \(item.receivedBy)").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.notificationType.rawValue), \(item.subject)")
    }
}

// MARK: - AddOfficialNotificationView

struct AddOfficialNotificationView: View {
    var contract: Contract? = nil
    var relatedNo: String? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var notificationType: NotificationType = .notification
    @State private var subject = ""
    @State private var givenBy = ""
    @State private var receivedBy = ""
    @State private var witnessName = ""
    @State private var date = Date()
    @State private var relatedCorrespondenceNo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tebliğ Bilgileri") {
                    Picker("Tür", selection: $notificationType) {
                        ForEach(NotificationType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                    }.pickerStyle(.segmented)
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    TextField("Konu *", text: $subject).accessibilityLabel("Konu")
                }
                Section("Taraflar") {
                    TextField("Tebliğ eden *", text: $givenBy).accessibilityLabel("Tebliğ eden")
                    TextField("Tebellüğ eden *", text: $receivedBy).accessibilityLabel("Tebellüğ eden")
                    TextField("Şahit (opsiyonel)", text: $witnessName)
                }
                Section("İlişkili Yazı") {
                    TextField("İlişkili yazı no", text: $relatedCorrespondenceNo)
                }
            }
            .navigationTitle("Tebliğ Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(subject.isEmpty || givenBy.isEmpty || receivedBy.isEmpty)
                }
            }
            .onAppear { if let no = relatedNo { relatedCorrespondenceNo = no } }
        }
    }

    private func save() {
        let item = OfficialNotification(subject: subject, givenBy: givenBy,
                                        receivedBy: receivedBy,
                                        notificationType: notificationType, date: date)
        item.witnessName = witnessName.isEmpty ? nil : witnessName
        item.relatedCorrespondenceNo = relatedCorrespondenceNo.isEmpty ? nil : relatedCorrespondenceNo
        item.contract = contract
        modelContext.insert(item)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - LetterGeneratorView

struct LetterGeneratorView: View {
    let contract: Contract?
    @State private var selectedTemplate: LetterTemplateType = .timeExtension
    @State private var tutar = ""
    @State private var tarih = Date()
    @State private var showingPDF = false
    @State private var pdfData: Data?

    var body: some View {
        Form {
            Section("Şablon Seçimi") {
                Picker("Şablon", selection: $selectedTemplate) {
                    ForEach(LetterTemplateType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .accessibilityLabel("Dilekçe şablonu")
            }
            Section("Değişkenler") {
                if let c = contract {
                    LabeledContent("Proje", value: c.project?.name ?? "—")
                    LabeledContent("Sözleşme", value: c.title)
                    LabeledContent("Yüklenici", value: c.contractor?.name ?? "—")
                }
                LabeledContent("Tutar") {
                    TextField("0.00", text: $tutar).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                DatePicker("Tarih", selection: $tarih, displayedComponents: .date)
            }
            Section("Metin Önizleme") {
                Text(previewText).font(.caption).foregroundColor(.secondary)
            }
            Section {
                Button {
                    pdfData = LetterPDFGenerator.generate(template: selectedTemplate,
                                                          contract: contract, tutar: tutar, date: tarih)
                    showingPDF = true
                } label: { Label("PDF Oluştur", systemImage: "doc.fill") }
                    .foregroundColor(.hakedisOrange).accessibilityLabel("PDF oluştur")
            }
        }
        .navigationTitle("Dilekçe Oluşturucu")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPDF) {
            if let data = pdfData {
                SafetyPDFShareSheet(data: data, fileName: "\(selectedTemplate.rawValue).pdf")
            }
        }
    }

    private var previewText: String {
        LetterTemplateProvider.text(for: selectedTemplate,
                                    projectName: contract?.project?.name ?? "[PROJE_ADI]",
                                    contractNo: contract?.title ?? "[SÖZLEŞME_NO]",
                                    contractorName: contract?.contractor?.name ?? "[YÜKLENİCİ_ADI]",
                                    tutar: tutar.isEmpty ? "[TUTAR]" : tutar, date: tarih)
    }
}

// MARK: - LetterTemplateType & Provider

enum LetterTemplateType: String, CaseIterable {
    case timeExtension = "Süre Uzatımı Talebi"
    case workIncrease = "İş Artışı Bildirimi"
    case priceDifference = "Fiyat Farkı Talebi"
    case penaltyObjection = "Gecikme Cezası İtirazı"
    case provisionalAcceptance = "Geçici Kabul Talebi"
    case finalAcceptance = "Kesin Kabul Talebi"
    case guaranteeReturn = "Teminat İade Talebi"
    case experienceCertificate = "İş Deneyim Belgesi Talebi"
    case claimNotice = "Hak Talebi Bildirimi"
}

struct LetterTemplateProvider {
    static func text(for template: LetterTemplateType, projectName: String, contractNo: String,
                     contractorName: String, tutar: String, date: Date) -> String {
        let ds = date.shortFormatted
        switch template {
        case .timeExtension:
            return "KONU: Süre Uzatımı Talebi\n\n\(projectName) işi (\(contractNo)) kapsamında öngörülemeyen nedenlerle sözleşme süresinin uzatılması talep edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .workIncrease:
            return "KONU: İş Artışı Bildirimi\n\n\(projectName) (\(contractNo)) kapsamında \(tutar) TL tutarında iş artışı zorunluluğu doğmuştur. Onay talep edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .priceDifference:
            return "KONU: Fiyat Farkı Talebi\n\n\(contractNo) no'lu sözleşme kapsamında \(tutar) TL fiyat farkı talebimiz bulunmaktadır.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .penaltyObjection:
            return "KONU: Gecikme Cezası İtirazı\n\n\(contractNo) sözleşmesi kapsamında uygulanan gecikme cezasına, mücbir sebep gerekçesiyle itiraz edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .provisionalAcceptance:
            return "KONU: Geçici Kabul Talebi\n\n\(projectName) (\(contractNo)) işleri tamamlanmış olup geçici kabul komisyonu oluşturulması talep edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .finalAcceptance:
            return "KONU: Kesin Kabul Talebi\n\n\(projectName) (\(contractNo)) garanti süresi dolmuş olup kesin kabul işlemleri talep edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .guaranteeReturn:
            return "KONU: Teminat İade Talebi\n\n\(contractNo) sözleşmesi kapsamında yatırılan \(tutar) TL teminatın iadesi talep edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .experienceCertificate:
            return "KONU: İş Deneyim Belgesi Talebi\n\n\(projectName) (\(contractNo)) işi tamamlandığından iş deneyim belgesinin düzenlenmesi talep edilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        case .claimNotice:
            return "KONU: Hak Talebi Bildirimi\n\n\(contractNo) sözleşmesi kapsamında \(tutar) TL tutarında hak talebimiz yasal süreler içinde bildirilmektedir.\n\nYüklenici: \(contractorName)  Tarih: \(ds)"
        }
    }
}

// MARK: - LetterPDFGenerator

struct LetterPDFGenerator {
    static func generate(template: LetterTemplateType, contract: Contract?,
                         tutar: String, date: Date) -> Data {
        let pageWidth: CGFloat = 595; let pageHeight: CGFloat = 842; let margin: CGFloat = 72
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11), .foregroundColor: UIColor.black]

            if let proj = contract?.project?.name {
                NSAttributedString(string: proj.uppercased(), attributes: bodyAttrs).draw(at: CGPoint(x: margin, y: y)); y += 16
            }
            NSAttributedString(string: "Sayı: \(Correspondence.generateNo(existingCount: 0))  Tarih: \(date.shortFormatted)", attributes: bodyAttrs).draw(at: CGPoint(x: margin, y: y)); y += 20

            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor); ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y)); ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y)); ctx.cgContext.strokePath(); y += 12

            NSAttributedString(string: template.rawValue.uppercased(), attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y)); y += 22

            let body = LetterTemplateProvider.text(
                for: template,
                projectName: contract?.project?.name ?? "[PROJE_ADI]",
                contractNo: contract?.title ?? "[SÖZLEŞME_NO]",
                contractorName: contract?.contractor?.name ?? "[YÜKLENİCİ_ADI]",
                tutar: tutar.isEmpty ? "[TUTAR]" : tutar, date: date)
            NSAttributedString(string: body, attributes: bodyAttrs)
                .draw(in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 280))

            y = pageHeight - margin - 60
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.lightGray]
            NSAttributedString(string: "HakedisApp — \(Date().shortFormatted)", attributes: footerAttrs).draw(at: CGPoint(x: margin, y: pageHeight - margin + 8))
            NSAttributedString(string: "İmza: ______________________", attributes: bodyAttrs).draw(at: CGPoint(x: pageWidth - margin - 180, y: y))
            if let name = contract?.contractor?.name {
                NSAttributedString(string: name, attributes: bodyAttrs).draw(at: CGPoint(x: pageWidth - margin - 180, y: y + 16))
            }
        }
    }
}

// MARK: - ContractMilestoneView

struct ContractMilestoneView: View {
    let contract: Contract
    @Query(sort: \ContractMilestone.plannedDate) private var allMilestones: [ContractMilestone]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var milestones: [ContractMilestone] {
        allMilestones.filter { $0.contract?.id == contract.id }
    }
    private var overdueCount: Int { milestones.filter { $0.isOverdue }.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if overdueCount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                        Text("\(overdueCount) gecikmiş milestone").font(.caption.bold()).foregroundColor(.hakedisDanger)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                    .background(Color.hakedisDanger.opacity(0.08))
                }
                if milestones.isEmpty {
                    EmptyStateView(icon: "flag.checkered", title: "Milestone yok",
                                   subtitle: "Sözleşme kilometre taşlarını buradan takip edin",
                                   actionTitle: "Ekle", action: { showingAdd = true })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(milestones, id: \.id) { ms in
                            MilestoneItemRow(milestone: ms, modelContext: modelContext)
                        }
                        .onDelete { offsets in
                            for i in offsets { modelContext.delete(milestones[i]) }
                            try? modelContext.save()
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("Milestone ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Milestone Takibi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { AddContractMilestoneView(contract: contract) }
    }
}

private struct MilestoneItemRow: View {
    let milestone: ContractMilestone
    let modelContext: ModelContext

    private var statusColor: Color {
        switch milestone.status {
        case .notStarted: return .secondary
        case .inProgress: return .hakedisWarning
        case .completed: return .hakedisSuccess
        case .delayed: return .hakedisDanger
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusColor.opacity(0.15)).frame(width: 36, height: 36)
                Image(systemName: milestone.status.icon).foregroundColor(statusColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.milestoneName).font(.subheadline.bold())
                HStack {
                    Text("Plan: \(milestone.plannedDate.shortFormatted)").font(.caption2).foregroundColor(.secondary)
                    if let actual = milestone.actualDate {
                        Text("· Gerçek: \(actual.shortFormatted)").font(.caption2).foregroundColor(.secondary)
                    }
                }
                if milestone.isOverdue && milestone.status != .completed {
                    Text("GECİKİYOR").font(.caption2.bold()).foregroundColor(.hakedisDanger)
                }
            }
            Spacer()
            Picker("", selection: Binding(
                get: { milestone.status },
                set: { milestone.status = $0; try? modelContext.save() }
            )) {
                ForEach(MilestoneStatus.allCases, id: \.self) { s in Text(s.rawValue).tag(s) }
            }
            .labelsHidden().pickerStyle(.menu)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(milestone.milestoneName), \(milestone.status.rawValue)")
    }
}

// MARK: - AddMilestoneView

struct AddContractMilestoneView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var milestoneName = ""
    @State private var plannedDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Milestone") {
                    TextField("Milestone adı *", text: $milestoneName).accessibilityLabel("Milestone adı")
                    DatePicker("Planlanan Tarih", selection: $plannedDate, displayedComponents: .date)
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle("Milestone Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        guard !milestoneName.isEmpty else { return }
                        let ms = ContractMilestone(milestoneName: milestoneName,
                                                   plannedDate: plannedDate, contract: contract)
                        ms.notes = notes.isEmpty ? nil : notes
                        modelContext.insert(ms)
                        try? modelContext.save()
                        dismiss()
                    }.disabled(milestoneName.isEmpty)
                }
            }
        }
    }
}
