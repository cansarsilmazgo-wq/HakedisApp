import SwiftUI
import SwiftData

// MARK: - Work Order List View

struct WorkOrderListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkOrder.createdAt, order: .reverse) private var orders: [WorkOrder]
    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [WorkOrder] {
        if searchText.isEmpty { return orders }
        return orders.filter {
            $0.orderTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.orderNo.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if orders.filter(\.isOverdue).count > 0 {
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                        Text("\(orders.filter(\.isOverdue).count) iş emri gecikmiş")
                            .foregroundColor(.hakedisDanger).font(.subheadline)
                    }
                }
            }
            ForEach(filtered) { order in
                NavigationLink(destination: WorkOrderDetailView(order: order)) {
                    WorkOrderRow(order: order)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("İş Emirleri")
        .searchable(text: $searchText, prompt: "Ara...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddWorkOrderView() }
        .overlay {
            if filtered.isEmpty {
                EmptyStateView(icon: "doc.badge.gearshape", title: "İş Emri Yok",
                               subtitle: "Yeni iş emri ekleyin")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        do { try context.save() } catch { print("WorkOrderListView delete error: \(error)") }
    }
}

private struct WorkOrderRow: View {
    let order: WorkOrder
    private var statusColor: Color {
        switch order.status {
        case .open: return .hakedisWarning
        case .assigned, .inProgress: return .hakedisOrange
        case .completed: return .hakedisSuccess
        case .cancelled: return .secondary
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(order.orderNo).font(.caption).foregroundColor(.secondary)
                Spacer()
                if order.isOverdue {
                    Image(systemName: "exclamationmark.circle.fill").foregroundColor(.hakedisDanger).font(.caption)
                }
                StatusBadge(text: order.status.rawValue, color: statusColor)
            }
            Text(order.orderTitle).font(.headline)
            HStack {
                Label(order.orderType.rawValue, systemImage: "wrench").font(.caption)
                if !order.assignedTo.isEmpty {
                    Spacer()
                    Label(order.assignedTo, systemImage: "person").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Work Order Detail View

struct WorkOrderDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var order: WorkOrder

    var body: some View {
        List {
            Section("Bilgiler") {
                LabeledContent("Emir No", value: order.orderNo)
                LabeledContent("Tür", value: order.orderType.rawValue)
                LabeledContent("Veren", value: order.issuedBy)
                LabeledContent("Atanan", value: order.assignedTo.isEmpty ? "-" : order.assignedTo)
                LabeledContent("Konum", value: order.location.isEmpty ? "-" : order.location)
                LabeledContent("Çıkış Tarihi", value: order.issueDate.formatted(date: .abbreviated, time: .omitted))
                if let due = order.dueDate {
                    LabeledContent("Son Tarih", value: due.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(order.isOverdue ? .hakedisDanger : .primary)
                }
            }
            Section("Durum") {
                Picker("Durum", selection: $order.statusRaw) {
                    ForEach(WorkOrderStatus.allCases, id: \.rawValue) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0.rawValue)
                    }
                }
            }
            if !order.workOrderDetails.isEmpty {
                Section("İş Tanımı") { Text(order.workOrderDetails) }
            }
            if !order.completionNotes.isEmpty {
                Section("Tamamlama Notu") { Text(order.completionNotes) }
            }
        }
        .navigationTitle(order.orderTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: order.statusRaw) { _, _ in
            do { try context.save() } catch { print("WorkOrderDetailView save error: \(error)") }
        }
    }
}

// MARK: - RFI List View

struct RFIListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RFI.createdAt, order: .reverse) private var rfis: [RFI]
    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [RFI] {
        if searchText.isEmpty { return rfis }
        return rfis.filter {
            $0.subject.localizedCaseInsensitiveContains(searchText) ||
            $0.rfiNo.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { rfi in
                NavigationLink(destination: RFIDetailView(rfi: rfi)) {
                    RFIRow(rfi: rfi)
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle("Teknik Sorular (RFI)")
        .searchable(text: $searchText, prompt: "Ara...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddRFIView() }
        .overlay {
            if filtered.isEmpty {
                EmptyStateView(icon: "questionmark.circle", title: "RFI Yok",
                               subtitle: "Teknik soru ekleyin")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets { context.delete(filtered[i]) }
        do { try context.save() } catch { print("RFIListView delete error: \(error)") }
    }
}

private struct RFIRow: View {
    let rfi: RFI
    private var statusColor: Color {
        switch rfi.status {
        case .open: return .hakedisWarning
        case .pending: return .hakedisOrange
        case .answered: return .hakedisSuccess
        case .closed: return .secondary
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(rfi.rfiNo).font(.caption).foregroundColor(.secondary)
                Spacer()
                if rfi.isOverdue {
                    Image(systemName: "clock.badge.exclamationmark").foregroundColor(.hakedisDanger).font(.caption)
                }
                StatusBadge(text: rfi.status.rawValue, color: statusColor)
            }
            Text(rfi.subject).font(.headline)
            Text(rfi.askedBy).font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - RFI Detail View

struct RFIDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var rfi: RFI

    var body: some View {
        List {
            Section("Soru") {
                LabeledContent("RFI No", value: rfi.rfiNo)
                LabeledContent("Soran", value: rfi.askedBy)
                LabeledContent("Tarih", value: rfi.submittedDate.formatted(date: .abbreviated, time: .omitted))
                if !rfi.drawingReference.isEmpty {
                    LabeledContent("Çizim Ref.", value: rfi.drawingReference)
                }
                if !rfi.specSection.isEmpty {
                    LabeledContent("Şartname", value: rfi.specSection)
                }
                Text(rfi.question).font(.subheadline)
            }
            Section("Durum") {
                Picker("Durum", selection: $rfi.statusRaw) {
                    ForEach(RFIStatus.allCases, id: \.rawValue) {
                        Label($0.rawValue, systemImage: $0.icon).tag($0.rawValue)
                    }
                }
            }
            if !rfi.answer.isEmpty {
                Section("Yanıt") {
                    if let by = rfi.answeredBy {
                        LabeledContent("Yanıtlayan", value: by)
                    }
                    if let date = rfi.answeredDate {
                        LabeledContent("Yanıt Tarihi", value: date.formatted(date: .abbreviated, time: .omitted))
                    }
                    Text(rfi.answer).font(.subheadline)
                }
            }
        }
        .navigationTitle(rfi.subject)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: rfi.statusRaw) { _, _ in
            do { try context.save() } catch { print("RFIDetailView save error: \(error)") }
        }
    }
}

// MARK: - Site Announcement View

struct SiteAnnouncementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SiteAnnouncement.createdAt, order: .reverse) private var announcements: [SiteAnnouncement]
    @State private var showAdd = false

    private var active: [SiteAnnouncement] { announcements.filter(\.isVisible) }
    private var inactive: [SiteAnnouncement] { announcements.filter { !$0.isVisible } }

    var body: some View {
        List {
            if !active.isEmpty {
                Section("Aktif Duyurular") {
                    ForEach(active) { ann in
                        AnnouncementRow(announcement: ann)
                    }
                }
            }
            if !inactive.isEmpty {
                Section("Geçmiş / Pasif") {
                    ForEach(inactive) { ann in
                        AnnouncementRow(announcement: ann)
                    }
                }
            }
        }
        .navigationTitle("Şantiye Duyuruları")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) { AddAnnouncementView() }
        .overlay {
            if announcements.isEmpty {
                EmptyStateView(icon: "megaphone", title: "Duyuru Yok",
                               subtitle: "Şantiye duyurusu ekleyin")
            }
        }
    }
}

private struct AnnouncementRow: View {
    let announcement: SiteAnnouncement
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: announcement.announcementType.icon)
                    .foregroundColor(announcement.announcementType == .urgent ? .hakedisDanger : .hakedisOrange)
                Text(announcement.announcementType.rawValue).font(.caption).foregroundColor(.secondary)
                Spacer()
                if !announcement.isActive {
                    Text("Pasif").font(.caption2).foregroundColor(.secondary)
                } else if announcement.isExpired {
                    Text("Süresi Doldu").font(.caption2).foregroundColor(.hakedisDanger)
                }
            }
            Text(announcement.announcementTitle).font(.headline)
            Text(announcement.content).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
            Text("— \(announcement.postedBy) · \(announcement.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Forms

struct AddWorkOrderView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var orders: [WorkOrder]

    @State private var orderTitle = ""
    @State private var orderType = WorkOrderType.repair
    @State private var issuedBy = ""
    @State private var assignedTo = ""
    @State private var location = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(3 * 86400)
    @State private var workOrderDetails = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("İş Emri Başlığı", text: $orderTitle)
                    Picker("Tür", selection: $orderType) {
                        ForEach(WorkOrderType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Veren", text: $issuedBy)
                    TextField("Atanan", text: $assignedTo)
                    TextField("Konum", text: $location)
                    Toggle("Son Tarih", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Son Tarih", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section("İş Tanımı") {
                    TextField("Açıklama", text: $workOrderDetails, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle("Yeni İş Emri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(orderTitle.isEmpty)
                }
            }
        }
    }

    private func save() {
        let year = Calendar.current.component(.year, from: Date())
        let no = WorkOrder.generateNo(existingCount: orders.count, year: year)
        let order = WorkOrder(orderNo: no, orderTitle: orderTitle, type: orderType, issuedBy: issuedBy)
        order.assignedTo = assignedTo
        order.location = location
        order.workOrderDetails = workOrderDetails
        if hasDueDate { order.dueDate = dueDate }
        context.insert(order)
        do { try context.save() } catch { print("AddWorkOrderView save error: \(error)") }
        dismiss()
    }
}

struct AddRFIView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var rfis: [RFI]

    @State private var subject = ""
    @State private var question = ""
    @State private var askedBy = ""
    @State private var drawingRef = ""
    @State private var specSection = ""
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Konu", text: $subject)
                    TextField("Soran Kişi", text: $askedBy)
                    TextField("Çizim Referansı", text: $drawingRef)
                    TextField("Şartname Bölümü", text: $specSection)
                    Toggle("Yanıt Tarihi", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Son Yanıt Tarihi", selection: $deadline, displayedComponents: .date)
                    }
                }
                Section("Soru") {
                    TextField("Teknik soru...", text: $question, axis: .vertical).lineLimit(4...8)
                }
            }
            .navigationTitle("Yeni RFI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(subject.isEmpty || question.isEmpty)
                }
            }
        }
    }

    private func save() {
        let year = Calendar.current.component(.year, from: Date())
        let no = RFI.generateNo(existingCount: rfis.count, year: year)
        let rfi = RFI(rfiNo: no, subject: subject, question: question, askedBy: askedBy)
        rfi.drawingReference = drawingRef
        rfi.specSection = specSection
        if hasDeadline { rfi.responseDeadline = deadline }
        context.insert(rfi)
        do { try context.save() } catch { print("AddRFIView save error: \(error)") }
        dismiss()
    }
}

