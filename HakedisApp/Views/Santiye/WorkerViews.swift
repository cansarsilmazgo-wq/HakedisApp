import SwiftUI
import SwiftData

// MARK: - WorkerListView

struct WorkerListView: View {
    @Query(sort: \Worker.fullName) private var workers: [Worker]
    @Query private var contractors: [Contractor]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var searchText = ""
    @State private var selectedContractorID: UUID? = nil
    @State private var selectedProfession: WorkerProfession? = nil

    private var filtered: [Worker] {
        workers.filter { w in
            let matchSearch = searchText.isEmpty || w.fullName.localizedCaseInsensitiveContains(searchText)
            let matchContractor = selectedContractorID == nil || w.contractor?.id == selectedContractorID
            let matchProfession = selectedProfession == nil || w.profession == selectedProfession
            return matchSearch && matchContractor && matchProfession
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Taşeron filtresi
                if !contractors.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedContractorID == nil) { selectedContractorID = nil }
                            ForEach(contractors, id: \.id) { c in
                                FilterChip(title: c.name, isSelected: selectedContractorID == c.id) {
                                    selectedContractorID = selectedContractorID == c.id ? nil : c.id
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                    }
                    .background(Color.hakedisBackground)
                }

                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: "İşçi kaydı yok",
                        subtitle: "Şantiyedeki işçileri buradan yönetin",
                        actionTitle: "İşçi Ekle",
                        action: { showingAdd = true }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { w in
                            NavigationLink(destination: WorkerDetailView(worker: w)) {
                                WorkerRow(worker: w)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { modelContext.delete(w) } label: { Label("Sil", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "İşçi ara...")
                }
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundColor(.white)
                    .frame(width: 56, height: 56).background(Color.hakedisOrange).clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4).accessibilityLabel("İşçi ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("İşçi Listesi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { AddWorkerView() }
    }
}

// MARK: - WorkerRow

private struct WorkerRow: View {
    let worker: Worker

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: worker.profession.icon)
                .font(.title2).foregroundColor(.hakedisOrange)
                .frame(width: 36, height: 36)
                .background(Color.hakedisOrange.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(worker.fullName).font(.subheadline.bold())
                    Spacer()
                    if !worker.isActive {
                        StatusBadge(text: "Pasif", color: .secondary)
                    }
                }
                Text(worker.profession.rawValue).font(.caption).foregroundColor(.secondary)
                if let cname = worker.contractor?.name {
                    Text(cname).font(.caption2).foregroundColor(.secondary)
                }
            }

            // Sertifika uyarısı
            let expiring = worker.expiringSoonCertificates()
            if !expiring.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.hakedisDanger).font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(worker.fullName), \(worker.profession.rawValue)")
    }
}

// MARK: - WorkerDetailView

struct WorkerDetailView: View {
    @Bindable var worker: Worker
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddCert = false
    @Query(sort: \Attendance.date, order: .reverse) private var allAttendances: [Attendance]

    private var workerAttendances: [Attendance] {
        let thirtyAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return allAttendances.filter { $0.worker?.id == worker.id && $0.date >= thirtyAgo }
    }

    private var thisMonthCost: Double {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return allAttendances.filter {
            $0.worker?.id == worker.id &&
            cal.dateComponents([.year, .month], from: $0.date) == comps
        }.reduce(0) { $0 + $1.totalDailyCost }
    }

