import SwiftUI
import SwiftData

struct EditContractView: View {
    let contract: Contract
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contractors: [Contractor]

    @State private var title: String
    @State private var contractDate: Date
    @State private var hasDeadline: Bool
    @State private var completionDeadline: Date
    @State private var contractType: ContractType
    @State private var contractSector: ContractSector
    @State private var objectionPeriodDays: Int
    @State private var kdvRate: Double
    @State private var retentionRate: Double
    @State private var advanceRate: Double
    @State private var dailyPenaltyRateStr: String
    @State private var overdueInterestRate: Double
    @State private var selectedContractor: Contractor?

    init(contract: Contract) {
        self.contract = contract
        _title = State(initialValue: contract.title)
        _contractDate = State(initialValue: contract.contractDate)
        _hasDeadline = State(initialValue: contract.completionDeadline != nil)
        _completionDeadline = State(initialValue: contract.completionDeadline ?? Date())
        _contractType = State(initialValue: contract.contractType)
        _contractSector = State(initialValue: contract.contractSector)
        _objectionPeriodDays = State(initialValue: contract.objectionPeriodDays)
        _kdvRate = State(initialValue: contract.kdvRate)
        _retentionRate = State(initialValue: contract.retentionRate)
        _advanceRate = State(initialValue: contract.advanceRate)
        _dailyPenaltyRateStr = State(initialValue: String(format: "%.4f", contract.dailyPenaltyRate))
        _overdueInterestRate = State(initialValue: contract.overdueInterestRate)
        _selectedContractor = State(initialValue: contract.contractor)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel Bilgiler") {
                    TextField("Sözleşme başlığı", text: $title)
                    Picker("Sözleşme Tipi", selection: $contractType) {
                        ForEach(ContractType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    Picker("Sektör", selection: $contractSector) {
                        ForEach(ContractSector.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .onChange(of: contractSector) { _, newSector in
                        // Sektör değişince varsayılan itiraz süresini güncelle
                        objectionPeriodDays = newSector.defaultObjectionDays
                    }
                }
                Section("Tarihler") {
                    DatePicker("Sözleşme Tarihi", selection: $contractDate, displayedComponents: .date)
                    Toggle("Bitiş Tarihi Var", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Bitiş Tarihi", selection: $completionDeadline, displayedComponents: .date)
                    }
                }
                Section("Oranlar") {
                    HStack {
                        Text("KDV Oranı %\(Int(kdvRate))")
                        Spacer()
                        Slider(value: $kdvRate, in: 0...20, step: 1)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Teminat Kesintisi %\(Int(retentionRate))")
                        Spacer()
                        Slider(value: $retentionRate, in: 0...10, step: 0.5)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Avans Kesintisi %\(Int(advanceRate))")
                        Spacer()
                        Slider(value: $advanceRate, in: 0...30, step: 1)
                            .frame(width: 140)
                    }
                }
                Section("Ceza & Faiz") {
                    TextField("Günlük Gecikme Cezası Oranı %", text: $dailyPenaltyRateStr)
                        .keyboardType(.decimalPad)
                    HStack {
                        Text("Gecikme Faizi %\(String(format: "%.1f", overdueInterestRate))")
                        Spacer()
                        Slider(value: $overdueInterestRate, in: 1...30, step: 0.5)
                            .frame(width: 140)
                    }
                }
                Section {
                    Stepper("İtiraz Süresi: \(objectionPeriodDays) gün",
                            value: $objectionPeriodDays, in: 1...180, step: 1)
                    Text("\(contractSector.rawValue) için varsayılan: \(contractSector.defaultObjectionDays) gün")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("İtiraz & Red")
                }
                if !contractors.isEmpty {
                    Section("Yüklenici") {
                        Picker("Yüklenici", selection: $selectedContractor) {
                            Text("Seçilmedi").tag(Optional<Contractor>.none)
                            ForEach(contractors, id: \.id) { c in
                                Text(c.name).tag(Optional(c))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sözleşmeyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(!isValid).bold()
                }
            }
        }
    }

    private func save() {
        contract.title = title.trimmingCharacters(in: .whitespaces)
        contract.contractDate = contractDate
        contract.completionDeadline = hasDeadline ? completionDeadline : nil
        contract.contractType = contractType
        contract.contractSector = contractSector
        contract.objectionPeriodDays = objectionPeriodDays
        contract.kdvRate = kdvRate
        contract.retentionRate = retentionRate
        contract.advanceRate = advanceRate
        contract.dailyPenaltyRate = Double(dailyPenaltyRateStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        contract.overdueInterestRate = overdueInterestRate
        contract.contractor = selectedContractor
        dismiss()
    }
}
