import SwiftUI
import SwiftData

// MARK: - UrbanRenewalListView

struct UrbanRenewalListView: View {
    @Query(sort: \UrbanRenewalProject.createdAt, order: .reverse) private var projects: [UrbanRenewalProject]
    @State private var showAddProject = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    EmptyStateView(
                        icon: "building.2.fill",
                        title: "Kentsel Dönüşüm Projesi Yok",
                        subtitle: "Yeni bir kentsel dönüşüm projesi ekleyin.",
                        actionTitle: "Proje Ekle"
                    ) { showAddProject = true }
                } else {
                    List {
                        ForEach(projects, id: \.id) { project in
                            NavigationLink(destination: UrbanRenewalDetailView(project: project)) {
                                projectRow(project)
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                modelContext.delete(projects[i])
                            }
                            do { try modelContext.save() } catch { }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Kentsel Dönüşüm")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddProject = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Proje Ekle")
                }
            }
            .sheet(isPresented: $showAddProject) {
                AddUrbanRenewalProjectView()
            }
        }
    }

    private func projectRow(_ project: UrbanRenewalProject) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(project.projectName)
                    .font(.headline)
                Spacer()
                StatusBadge(text: project.status.rawValue, color: statusColor(project.status))
            }
            HStack {
                Label(project.district + ", " + project.city, systemImage: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(project.totalUnits) bağımsız bölüm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressBarView(progress: project.agreementRate / 100, color: .hakedisOrange)
            Text("Anlaşma: \(String(format: "%.0f%%", project.agreementRate)) (\(project.agreedStakeholderCount)/\(project.stakeholders.count) hak sahibi)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func statusColor(_ status: UrbanRenewalStatus) -> Color {
        switch status {
        case .riskAssessment: return .hakedisWarning
        case .stakeholderAgreement: return .hakedisOrange
        case .demolition: return .hakedisDanger
        case .permitting, .construction: return .hakedisInfo
        case .delivery, .completed: return .hakedisSuccess
        }
    }
}

// MARK: - UrbanRenewalDetailView

struct UrbanRenewalDetailView: View {
    @Bindable var project: UrbanRenewalProject
    @State private var showAddStakeholder = false
    @State private var showAddUnit = false
    @State private var selectedTab = 0
    @Environment(\.modelContext) private var modelContext

    private var constructionCostPerM2: Double {
        UserDefaults.standard.double(forKey: "constructionCostPerM2").isZero ? 25000 :
        UserDefaults.standard.double(forKey: "constructionCostPerM2")
    }

    private var estimatedCost: Double {
        project.totalArea * constructionCostPerM2
    }

    private var estimatedProfit: Double {
        project.estimatedRevenue - estimatedCost
    }

    var body: some View {
        List {
            // Durum timeline
            Section("Proje Durumu") {
                statusTimeline
            }

            // Proje bilgileri
            Section("Proje Bilgileri") {
                LabeledContent("Adres", value: project.address)
                LabeledContent("İlçe/İl", value: "\(project.district), \(project.city)")
                LabeledContent("Ada/Parsel", value: project.parcelNo.isEmpty ? "—" : project.parcelNo)
                LabeledContent("Sözleşme Türü", value: project.contractType.rawValue)
                LabeledContent("Toplam Kat", value: "\(project.totalFloors)")
                LabeledContent("Toplam Bölüm", value: "\(project.totalUnits)")
                LabeledContent("Toplam Alan", value: String(format: "%.0f m²", project.totalArea))
                if let rd = project.riskReportDate {
                    LabeledContent("Risk Raporu", value: rd.formatted(date: .abbreviated, time: .omitted))
                }
                if let dd = project.demolitionDate {
                    LabeledContent("Yıkım Tarihi", value: dd.formatted(date: .abbreviated, time: .omitted))
                }
            }

            // Hak sahipleri
            Section {
                HStack {
                    Text("Hak Sahipleri")
                        .font(.headline)
                    Spacer()
                    Button("Ekle") { showAddStakeholder = true }
                        .font(.caption)
                        .foregroundColor(.hakedisOrange)
                }
                if project.stakeholders.isEmpty {
                    Text("Hak sahibi eklenmemiş.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(project.stakeholders, id: \.id) { stakeholder in
                        HStack {
                            Image(systemName: stakeholder.isAgreed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(stakeholder.isAgreed ? .hakedisSuccess : .secondary)
                            VStack(alignment: .leading) {
                                Text(stakeholder.fullName)
                                    .font(.subheadline)
                                if let pct = stakeholder.sharePercentage {
                                    Text(String(format: "Arsa payı: %.2f%%", pct))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            StatusBadge(
                                text: stakeholder.isAgreed ? "Anlaşıldı" : "Bekleniyor",
                                color: stakeholder.isAgreed ? .hakedisSuccess : .hakedisWarning
                            )
                        }
                    }
                }
            }

            // Daire dağılım
            Section {
                HStack {
                    Text("Daire Dağılımı")
                        .font(.headline)
                    Spacer()
                    Button("Ekle") { showAddUnit = true }
                        .font(.caption)
                        .foregroundColor(.hakedisOrange)
                }
                unitDistributionSummary
            }

            // Kat karşılığı hesap
            Section("Kat Karşılığı Hesap") {
                HStack {
                    Text("Hak Sahibi Bölümleri")
                    Spacer()
                    Text("\(project.stakeholderUnits.count) adet")
                }
                HStack {
                    Text("Müteahhit Bölümleri")
                    Spacer()
                    Text("\(project.contractorUnits.count) adet")
                }
                HStack {
                    Text("Satışa Çıkan")
                    Spacer()
                    Text("\(project.saleUnits.count) adet")
                }
            }

            // Gelir ve maliyet
            Section("Gelir & Kârlılık") {
                LabeledContent("Tahmini Gelir", value: project.estimatedRevenue.currencyFormatted)
                LabeledContent("Tahmini Maliyet", value: estimatedCost.currencyFormatted)
                HStack {
                    Text("Tahmini Kâr")
                        .bold()
                    Spacer()
                    Text(estimatedProfit.currencyFormatted)
                        .foregroundColor(estimatedProfit >= 0 ? .hakedisSuccess : .hakedisDanger)
                        .bold()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(project.projectName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddStakeholder) {
            AddStakeholderView(project: project)
        }
        .sheet(isPresented: $showAddUnit) {
            AddUnitDistributionView(project: project)
        }
    }

    private var statusTimeline: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(UrbanRenewalStatus.allCases, id: \.self) { step in
                    let isActive = step.stepIndex <= project.status.stepIndex
                    VStack(spacing: 4) {
                        Image(systemName: step.icon)
                            .font(.system(size: 20))
                            .foregroundColor(isActive ? .hakedisOrange : .secondary)
                        Text(step.rawValue)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(isActive ? .hakedisOrange : .secondary)
                            .frame(width: 70)
                    }
                    if step != UrbanRenewalStatus.allCases.last {
                        Rectangle()
                            .frame(width: 20, height: 2)
                            .foregroundColor(isActive ? .hakedisOrange : .secondary)
                    }
                }
            }
            .padding(.vertical, Spacing.xs)
        }
    }

    private var unitDistributionSummary: some View {
        Group {
            if project.unitDistributions.isEmpty {
                Text("Daire dağılımı girilmemiş.")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(project.unitDistributions, id: \.id) { unit in
                    HStack {
                        Circle()
                            .fill(unitColor(unit.allocationTarget))
                            .frame(width: 10, height: 10)
                        Text(unit.unitNo)
                            .font(.caption)
                        Text(unit.unitType.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f m²", unit.grossArea))
                            .font(.caption)
                        Text(unit.allocationTarget.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func unitColor(_ target: AllocationTarget) -> Color {
        switch target {
        case .stakeholder: return .blue
        case .contractor:  return .hakedisOrange
        case .sale:        return .hakedisSuccess
        }
    }
}

// MARK: - AddUrbanRenewalProjectView

struct AddUrbanRenewalProjectView: View {
    @State private var projectName = ""
    @State private var address = ""
    @State private var district = ""
    @State private var city = ""
    @State private var parcelNo = ""
    @State private var contractType = UrbanRenewalContractType.landShare
    @State private var totalFloors = ""
    @State private var totalUnits = ""
    @State private var totalArea = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Proje Bilgileri") {
                    TextField("Proje adı", text: $projectName)
                    TextField("Adres", text: $address)
                    TextField("İlçe", text: $district)
                    TextField("İl", text: $city)
                    TextField("Ada/Parsel no", text: $parcelNo)
                }
                Section("Sözleşme") {
                    Picker("Sözleşme Türü", selection: $contractType) {
                        ForEach(UrbanRenewalContractType.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
                Section("Yapı Bilgileri") {
                    TextField("Toplam kat", text: $totalFloors).keyboardType(.numberPad)
                    TextField("Bağımsız bölüm sayısı", text: $totalUnits).keyboardType(.numberPad)
                    TextField("Toplam alan (m²)", text: $totalArea).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Kentsel Dönüşüm Projesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                        dismiss()
                    }
                    .disabled(projectName.isEmpty || district.isEmpty || city.isEmpty)
                }
            }
        }
    }

    private func save() {
        let p = UrbanRenewalProject(projectName: projectName, address: address, district: district, city: city)
        p.parcelNo = parcelNo
        p.contractType = contractType
        p.totalFloors = Int(totalFloors) ?? 0
        p.totalUnits = Int(totalUnits) ?? 0
        p.totalArea = Double(totalArea.replacingOccurrences(of: ",", with: ".")) ?? 0
        modelContext.insert(p)
        do { try modelContext.save() } catch { }
    }
}

// MARK: - AddStakeholderView

struct AddStakeholderView: View {
    let project: UrbanRenewalProject
    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var currentUnitNo = ""
    @State private var currentAreaText = ""
    @State private var sharePercentageText = ""
    @State private var isAgreed = false
    @State private var agreementType = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Hak Sahibi Bilgileri") {
                    TextField("Ad Soyad", text: $fullName)
                    TextField("Telefon", text: $phone).keyboardType(.phonePad)
                    TextField("E-posta", text: $email).keyboardType(.emailAddress)
                }
                Section("Mülk Bilgileri") {
                    TextField("Mevcut daire/dükkan no", text: $currentUnitNo)
                    TextField("Mevcut alan (m²)", text: $currentAreaText).keyboardType(.decimalPad)
                    TextField("Arsa payı (%)", text: $sharePercentageText).keyboardType(.decimalPad)
                }
                Section("Anlaşma") {
                    Toggle("Anlaşma sağlandı", isOn: $isAgreed)
                    if isAgreed {
                        TextField("Anlaşma türü (Daire karşılığı, Nakit...)", text: $agreementType)
                    }
                }
            }
            .navigationTitle("Hak Sahibi Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                        dismiss()
                    }
                    .disabled(fullName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let s = Stakeholder(fullName: fullName)
        s.phone = phone.isEmpty ? nil : phone
        s.email = email.isEmpty ? nil : email
        s.currentUnitNo = currentUnitNo.isEmpty ? nil : currentUnitNo
        s.currentArea = Double(currentAreaText.replacingOccurrences(of: ",", with: "."))
        s.sharePercentage = Double(sharePercentageText.replacingOccurrences(of: ",", with: "."))
        s.isAgreed = isAgreed
        s.agreementType = agreementType.isEmpty ? nil : agreementType
        if isAgreed { s.agreementDate = Date() }
        s.urbanProject = project
        modelContext.insert(s)
        do { try modelContext.save() } catch { }
    }
}

// MARK: - AddUnitDistributionView

struct AddUnitDistributionView: View {
    let project: UrbanRenewalProject
    @Query private var stakeholders: [Stakeholder]
    @State private var unitNo = ""
    @State private var unitType = UnitType.twoPlusOne
    @State private var grossAreaText = ""
    @State private var netAreaText = ""
    @State private var target = AllocationTarget.contractor
    @State private var selectedStakeholder: Stakeholder?
    @State private var estimatedValueText = ""
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var projectStakeholders: [Stakeholder] {
        stakeholders.filter { $0.urbanProject?.id == project.id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bölüm Bilgileri") {
                    TextField("Daire/bölüm no (Blok A Kat 3 No 7)", text: $unitNo)
                    Picker("Tip", selection: $unitType) {
                        ForEach(UnitType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Brüt alan (m²)", text: $grossAreaText).keyboardType(.decimalPad)
                    TextField("Net alan (m²)", text: $netAreaText).keyboardType(.decimalPad)
                    TextField("Tahmini değer (₺)", text: $estimatedValueText).keyboardType(.decimalPad)
                }
                Section("Tahsis") {
                    Picker("Kime", selection: $target) {
                        ForEach(AllocationTarget.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    if target == .stakeholder && !projectStakeholders.isEmpty {
                        Picker("Hak Sahibi", selection: $selectedStakeholder) {
                            Text("Seçiniz").tag(Optional<Stakeholder>.none)
                            ForEach(projectStakeholders, id: \.id) { s in
                                Text(s.fullName).tag(Optional(s))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Daire Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                        dismiss()
                    }
                    .disabled(unitNo.isEmpty || grossAreaText.isEmpty)
                }
            }
        }
    }

    private func save() {
        let gross = Double(grossAreaText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let net = Double(netAreaText.replacingOccurrences(of: ",", with: ".")) ?? gross
        let unit = UnitDistribution(unitNo: unitNo, unitType: unitType, grossArea: gross, netArea: net, target: target)
        unit.estimatedValue = Double(estimatedValueText.replacingOccurrences(of: ",", with: "."))
        unit.stakeholder = target == .stakeholder ? selectedStakeholder : nil
        unit.urbanProject = project
        modelContext.insert(unit)
        do { try modelContext.save() } catch { }
    }
}
