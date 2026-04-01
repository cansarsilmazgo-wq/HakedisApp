import SwiftUI

struct PetitionGeneratorView: View {
    let hakedis: Hakedis
    @Environment(\.dismiss) private var dismiss

    @State private var recipientName: String
    @State private var petitionBody: String
    @State private var requestedAmount: String
    @State private var petitionDate = Date()

    init(hakedis: Hakedis) {
        self.hakedis = hakedis
        let contractorName = hakedis.contract?.contractor?.name ?? "Yüklenici"
        let projectTitle = hakedis.contract?.title ?? "Proje"
        let rejectionReason = hakedis.revisions.last?.rejectionReason ?? "Belirtilmemiş"
        let rejectionDate = hakedis.revisions.last?.rejectedAt ?? Date()
        _recipientName = State(initialValue: projectTitle)
        _requestedAmount = State(initialValue: hakedis.netAmount.currencyFormatted)

        let template = """
\(projectTitle)'a,

Yüklenicisi olduğumuz \(projectTitle) işi kapsamında \(hakedis.periodName) dönemine ait hakedişimiz \(rejectionDate.shortFormatted) tarihinde "\(rejectionReason)" gerekçesiyle reddedilmiştir.

İtiraz gerekçemiz: [Lütfen itiraz gerekçenizi buraya yazınız]

4735 sayılı Kanun'un ilgili hükümleri ve sözleşme şartnamesi çerçevesinde, söz konusu hakedişimizin onaylanmasını saygıyla arz ederiz.

\(Date().shortFormatted)
\(contractorName)
"""
        _petitionBody = State(initialValue: template)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dilekçe Bilgileri") {
                    TextField("Muhatap (İdare Adı)", text: $recipientName)
                    DatePicker("Dilekçe Tarihi", selection: $petitionDate, displayedComponents: .date)
                    TextField("Talep Edilen Tutar", text: $requestedAmount)
                }
                Section("Dilekçe Metni") {
                    TextEditor(text: $petitionBody)
                        .frame(minHeight: 300)
                        .font(.body)
                }
            }
            .navigationTitle("İtiraz Dilekçesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: petitionBody) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