    var body: some View {
        List {
            // Kişisel Bilgiler
            Section("Kişisel Bilgiler") {
                LabeledContent("Ad Soyad", value: worker.fullName)
                LabeledContent("Meslek", value: worker.profession.rawValue)
                if let cname = worker.contractor?.name { LabeledContent("Taşeron", value: cname) }
                if let bt = worker.bloodType { LabeledContent("Kan Grubu", value: bt.rawValue) }
                if let sgk = worker.sgkSicilNo { LabeledContent("SGK Sicil No", value: sgk) }
                if let ec = worker.emergencyContactName {
                    LabeledContent("Acil İletişim", value: ec + (worker.emergencyContactPhone.map { " - \($0)" } ?? ""))
                }
                LabeledContent("Günlük Maliyet", value: worker.dailyCost.currencyFormatted)
                LabeledContent("Saatlik Maliyet", value: worker.hourlyCost.currencyFormatted)
                Toggle("Aktif", isOn: $worker.isActive)
                    .onChange(of: worker.isActive) { _, _ in try? modelContext.save() }
            }

            // Maliyet Özeti
            Section("Bu Ay Maliyet") {
                HStack {
                    Text("Toplam İşçilik Maliyeti").font(.subheadline.bold())
                    Spacer()
                    Text(thisMonthCost.currencyFormatted).font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                }
            }

            // Sertifikalar
            Section {
                if worker.certificates.isEmpty {
                    Text("Sertifika kaydı yok").font(.caption).foregroundColor(.secondary)
                } else {
                    ForEach(worker.certificates, id: \.id) { cert in
                        WorkerCertificateRow(certificate: cert)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { modelContext.delete(cert) } label: { Label("Sil", systemImage: "trash") }
                            }
                    }
                }
                Button { showingAddCert = true } label: {
                    Label("Sertifika Ekle", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("Sertifikalar")
                    let expCount = worker.expiringSoonCertificates().count
                    if expCount > 0 {
                        Spacer()
                        Text("\(expCount) uyarı").font(.caption).foregroundColor(.hakedisDanger)
                    }
                }
            }

            // Son 30 Gün Puantaj
            Section("Son 30 Gün Devam") {
                if workerAttendances.isEmpty {
                    Text("Bu dönemde devam kaydı yok").font(.caption).foregroundColor(.secondary)
                } else {
                    let presentDays = workerAttendances.filter { $0.isPresent }.count
                    let sgkDays = workerAttendances.filter { $0.isSGKDay }.count
                    LabeledContent("Mevcut Gün", value: "\(presentDays) gün")
                    LabeledContent("SGK Gün", value: "\(sgkDays) gün")
                    ForEach(workerAttendances.prefix(10), id: \.id) { att in
                        HStack {
                            Text(att.date.shortFormatted).font(.caption)
                            Spacer()
                            Image(systemName: att.isPresent ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundColor(att.isPresent ? .hakedisSuccess : .secondary)
                            Text(String(format: "%.0f sa", att.totalHours)).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Yıllık İzin
            if let bd = worker.birthDate {
                let startDate = bd  // İşe başlangıç yok, doğum tarihi fallback
                let leaveDays = worker.annualLeaveDays(since: startDate)
                Section("Yıllık İzin Hakkı (4857 Md.53)") {
                    LabeledContent("Hak Edilen", value: "\(leaveDays) gün")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(worker.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCert) { AddWorkerCertificateView(worker: worker) }
    }
}

// MARK: - WorkerCertificateRow

struct WorkerCertificateRow: View {
    let certificate: WorkerCertificate

    var body: some View {
        HStack {
            Image(systemName: certificate.certificateType.icon)
                .foregroundColor(certificate.isExpired ? .hakedisDanger : certificate.isExpiringSoon ? .hakedisWarning : .hakedisSuccess)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(certificate.certificateType.rawValue).font(.subheadline)
                if let exp = certificate.expiryDate {
                    HStack(spacing: 4) {
                        Text(exp.shortFormatted).font(.caption).foregroundColor(.secondary)
                        if certificate.isExpired {
                            Text("SÜRESİ DOLDU").font(.caption2.bold()).foregroundColor(.hakedisDanger)
                        } else if certificate.isExpiringSoon, let days = certificate.daysUntilExpiry {
                            Text("\(days) gün kaldı").font(.caption2.bold()).foregroundColor(.hakedisWarning)
                        }
                    }
                }
            }
            Spacer()
            if certificate.isExpired || certificate.isExpiringSoon {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(certificate.isExpired ? .hakedisDanger : .hakedisWarning)
                    .font(.caption)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(certificate.certificateType.rawValue), \(certificate.isExpired ? "süresi dolmuş" : "geçerli")")
    }
}

// MARK: - AddWorkerView

struct AddWorkerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contractors: [Contractor]

    @State private var fullName = ""
    @State private var profession: WorkerProfession = .laborer
    @State private var bloodType: BloodType? = nil
    @State private var sgkSicilNo = ""
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""
    @State private var dailyCostText = ""
    @State private var hourlyCostText = ""
    @State private var selectedContractor: Contractor? = nil
    @State private var showValidation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Kimlik Bilgileri") {
                    TextField("Ad Soyad *", text: $fullName).accessibilityLabel("Ad soyad")
                    if showValidation && fullName.isEmpty {
                        Text("Ad Soyad zorunludur").font(.caption).foregroundColor(.hakedisDanger)
                    }
                    Picker("Meslek", selection: $profession) {
                        ForEach(WorkerProfession.allCases, id: \.rawValue) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }.accessibilityLabel("Meslek seçin")
                    Picker("Kan Grubu", selection: $bloodType) {
                        Text("Belirtilmedi").tag(Optional<BloodType>.none)
                        ForEach(BloodType.allCases, id: \.rawValue) { bt in Text(bt.rawValue).tag(Optional(bt)) }
                    }.accessibilityLabel("Kan grubu")
                    TextField("SGK Sicil No", text: $sgkSicilNo).accessibilityLabel("SGK sicil no")
                }
                Section("Taşeron") {
                    Picker("Taşeron", selection: $selectedContractor) {
                        Text("Seçilmedi").tag(Optional<Contractor>.none)
                        ForEach(contractors, id: \.id) { c in Text(c.name).tag(Optional(c)) }
                    }.accessibilityLabel("Taşeron seçin")
                }
                Section("Acil İletişim") {
                    TextField("Adı", text: $emergencyContactName).accessibilityLabel("Acil iletişim adı")
                    TextField("Telefon", text: $emergencyContactPhone).keyboardType(.phonePad).accessibilityLabel("Acil telefon")
                }
                Section("Maliyet") {
                    HStack {
                        Text("Günlük (TL)"); Spacer()
                        TextField("0.00", text: $dailyCostText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                    }
                    HStack {
                        Text("Saatlik (TL)"); Spacer()
                        TextField("0.00", text: $hourlyCostText).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                    }
                }
            }
            .navigationTitle("İşçi Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        guard !fullName.isEmpty else { showValidation = true; return }
        let w = Worker(
            fullName: fullName,
            profession: profession,
            dailyCost: Double(dailyCostText) ?? 0,
            hourlyCost: Double(hourlyCostText) ?? 0
        )
        w.bloodType = bloodType
        w.sgkSicilNo = sgkSicilNo.isEmpty ? nil : sgkSicilNo
        w.emergencyContactName = emergencyContactName.isEmpty ? nil : emergencyContactName
        w.emergencyContactPhone = emergencyContactPhone.isEmpty ? nil : emergencyContactPhone
        w.contractor = selectedContractor
        modelContext.insert(w)
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}

// MARK: - AddWorkerCertificateView

struct AddWorkerCertificateView: View {
    let worker: Worker
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var certType: CertificateType = .osgTraining
    @State private var issueDate = Date()
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var issuingAuthority = ""
    @State private var certNo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Sertifika Bilgileri") {
                    Picker("Tür", selection: $certType) {
                        ForEach(CertificateType.allCases, id: \.rawValue) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }.accessibilityLabel("Sertifika türü")
                    DatePicker("Veriliş Tarihi", selection: $issueDate, displayedComponents: .date)
                    Toggle("Son Kullanma Tarihi Var", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Son Kullanma", selection: $expiryDate, in: issueDate..., displayedComponents: .date)
                    } else if let months = certType.requiredRenewalMonths {
                        HStack {
                            Image(systemName: "info.circle").foregroundColor(.hakedisInfo)
                            Text("Bu sertifika \(months) ayda bir yenilenmeli").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    TextField("Veren Kurum", text: $issuingAuthority).accessibilityLabel("Veren kurum")
                    TextField("Belge No", text: $certNo).accessibilityLabel("Belge no")
                }
            }
            .navigationTitle("Sertifika Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        let cert = WorkerCertificate(certificateType: certType, issueDate: issueDate)
        cert.expiryDate = hasExpiry ? expiryDate : nil
        cert.issuingAuthority = issuingAuthority.isEmpty ? nil : issuingAuthority
        cert.certificateNo = certNo.isEmpty ? nil : certNo
        cert.worker = worker
        worker.certificates.append(cert)
        modelContext.insert(cert)
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}

// MARK: - SGKReportView

struct SGKReportView: View {
    @Query private var workers: [Worker]
    @Query private var attendances: [Attendance]

    @State private var selectedMonth = Date()

    private var monthComponents: DateComponents {
        Calendar.current.dateComponents([.year, .month], from: selectedMonth)
    }

    private func sgkDays(for worker: Worker) -> Int {
        attendances.filter {
            $0.worker?.id == worker.id &&
            Calendar.current.dateComponents([.year, .month], from: $0.date) == monthComponents &&
            $0.isSGKDay
        }.count
    }

    private func totalCost(for worker: Worker) -> Double {
        attendances.filter {
            $0.worker?.id == worker.id &&
            Calendar.current.dateComponents([.year, .month], from: $0.date) == monthComponents
        }.reduce(0) { $0 + $1.totalDailyCost }
    }

    var body: some View {
        VStack(spacing: 0) {
            DatePicker("Ay", selection: $selectedMonth, displayedComponents: [.date])
                .datePickerStyle(.compact)
                .padding(Spacing.card)
                .background(Color.hakedisBackground)

            List {
                Section("SGK Prim Bildirim Tablosu") {
                    HStack {
                        Text("İşçi Adı").frame(maxWidth: .infinity, alignment: .leading).font(.caption.bold())
                        Text("SGK Gün").frame(width: 60, alignment: .trailing).font(.caption.bold())
                        Text("Maliyet").frame(width: 80, alignment: .trailing).font(.caption.bold())
                    }
                    .padding(.vertical, 2)
                    ForEach(workers.filter { $0.isActive }, id: \.id) { w in
                        let days = sgkDays(for: w)
                        let cost = totalCost(for: w)
                        if days > 0 {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(w.fullName).font(.subheadline)
                                    Text(w.profession.rawValue).font(.caption2).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(days)").frame(width: 60, alignment: .trailing).font(.subheadline.bold()).foregroundColor(.hakedisInfo)
                                Text(cost.shortFormatted).frame(width: 80, alignment: .trailing).font(.caption.bold())
                            }
                        }
                    }
                }

                Section("Genel Toplam") {
                    let totalDays = workers.filter { $0.isActive }.reduce(0) { $0 + sgkDays(for: $1) }
                    let totalCostAll = workers.filter { $0.isActive }.reduce(0) { $0 + totalCost(for: $1) }
                    LabeledContent("Toplam SGK Gün", value: "\(totalDays) gün")
                    HStack {
                        Text("Toplam İşçilik").font(.subheadline.bold())
                        Spacer()
                        Text(totalCostAll.currencyFormatted).font(.subheadline.bold()).foregroundColor(.hakedisOrange)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("SGK Prim Raporu")
        .navigationBarTitleDisplayMode(.inline)
    }
}
