import SwiftUI
import SwiftData

// MARK: - Budget List View

struct BudgetView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProjectBudget.createdAt, order: .reverse) private var budgets: [ProjectBudget]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(budgets) { budget in
                    NavigationLink(destination: BudgetDetailView(budget: budget)) {
                        BudgetRow(budget: budget)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("Bütçe Yönetimi")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) { AddBudgetView() }
            .overlay {
                if budgets.isEmpty {
                    EmptyStateView(icon: "dollarsign.circle", title: "Bütçe Yok",
                                   subtitle: "Proje bütçesi oluşturun")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(budgets[i]) }
        do { try context.save() } catch { print("BudgetView delete error: \(error)") }
    }
}

private struct BudgetRow: View {
    let budget: ProjectBudget
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(budget.budgetName).font(.headline)
            Text(budget.projectName).font(.subheadline).foregroundColor(.secondary)
            HStack {
                Text("Bütçe: \(budget.budgetedCost.currencyFormatted)")
                    .font(.caption)
                Spacer()
                let variance = budget.costVariance
                Text(variance >= 0 ? "+\(variance.currencyFormatted)" : variance.currencyFormatted)
                    .font(.caption).bold()
                    .foregroundColor(variance >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Budget Detail View

struct BudgetDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var budget: ProjectBudget
    @State private var showAddLineItem = false
    @State private var showAddOverhead = false
    @State private var showEVMDashboard = false
    @State private var showAddSnapshot = false
    @State private var showProfitability = false

    var body: some View {
        List {
            Section("Özet") {
                LabeledContent("Toplam Bütçe", value: budget.totalBudget.currencyFormatted)
                LabeledContent("Planlanan Maliyet", value: budget.budgetedCost.currencyFormatted)
                LabeledContent("Gerçek Maliyet", value: budget.actualCost.currencyFormatted)
                LabeledContent("Genel Gider", value: budget.totalOverheadCost.currencyFormatted)
                let v = budget.costVariance
                HStack {
                    Text("Bütçe Sapması")
                    Spacer()
                    Text(v >= 0 ? "+\(v.currencyFormatted)" : v.currencyFormatted)
                        .bold()
                        .foregroundColor(v >= 0 ? .hakedisSuccess : .hakedisDanger)
                }
            }
            Section("Hızlı Erişim") {
                Button {
                    showEVMDashboard = true
                } label: {
                    Label("EVM Dashboard", systemImage: "chart.xyaxis.line")
                }
                Button {
                    showProfitability = true
                } label: {
                    Label("Kârlılık Analizi", systemImage: "chart.pie")
                }
            }
            Section {
                ForEach(budget.lineItems) { item in
                    BudgetLineItemRow(item: item)
                }
                .onDelete { idx in
                    for i in idx { context.delete(budget.lineItems[i]) }
                    budget.lineItems.remove(atOffsets: idx)
                    do { try context.save() } catch { print("BudgetDetailView delete error: \(error)") }
                }
            } header: {
                HStack {
                    Text("Bütçe Kalemleri")
                    Spacer()
                    Button { showAddLineItem = true } label: { Image(systemName: "plus.circle") }
                }
            }
            Section {
                ForEach(budget.overheadExpenses.sorted(by: { $0.expenseDate > $1.expenseDate })) { exp in
                    OverheadExpenseRow(expense: exp)
                }
                .onDelete { idx in
                    let sorted = budget.overheadExpenses.sorted(by: { $0.expenseDate > $1.expenseDate })
                    for i in idx {
                        if let pos = budget.overheadExpenses.firstIndex(where: { $0.id == sorted[i].id }) {
                            context.delete(budget.overheadExpenses[pos])
                        }
                    }
                    do { try context.save() } catch { print("BudgetDetailView overhead delete error: \(error)") }
                }
            } header: {
                HStack {
                    Text("Genel Giderler")
                    Spacer()
                    Button { showAddOverhead = true } label: { Image(systemName: "plus.circle") }
                }
            }
            Section {
                ForEach(budget.evmSnapshots.sorted(by: { $0.snapshotDate > $1.snapshotDate })) { snap in
                    EVMSnapshotRow(snapshot: snap)
                }
            } header: {
                HStack {
                    Text("EVM Kayıtları")
                    Spacer()
                    Button { showAddSnapshot = true } label: { Image(systemName: "plus.circle") }
                }
            }
        }
        .navigationTitle(budget.budgetName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddLineItem) { AddBudgetLineItemView(budget: budget) }
        .sheet(isPresented: $showAddOverhead) { AddOverheadExpenseView(budget: budget) }
        .sheet(isPresented: $showEVMDashboard) { EVMDashboardView(budget: budget) }
        .sheet(isPresented: $showAddSnapshot) { AddEVMSnapshotView(budget: budget) }
        .sheet(isPresented: $showProfitability) { ProfitabilityAnalysisView(budget: budget) }
    }
}

private struct BudgetLineItemRow: View {
    let item: BudgetLineItem
    var body: some View {
        HStack {
            Image(systemName: item.category.icon).foregroundColor(.hakedisOrange).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemName).font(.headline)
                Text(item.category.rawValue).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.budgetedAmount.currencyFormatted).font(.subheadline)
                let v = item.variance
                Text(v >= 0 ? "+\(v.currencyFormatted)" : v.currencyFormatted)
                    .font(.caption).foregroundColor(v >= 0 ? .hakedisSuccess : .hakedisDanger)
            }
        }
    }
}

