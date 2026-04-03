import SwiftUI
import SwiftData

// MARK: - ContractManagementView
// Süre uzatımı + iş artışı/eksilişi + keşif artışı yönetimi

struct ContractManagementView: View {
    let contract: Contract

    @State private var selectedTab = 0
    private let tabs = ["Süre Uzatımı", "İş Artış/Eksilişi"]

    var body: some View {
        VStack(spacing: 0) {
            // Tab seçici
            Picker("Sekme", selection: $selectedTab) {
                ForEach(tabs.indices, id: \.self) { i in
                    Text(tabs[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.card)
            .background(Color.hakedisBackground)

            switch selectedTab {
            case 0:
                TimeExtensionListView(contract: contract)
            case 1:
                WorkChangeOrderListView(contract: contract)
            default:
                EmptyView()
            }
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Sözleşme Yönetimi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TimeExtensionListView

struct TimeExtensionListView: View {
    let contract: Contract

    @Query private var allRequests: [TimeExtensionRequest]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var requests: [TimeExtensionRequest] {
        allRequests.filter { $0.contract?.id == contract.id }
    }

    private var totalApprovedDays: Int {
        requests.filter { $0.isApproved }.reduce(0) { $0 + $1.extensionDays }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if requests.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "Süre uzatımı talebi yok",
                    subtitle: "4735 Md.23 kapsamında süre uzatımı taleplerini yönetin",
                    actionTitle: "Talep Ekle",
                    action: { showingAdd = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Özet") {
                        LabeledContent("Toplam Onaylanan", value: "\(totalApprovedDays) gün")
                        LabeledContent("Toplam Talep", value: "\(requests.count) adet")
                    }
                    Section("Talepler") {
                        ForEach(requests, id: \.id) { r in
                            TimeExtensionRow(request: r)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(r)
                                    } label: { Label("Sil", systemImage: "trash") }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("Süre uzatımı talebi ekle")
        }
        .sheet(isPresented: $showingAdd) {
            AddTimeExtensionView(contract: contract)
        }
    }
}

// MARK: - TimeExtensionRow

private struct TimeExtensionRow: View {
    let request: TimeExtensionRequest

    private var statusColor: Color {
        switch request.statusRaw {
        case "Onaylandı": return .hakedisSuccess
        case "Reddedildi": return .hakedisDanger
        default:           return .hakedisWarning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(request.extensionDays) gün").font(.subheadline.bold())
                Spacer()
                StatusBadge(text: request.statusRaw, color: statusColor)
            }
            Text(request.reasonCode).font(.caption).foregroundColor(.secondary)
            if !request.reasonDetails.isEmpty {
                Text(request.reasonDetails).font(.caption2).foregroundColor(.secondary).lineLimit(2)
            }
            Text(request.requestDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(request.extensionDays) gün uzatım talebi, \(request.statusRaw)")
    }
}

// MARK: - AddTimeExtensionView

struct AddTimeExtensionView: View {
    let contract: Contract

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var extensionDaysText = ""
    @State private var reasonCode = "Mücbir Sebep"
    @State private var reasonDetails = ""
    @State private var showValidation = false

    private let reasonCodes = ["Mücbir Sebep", "İdare Kaynaklı", "Hava Şartları", "Genel Grev", "Seferberlik", "Ödenek Yetersizliği"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Talep Detayı") {
                    HStack {
                        Text("Uzatma Süresi (gün)")
                        Spacer()
                        TextField("0", text: $extensionDaysText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    if showValidation && (Int(extensionDaysText) ?? 0) <= 0 {
                        Text("Geçerli gün sayısı giriniz").font(.caption).foregroundColor(.hakedisDanger)
                    }
                    Picker("Sebep Kodu", selection: $reasonCode) {
                        ForEach(reasonCodes, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Gerekçe") {
                    TextEditor(text: $reasonDetails).frame(minHeight: 80)
                }
                Section {
                    Text("4735 Sayılı Kanun Madde 23 kapsamında mücbir sebep halleri: doğal afetler, kanuni grev, genel salgın hastalık, kısmî veya genel seferberlik ilanı, idareden kaynaklanan gecikmeler.")
                        .font(.caption).foregroundColor(.secondary)
                } header: { Text("Yasal Dayanak") }
            }
            .navigationTitle("Süre Uzatımı Talebi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        guard let days = Int(extensionDaysText), days > 0 else { showValidation = true; return }
        let r = TimeExtensionRequest(extensionDays: days, reasonCode: reasonCode, reasonDetails: reasonDetails)
        r.contract = contract
        modelContext.insert(r)
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}

// MARK: - WorkChangeOrderListView

struct WorkChangeOrderListView: View {
    let contract: Contract

    @Query private var allOrders: [WorkChangeOrder]
    @Environment(\.modelContext) private var modelContext
    @State private var showingAdd = false

    private var orders: [WorkChangeOrder] {
        allOrders.filter { $0.contract?.id == contract.id }
    }

    private var totalChangeAmount: Double {
        orders.filter { $0.isApproved }.reduce(0) { $0 + $1.changeAmount }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if orders.isEmpty {
                EmptyStateView(
                    icon: "arrow.up.arrow.down.circle",
                    title: "İş artışı/eksilişi emri yok",
                    subtitle: "4735 Md.15 kapsamında iş artışı ve eksilişlerini yönetin",
                    actionTitle: "Emir Ekle",
                    action: { showingAdd = true }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Özet") {
                        LabeledContent("Toplam Onaylanan Değişim", value: totalChangeAmount.currencyFormatted)
                        let hasExceeded = orders.contains { $0.exceedsLimit }
                        if hasExceeded {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                                Text("4735 Md.15: %20 limitini aşan emir var").font(.caption).foregroundColor(.hakedisDanger)
                            }
                        }
                    }
                    Section("Emirler") {
                        ForEach(orders, id: \.id) { o in
                            WorkChangeOrderRow(order: o)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(o)
                                    } label: { Label("Sil", systemImage: "trash") }
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            Button { showingAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.hakedisOrange)
                    .clipShape(Circle())
                    .shadow(color: .hakedisOrange.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(Spacing.card + 4)
            .accessibilityLabel("İş artışı/eksilişi emri ekle")
        }
        .sheet(isPresented: $showingAdd) {
            AddWorkChangeOrderView(contract: contract)
        }
    }
}

// MARK: - WorkChangeOrderRow

private struct WorkChangeOrderRow: View {
    let order: WorkChangeOrder

    private var statusColor: Color {
        switch order.statusRaw {
        case "Onaylandı": return .hakedisSuccess
        case "Reddedildi": return .hakedisDanger
        default:           return .hakedisWarning
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.orderNo).font(.subheadline.bold())
                Spacer()
                StatusBadge(text: order.statusRaw, color: statusColor)
            }
            HStack {
                Text(order.changeType).font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(order.changeAmount.currencyFormatted).font(.caption.bold())
                    .foregroundColor(order.changeAmount >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
            HStack {
                Text(String(format: "Oran: %%%.1f", order.changePercent)).font(.caption2).foregroundColor(.secondary)
                if order.exceedsLimit {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2).foregroundColor(.hakedisDanger)
                    Text("%%20 sınırı aşıldı").font(.caption2).foregroundColor(.hakedisDanger)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(order.orderNo), \(order.changeType), \(order.changeAmount.currencyFormatted)")
    }
}

// MARK: - AddWorkChangeOrderView

struct AddWorkChangeOrderView: View {
    let contract: Contract

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var orderNo = ""
    @State private var changeType = "Artış"
    @State private var changePercentText = ""
    @State private var changeAmountText = ""
    @State private var changeDescription = ""
    @State private var showValidation = false

    private let changeTypes = ["Artış", "Eksilişi", "Keşif Revizyonu"]

    private var changePercent: Double { Double(changePercentText) ?? 0 }
    private var changeAmount: Double { Double(changeAmountText) ?? 0 }
    private var exceedsLimit: Bool { abs(changePercent) > 20 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Emir Bilgileri") {
                    TextField("Emir No (örn: İAE-001)", text: $orderNo)
                    if showValidation && orderNo.isEmpty {
                        Text("Emir no zorunludur").font(.caption).foregroundColor(.hakedisDanger)
                    }
                    Picker("Değişiklik Türü", selection: $changeType) {
                        ForEach(changeTypes, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section("Tutarlar") {
                    HStack {
                        Text("Değişim Oranı (%)")
                        Spacer()
                        TextField("0.00", text: $changePercentText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    if exceedsLimit {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                            Text("4735 Md.15 kapsamında %20 sınırı aşılıyor").font(.caption).foregroundColor(.hakedisDanger)
                        }
                    }
                    HStack {
                        Text("Değişim Tutarı (TL)")
                        Spacer()
                        TextField("0.00", text: $changeAmountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }
                Section("Açıklama") {
                    TextEditor(text: $changeDescription).frame(minHeight: 80)
                }
            }
            .navigationTitle("İş Artışı/Eksilişi Emri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } }
            }
        }
    }

    private func save() {
        guard !orderNo.isEmpty else { showValidation = true; return }
        let o = WorkChangeOrder(
            orderNo: orderNo, changeType: changeType,
            changePercent: changePercent, changeAmount: changeAmount,
            description: changeDescription
        )
        o.contract = contract
        modelContext.insert(o)
        do { try modelContext.save() } catch { print(error) }
        dismiss()
    }
}