struct AddAnnouncementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var announcementTitle = ""
    @State private var content = ""
    @State private var announcementType = AnnouncementType.general
    @State private var postedBy = ""
    @State private var hasExpiry = false
    @State private var expiresAt = Date().addingTimeInterval(7 * 86400)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Başlık", text: $announcementTitle)
                    Picker("Tür", selection: $announcementType) {
                        ForEach(AnnouncementType.allCases, id: \.self) {
                            Label($0.rawValue, systemImage: $0.icon).tag($0)
                        }
                    }
                    TextField("Yayınlayan", text: $postedBy)
                    Toggle("Bitiş Tarihi", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Bitiş", selection: $expiresAt, displayedComponents: .date)
                    }
                }
                Section("İçerik") {
                    TextField("Duyuru içeriği...", text: $content, axis: .vertical).lineLimit(3...8)
                }
            }
            .navigationTitle("Yeni Duyuru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Yayınla") { save() }
                        .disabled(announcementTitle.isEmpty || content.isEmpty)
                }
            }
        }
    }

    private func save() {
        let ann = SiteAnnouncement(announcementTitle: announcementTitle, content: content,
                                    type: announcementType, postedBy: postedBy)
        if hasExpiry { ann.expiresAt = expiresAt }
        context.insert(ann)
        do { try context.save() } catch { print("AddAnnouncementView save error: \(error)") }
        dismiss()
    }
}