private struct OverheadExpenseRow: View {
    let expense: OverheadExpense
    var body: some View {
        HStack {
            Image(systemName: expense.category.icon).foregroundColor(.hakedisOrange).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.expenseName).font(.headline)
                Text(expense.expenseDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(expense.amount.currencyFormatted).font(.subheadline).bold()
        }
    }
}

private struct EVMSnapshotRow: View {
    let snapshot: EVMSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.snapshotDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption).foregroundColor(.secondary)
            HStack {
                EVMMetricBadge(label: "SPI", value: snapshot.spi, isGood: snapshot.isOnSchedule)
                EVMMetricBadge(label: "CPI", value: snapshot.cpi, isGood: snapshot.isOnBudget)
                Spacer()
                Text("\(Int(snapshot.completionPercent))% tamamlandı")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct EVMMetricBadge: View {
    let label: String
    let value: Double
    let isGood: Bool
    var body: some View {
        HStack(spacing: 2) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(String(format: "%.2f", value))
                .font(.caption).bold()
                .foregroundColor(isGood ? .hakedisSuccess : .hakedisDanger)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background((isGood ? Color.hakedisSuccess : Color.hakedisDanger).opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - EVM Dashboard View

struct EVMDashboardView: View {
    let budget: ProjectBudget
    @Environment(\.dismiss) private var dismiss

    private var latestSnapshot: EVMSnapshot? {
        budget.evmSnapshots.max(by: { $0.snapshotDate < $1.snapshotDate })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let snap = latestSnapshot {
                        EVMSummaryCard(snapshot: snap)
                        EVMForecasterCard(snapshot: snap)
                        EVMMetricsGrid(snapshot: snap)
                    } else {
                        EmptyStateView(icon: "chart.xyaxis.line", title: "EVM Verisi Yok",
                                       subtitle: "Bütçe detayından EVM kaydı ekleyin")
                    }
                }
                .padding()
            }
            .navigationTitle("EVM Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

private struct EVMSummaryCard: View {
    let snapshot: EVMSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kazanılmış Değer Analizi").font(.headline)
            HStack(spacing: 16) {
                EVMValueBox(label: "PV", value: snapshot.plannedValue, color: .hakedisOrange)
                EVMValueBox(label: "EV", value: snapshot.earnedValue, color: .hakedisSuccess)
                EVMValueBox(label: "AC", value: snapshot.actualCost, color: .hakedisDanger)
            }
            HStack(spacing: 16) {
                EVMVarianceBox(label: "SV", value: snapshot.scheduleVariance)
                EVMVarianceBox(label: "CV", value: snapshot.costVariance)
            }
        }
        .padding()
        .background(Color.hakedisCard)
        .cornerRadius(12)
    }
}

private struct EVMValueBox: View {
    let label: String
    let value: Double
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value.shortFormatted).font(.headline).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EVMVarianceBox: View {
    let label: String
    let value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value >= 0 ? "+\(value.shortFormatted)" : value.shortFormatted)
                .font(.headline)
                .foregroundColor(value >= 0 ? .hakedisSuccess : .hakedisDanger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EVMForecasterCard: View {
    let snapshot: EVMSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tahmin").font(.headline)
            HStack(spacing: 16) {
                EVMValueBox(label: "EAC", value: snapshot.eac, color: .hakedisOrange)
                EVMValueBox(label: "ETC", value: snapshot.etc, color: .hakedisOrange)
                EVMVarianceBox(label: "VAC", value: snapshot.vac)
            }
            HStack {
                Text("TCPI").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.3f", snapshot.tcpi))
                    .font(.headline)
                    .foregroundColor(snapshot.tcpi <= 1.1 ? .hakedisSuccess : .hakedisDanger)
            }
        }
        .padding()
        .background(Color.hakedisCard)
        .cornerRadius(12)
    }
}

private struct EVMMetricsGrid: View {
    let snapshot: EVMSnapshot
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatCard(title: "SPI", value: String(format: "%.2f", snapshot.spi),
                         color: snapshot.isOnSchedule ? .hakedisSuccess : .hakedisDanger,
                         icon: "calendar.badge.clock")
                StatCard(title: "CPI", value: String(format: "%.2f", snapshot.cpi),
                         color: snapshot.isOnBudget ? .hakedisSuccess : .hakedisDanger,
                         icon: "dollarsign.circle")
            }
            HStack(spacing: 8) {
                StatCard(title: "Tamamlanan",
                         value: "\(Int(snapshot.completionPercent))%",
                         color: .hakedisOrange, icon: "checkmark.circle")
                StatCard(title: "BAC",
                         value: snapshot.budgetAtCompletion.shortFormatted,
                         color: .hakedisOrange, icon: "dollarsign.square")
            }
        }
    }
}

