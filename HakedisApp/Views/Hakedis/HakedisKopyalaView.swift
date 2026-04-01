import SwiftUI
import SwiftData

struct HakedisKopyalaView: View {
    let hakedis: Hakedis
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newPeriodName: String
    @State private var newStartDate: Date
    @State private var newEndDate: Date

    init(hakedis: Hakedis) {
        self.hakedis = hakedis
        let nextNum = (hakedis.contract?.hakedisler.count ?? 0) + 1
        _newPeriodName = State(initialValue: "Dönem \(nextNum)")
        let start = hakedis.periodEnd
        _newStartDate = State(initialValue: start)
        _newEndDate = State(initialValue: Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Yeni Hakediş Bilgileri") {
                    TextField("Dönem Adı", text: $newPeriodName)
                    DatePicker("Dönem Başlangıcı", selection: $newStartDate, displayedComponents: .date)
                    DatePicker("Dönem Bitişi", selection: $newEndDate, displayedComponents: .date)
                }
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundColor(.hakedisOrange)
                        Text("Hakediş kalemleri kopyalanacak. Mevcut dönemin bitiş miktarları yeni hakedişin önceki miktar değeri olarak ayarlanacak. Yeni dönem miktar girişleri sıfırdan başlar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listRowBackground(Color.hakedisOrange.opacity(0.05))
            }
            .navigationTitle("Hakedişi Kopyala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kopyala") { kopyala() }
                        .bold()
                        .disabled(newPeriodName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func kopyala() {
        let yeni = Hakedis(periodName: newPeriodName.trimmingCharacters(in: .whitespaces),
                           periodStart: newStartDate, periodEnd: newEndDate)
        yeni.status = .draft
        yeni.contract = hakedis.contract

        for eskiItem in hakedis.items {
            let yeniItem = HakedisItem(
                workItemName: eskiItem.workItemName,
                workItemCode: eskiItem.workItemCode,
                unit: eskiItem.unit,
                unitPrice: eskiItem.unitPrice,
                previousQuantity: eskiItem.previousQuantity + eskiItem.currentQuantity,
                currentQuantity: 0
            )
            yeniItem.hakedis = yeni
            modelContext.insert(yeniItem)
            yeni.items.append(yeniItem)
        }

        modelContext.insert(yeni)
        hakedis.contract?.hakedisler.append(yeni)
        dismiss()
    }
}