// MARK: - Profitability Analysis View

struct ProfitabilityAnalysisView: View {
    let budget: ProjectBudget
    @Environment(\.dismiss) private var dismiss
    @State private var contractValue: Double = 0
    @State private var contractValueStr = ""

    private var totalExpense: Double { budget.totalCost }
    private var grossProfit: Double { contractValue - totalExpense }
    private var grossMargin: Double { contractValue > 0 ? grossProfit / contractValue * 100 : 0 }
    private var netProfit: Double { grossProfit }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sözleşme Değeri") {
                    TextField("Sözleşme Tutarı (₺)", text: $contractValueStr)
                        .keyboardType(.decimalPad)
                        .onChange(of: contractValueStr) { _, v in
                            contractValue = Double(v.replacingOccurrences(of: ",", with: ".")) ?? 0
                        }
                }
                Section("Maliyet Özeti") {
                    LabeledContent("Doğrudan Maliyet", value: budget.actualCost.currencyFormatted)
                    LabeledContent("Genel Gider", value: budget.totalOverheadCost.currencyFormatted)
                    LabeledContent("Toplam Maliyet", value: totalExpense.currencyFormatted)
                }
                if contractValue > 0 {
                    Section("Kârlılık") {
                        LabeledContent("Brüt Kâr", value: grossProfit.currencyFormatted)
                            .foregroundColor(grossProfit >= 0 ? .hakedisSuccess : .hakedisDanger)
                        LabeledContent("Kâr Marjı",
                                       value: String(format: "%.1f%%", grossMargin))
                            .foregroundColor(grossMargin >= 10 ? .hakedisSuccess : .hakedisDanger)
                    }
                }
            }
            .navigationTitle("Kârlılık Analizi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Forms

struct AddBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    // FAZ 17.13 — Proje picker
    @Query private var projects: [Project]

    @State private var budgetName = ""
    @State private var selectedProject: Project? = nil
    @State private var totalBudgetStr = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bütçe Adı", text: $budgetName)
                    // FAZ 17.13 — Proje picker
                    Picker("Proje", selection: $selectedProject) {
                        Text("Seçilmedi").tag(Optional<Project>.none)
                        ForEach(projects, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    TextField("Toplam Bütçe (₺)", text: $totalBudgetStr).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Yeni Bütçe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(budgetName.isEmpty)
                }
            }
        }
    }

    private func save() {
        let total = Double(totalBudgetStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let pname = selectedProject?.name ?? ""
        let b = ProjectBudget(budgetName: budgetName, projectName: pname, totalBudget: total)
        b.linkedProject = selectedProject
        context.insert(b)
        do { try context.save() } catch { print("AddBudgetView save error: \(error)") }
        dismiss()
    }
}

struct AddBudgetLineItemView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: ProjectBudget

    @State private var itemName = ""
    @State private var category = BudgetCategory.labor
    @State private var budgetedStr = ""
    @State private var actualStr = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kalem Adı", text: $itemName)
                    Picker("Kategori", selection: $category) {
                        ForEach(BudgetCategory.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    TextField("Planlanan (₺)", text: $budgetedStr).keyboardType(.decimalPad)
                    TextField("Gerçekleşen (₺)", text: $actualStr).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Bütçe Kalemi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(itemName.isEmpty || budgetedStr.isEmpty)
                }
            }
        }
    }

    private func save() {
        let b = Double(budgetedStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let a = Double(actualStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let item = BudgetLineItem(itemName: itemName, category: category, budgetedAmount: b)
        item.actualAmount = a
        item.budget = budget
        context.insert(item)
        budget.lineItems.append(item)
        do { try context.save() } catch { print("AddBudgetLineItemView save error: \(error)") }
        dismiss()
    }
}

struct AddOverheadExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: ProjectBudget

    @State private var expenseName = ""
    @State private var category = ExpenseCategory.other
    @State private var amountStr = ""
    @State private var expenseDate = Date()
    @State private var invoiceNo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Gider Adı", text: $expenseName)
                    Picker("Kategori", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    TextField("Tutar (₺)", text: $amountStr).keyboardType(.decimalPad)
                    DatePicker("Tarih", selection: $expenseDate, displayedComponents: .date)
                    TextField("Fatura No", text: $invoiceNo)
                }
            }
            .navigationTitle("Genel Gider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") { save() }.disabled(expenseName.isEmpty || amountStr.isEmpty)
                }
            }
        }
    }

    private func save() {
        let a = Double(amountStr.replacingOccurrences(of: ",", with: ".")) ?? 0
        let exp = OverheadExpense(expenseName: expenseName, category: category, amount: a, expenseDate: expenseDate)
        exp.invoiceNo = invoiceNo
        exp.budget = budget
        context.insert(exp)
        budget.overheadExpenses.append(exp)
        do { try context.save() } catch { print("AddOverheadExpenseView save error: \(error)") }
        dismiss()
    }
}

struct AddEVMSnapshotView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var budget: ProjectBudget

    @State private var snapshotDate = Date()
    @State private var bacStr = ""
    @State private var pvStr = ""
    @State private var evStr = ""
    @State private var acStr = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("EVM Değerleri") {
                    DatePicker("Tarih", selection: $snapshotDate, displayedComponents: .date)
                    TextField("BAC (Tamamlanma Bütçesi ₺)", text: $bacStr).keyboardType(.decimalPad)
                    TextField("PV (Planlanan Değer ₺)", text: $pvStr).keyboardType(.decimalPad)
                    TextField("EV (Kazanılmış Değer ₺)", text: $evStr).keyboardType(.decimalPad)
                    TextField("AC (Gerçek Maliyet ₺)", text: $acStr).keyboardType(.decimalPad)
                }
                Section("Notlar") {
                    TextField("Notlar", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle("EVM Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(bacStr.isEmpty || pvStr.isEmpty || evStr.isEmpty || acStr.isEmpty)
                }
            }
        }
    }

    private func save() {
        let p = { (s: String) -> Double in Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        let snap = EVMSnapshot(snapshotDate: snapshotDate, budgetAtCompletion: p(bacStr),
                               plannedValue: p(pvStr), earnedValue: p(evStr), actualCost: p(acStr))
        snap.notes = notes
        snap.budget = budget
        context.insert(snap)
        budget.evmSnapshots.append(snap)
        do { try context.save() } catch { print("AddEVMSnapshotView save error: \(error)") }
        dismiss()
    }
}
