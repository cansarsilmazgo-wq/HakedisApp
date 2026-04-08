import SwiftUI
import SwiftData

// MARK: - MeetingListView (B2)

struct MeetingListView: View {
    @Query(sort: \Meeting.meetingDate, order: .reverse) private var allMeetings: [Meeting]
    @Environment(\.modelContext) private var modelContext
    var project: Project? = nil
    @State private var showingAdd = false
    @State private var typeFilter: MeetingType? = nil

    private var filtered: [Meeting] {
        allMeetings.filter { m in
            let projMatch = project.map { m.project?.id == $0.id } ?? true
            let typeMatch = typeFilter.map { m.meetingType == $0 } ?? true
            return projMatch && typeMatch
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", isSelected: typeFilter == nil) { typeFilter = nil }
                        ForEach(MeetingType.allCases, id: \.self) { t in
                            FilterChip(title: t.rawValue, isSelected: typeFilter == t) {
                                typeFilter = typeFilter == t ? nil : t
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.card).padding(.vertical, 6)
                }
                .background(Color.hakedisBackground)

                if filtered.isEmpty {
                    EmptyStateView(icon: "person.3.fill", title: "Toplantı kaydı yok",
                                   subtitle: "Toplantıları ve kararlarını buradan takip edin",
                                   actionTitle: "Toplantı Ekle", action: { showingAdd = true })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered, id: \.id) { meeting in
                            NavigationLink(destination: MeetingDetailView(meeting: meeting)) {
                                MeetingRow(meeting: meeting)
                            }
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
            .padding(Spacing.card + 4).accessibilityLabel("Toplantı ekle")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Toplantılar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAdd) { AddMeetingView(project: project) }
    }
}

// MARK: - MeetingRow

private struct MeetingRow: View {
    let meeting: Meeting
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: meeting.meetingType.icon).foregroundColor(.hakedisOrange)
                Text(meeting.title).font(.subheadline.bold()).lineLimit(1)
                Spacer()
                if meeting.openDecisionCount > 0 {
                    StatusBadge(text: "\(meeting.openDecisionCount) açık karar", color: .hakedisWarning)
                }
            }
            HStack {
                Text(meeting.meetingType.rawValue).font(.caption2).foregroundColor(.secondary)
                if let loc = meeting.location { Text("· \(loc)").font(.caption2).foregroundColor(.secondary) }
                Spacer()
                Text("\(meeting.attendees.count) katılımcı").font(.caption2).foregroundColor(.secondary)
                Text("·").font(.caption2).foregroundColor(.secondary)
                Text(meeting.meetingDate.shortFormatted).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(meeting.title), \(meeting.meetingType.rawValue)")
    }
}

// MARK: - MeetingDetailView

struct MeetingDetailView: View {
    let meeting: Meeting
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddDecision = false
    @State private var showingPDF = false
    @State private var pdfData: Data?

    var body: some View {
        List {
            Section("Toplantı Bilgileri") {
                LabeledContent("Başlık", value: meeting.title)
                LabeledContent("Tür", value: meeting.meetingType.rawValue)
                LabeledContent("Tarih", value: meeting.meetingDate.shortFormatted)
                if let loc = meeting.location { LabeledContent("Yer", value: loc) }
            }

            if !meeting.attendees.isEmpty {
                Section("Katılımcılar (\(meeting.attendees.count))") {
                    ForEach(meeting.attendees, id: \.id) { att in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(att.name).font(.subheadline)
                                HStack {
                                    if let title = att.title { Text(title).font(.caption2).foregroundColor(.secondary) }
                                    if let company = att.company { Text("· \(company)").font(.caption2).foregroundColor(.secondary) }
                                }
                            }
                            Spacer()
                            Image(systemName: att.isSigned ? "signature" : "pencil.slash")
                                .foregroundColor(att.isSigned ? .hakedisSuccess : .secondary)
                                .font(.caption)
                        }
                    }
                }
            }

            if let agenda = meeting.agendaItems, !agenda.isEmpty {
                Section("Gündem") {
                    Text(agenda).font(.body)
                }
            }

            if let minutes = meeting.minutesText, !minutes.isEmpty {
                Section("Toplantı Tutanağı") {
                    Text(minutes).font(.body)
                }
            }

            // Previous meeting open decisions
            if let prevId = meeting.previousMeetingId {
                PreviousMeetingDecisionsSection(previousMeetingId: prevId)
            }

            Section("Kararlar (\(meeting.decisions.count))") {
                ForEach(meeting.decisions.sorted { $0.decisionNo < $1.decisionNo }, id: \.id) { decision in
                    DecisionRow(decision: decision, modelContext: modelContext)
                }
                Button { showingAddDecision = true } label: {
                    Label("Karar Ekle", systemImage: "plus.circle")
                }
                .foregroundColor(.hakedisOrange).accessibilityLabel("Karar ekle")
            }

            Section("İşlemler") {
                Button {
                    pdfData = MeetingPDFGenerator.generate(meeting: meeting)
                    showingPDF = true
                } label: { Label("Tutanak PDF", systemImage: "doc.fill") }
                    .foregroundColor(.hakedisOrange).accessibilityLabel("PDF oluştur")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddDecision) { AddDecisionView(meeting: meeting) }
        .sheet(isPresented: $showingPDF) {
            if let data = pdfData {
                SafetyPDFShareSheet(data: data, fileName: "toplanti_tutanagi.pdf")
            }
        }
    }
}

// MARK: - PreviousMeetingDecisionsSection

private struct PreviousMeetingDecisionsSection: View {
    let previousMeetingId: UUID
    @Query private var allDecisions: [MeetingDecision]

    private var openDecisions: [MeetingDecision] {
        allDecisions.filter {
            $0.meeting?.id == previousMeetingId &&
            ($0.status == .open || $0.status == .inProgress || $0.effectiveStatus == .overdue)
        }
    }

    var body: some View {
        if !openDecisions.isEmpty {
            Section("Önceki Toplantı Açık Kararları (\(openDecisions.count))") {
                ForEach(openDecisions, id: \.id) { d in
                    HStack {
                        Image(systemName: d.effectiveStatus.icon)
                            .foregroundColor(d.effectiveStatus == .overdue ? .hakedisDanger : .hakedisWarning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(d.decisionText).font(.caption).lineLimit(2)
                            Text("Sorumlu: \(d.responsiblePerson)").font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - DecisionRow

private struct DecisionRow: View {
    let decision: MeetingDecision
    let modelContext: ModelContext

    private var effectiveStatus: DecisionStatus { decision.effectiveStatus }

    private var statusColor: Color {
        switch effectiveStatus {
        case .open: return .hakedisWarning
        case .inProgress: return .hakedisInfo
        case .completed: return .hakedisSuccess
        case .overdue: return .hakedisDanger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: effectiveStatus.icon).foregroundColor(statusColor)
                Text("Karar \(decision.decisionNo)").font(.caption.bold()).foregroundColor(.hakedisOrange)
                Spacer()
                StatusBadge(text: effectiveStatus.rawValue, color: statusColor)
            }
            Text(decision.decisionText).font(.subheadline).lineLimit(3)
            HStack {
                Text("Sorumlu: \(decision.responsiblePerson)").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("Termin: \(decision.deadline.shortFormatted)").font(.caption2)
                    .foregroundColor(decision.isOverdue ? .hakedisDanger : .secondary)
            }
            if decision.status != .completed {
                Button {
                    decision.status = .completed
                    decision.completionDate = Date()
                    try? modelContext.save()
                } label: {
                    Label("Tamamlandı", systemImage: "checkmark.circle")
                        .font(.caption).foregroundColor(.hakedisSuccess)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AddMeetingView

struct AddMeetingView: View {
    var project: Project? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [Project]
    @Query(sort: \Meeting.meetingDate, order: .reverse) private var allMeetings: [Meeting]

    @State private var title = ""
    @State private var meetingType: MeetingType = .weeklyCoordination
    @State private var meetingDate = Date()
    @State private var location = ""
    @State private var agendaItems = ""
    @State private var minutesText = ""
    @State private var attendeeName = ""
    @State private var attendeeTitle = ""
    @State private var attendeeCompany = ""
    @State private var attendees: [MeetingAttendee] = []
    @State private var linkPreviousMeeting = false
    @State private var selectedPreviousMeeting: Meeting? = nil
    @State private var selectedProject: Project? = nil

    private var projectMeetings: [Meeting] {
        allMeetings.filter { m in
            let p = project ?? selectedProject
            return p.map { m.project?.id == $0.id } ?? true
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Toplantı Bilgileri") {
                    TextField("Başlık *", text: $title).accessibilityLabel("Toplantı başlığı")
                    Picker("Tür", selection: $meetingType) {
                        ForEach(MeetingType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    DatePicker("Tarih", selection: $meetingDate, displayedComponents: .date)
                    TextField("Toplantı yeri", text: $location)
                    if project == nil {
                        Picker("Proje", selection: $selectedProject) {
                            Text("Seçilmedi").tag(Optional<Project>.none)
                            ForEach(projects, id: \.id) { p in Text(p.name).tag(Optional(p)) }
                        }
                    }
                }

                Section("Katılımcı Ekle") {
                    TextField("Ad Soyad", text: $attendeeName)
                    TextField("Unvan", text: $attendeeTitle)
                    TextField("Firma", text: $attendeeCompany)
                    Button {
                        guard !attendeeName.isEmpty else { return }
                        let att = MeetingAttendee(name: attendeeName,
                                                  title: attendeeTitle.isEmpty ? nil : attendeeTitle,
                                                  company: attendeeCompany.isEmpty ? nil : attendeeCompany)
                        attendees.append(att)
                        attendeeName = ""; attendeeTitle = ""; attendeeCompany = ""
                    } label: { Label("Katılımcı Ekle", systemImage: "plus.circle") }
                        .foregroundColor(.hakedisOrange).disabled(attendeeName.isEmpty)
                }

                if !attendees.isEmpty {
                    Section("Katılımcılar (\(attendees.count))") {
                        ForEach(attendees, id: \.id) { att in
                            HStack {
                                Text(att.name).font(.subheadline)
                                if let t = att.title { Text(t).font(.caption2).foregroundColor(.secondary) }
                                Spacer()
                            }
                        }
                        .onDelete { offsets in attendees.remove(atOffsets: offsets) }
                    }
                }

                Section("Gündem") {
                    TextEditor(text: $agendaItems).frame(minHeight: 80).accessibilityLabel("Gündem maddeleri")
                }
                Section("Tutanak") {
                    TextEditor(text: $minutesText).frame(minHeight: 100).accessibilityLabel("Toplantı tutanağı")
                }

                if !projectMeetings.isEmpty {
                    Section("Önceki Toplantı") {
                        Toggle("Önceki toplantıya bağla", isOn: $linkPreviousMeeting).tint(.hakedisOrange)
                        if linkPreviousMeeting {
                            Picker("Toplantı", selection: $selectedPreviousMeeting) {
                                Text("Seçilmedi").tag(Optional<Meeting>.none)
                                ForEach(projectMeetings, id: \.id) { m in
                                    Text(m.title).tag(Optional(m))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Toplantı Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.disabled(title.isEmpty)
                }
            }
            .onAppear { selectedProject = project }
        }
    }

    private func save() {
        let meeting = Meeting(title: title, meetingType: meetingType, meetingDate: meetingDate)
        meeting.location = location.isEmpty ? nil : location
        meeting.agendaItems = agendaItems.isEmpty ? nil : agendaItems
        meeting.minutesText = minutesText.isEmpty ? nil : minutesText
        meeting.attendees = attendees
        meeting.project = project ?? selectedProject
        if linkPreviousMeeting, let prev = selectedPreviousMeeting {
            meeting.previousMeetingId = prev.id
        }
        modelContext.insert(meeting)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - AddDecisionView

struct AddDecisionView: View {
    let meeting: Meeting
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var decisionText = ""
    @State private var responsiblePerson = ""
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Karar") {
                    TextEditor(text: $decisionText).frame(minHeight: 80).accessibilityLabel("Karar metni")
                    TextField("Sorumlu kişi *", text: $responsiblePerson).accessibilityLabel("Sorumlu")
                    DatePicker("Termin Tarihi", selection: $deadline, displayedComponents: .date)
                }
                Section("Notlar") {
                    TextEditor(text: $notes).frame(minHeight: 60)
                }
            }
            .navigationTitle("Karar Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .disabled(decisionText.isEmpty || responsiblePerson.isEmpty)
                }
            }
        }
    }

    private func save() {
        let decisionNo = (meeting.decisions.map { $0.decisionNo }.max() ?? 0) + 1
        let d = MeetingDecision(decisionNo: decisionNo, decisionText: decisionText,
                                responsiblePerson: responsiblePerson, deadline: deadline)
        d.notes = notes.isEmpty ? nil : notes
        d.meeting = meeting
        meeting.decisions.append(d)
        modelContext.insert(d)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - DecisionTrackingView

struct DecisionTrackingView: View {
    @Query(sort: \MeetingDecision.deadline) private var allDecisions: [MeetingDecision]
    @Environment(\.modelContext) private var modelContext
    @State private var responsibleFilter = ""
    @State private var showOnlyOpen = true

    private var filtered: [MeetingDecision] {
        allDecisions.filter { d in
            let openMatch = !showOnlyOpen || d.status != .completed
            let personMatch = responsibleFilter.isEmpty ||
                d.responsiblePerson.localizedCaseInsensitiveContains(responsibleFilter)
            return openMatch && personMatch
        }
    }

    private var overdueCount: Int { filtered.filter { $0.isOverdue && $0.status != .completed }.count }

    var body: some View {
        VStack(spacing: 0) {
            if overdueCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.hakedisDanger)
                    Text("\(overdueCount) gecikmiş karar").font(.caption.bold()).foregroundColor(.hakedisDanger)
                    Spacer()
                }
                .padding(.horizontal, Spacing.card).padding(.vertical, 8)
                .background(Color.hakedisDanger.opacity(0.08))
            }

            List {
                Section {
                    Toggle("Sadece açık kararlar", isOn: $showOnlyOpen).tint(.hakedisOrange)
                    TextField("Sorumlu filtrele", text: $responsibleFilter)
                }
                if filtered.isEmpty {
                    Section {
                        EmptyStateView(
                            icon: "checkmark.circle",
                            title: showOnlyOpen ? "Açık karar yok" : "Karar bulunamadı",
                            subtitle: showOnlyOpen ? "Tüm kararlar tamamlandı." : "Filtre kriterlerini değiştirin."
                        )
                    }
                } else {
                    ForEach(filtered, id: \.id) { decision in
                        DecisionTrackingRow(decision: decision, modelContext: modelContext)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Karar Takibi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DecisionTrackingRow: View {
    let decision: MeetingDecision
    let modelContext: ModelContext
    private var effectiveStatus: DecisionStatus { decision.effectiveStatus }
    private var statusColor: Color {
        switch effectiveStatus {
        case .open: return .hakedisWarning
        case .inProgress: return .hakedisInfo
        case .completed: return .hakedisSuccess
        case .overdue: return .hakedisDanger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: effectiveStatus.icon).foregroundColor(statusColor)
                if let meetingTitle = decision.meeting?.title {
                    Text(meetingTitle).font(.caption2).foregroundColor(.hakedisOrange)
                }
                Spacer()
                StatusBadge(text: effectiveStatus.rawValue, color: statusColor)
            }
            Text(decision.decisionText).font(.subheadline).lineLimit(2)
            HStack {
                Text("Sorumlu: \(decision.responsiblePerson)").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("Termin: \(decision.deadline.shortFormatted)").font(.caption2)
                    .foregroundColor(decision.isOverdue ? .hakedisDanger : .secondary)
            }
            if decision.status != .completed {
                Button {
                    decision.status = .completed
                    decision.completionDate = Date()
                    try? modelContext.save()
                } label: {
                    Label("Tamamlandı İşaretle", systemImage: "checkmark.circle")
                        .font(.caption).foregroundColor(.hakedisSuccess)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - MeetingPDFGenerator

struct MeetingPDFGenerator {
    static func generate(meeting: Meeting) -> Data {
        let pageWidth: CGFloat = 595; let pageHeight: CGFloat = 842; let margin: CGFloat = 50
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor(red: 0.96, green: 0.45, blue: 0.12, alpha: 1)]
            let boldAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.black]
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray]

            NSAttributedString(string: "TOPLANTI TUTANAĞI", attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y)); y += 24
            NSAttributedString(string: "\(meeting.meetingType.rawValue) — \(meeting.meetingDate.shortFormatted)", attributes: boldAttrs).draw(at: CGPoint(x: margin, y: y)); y += 16
            NSAttributedString(string: meeting.title, attributes: bodyAttrs).draw(at: CGPoint(x: margin, y: y)); y += 14
            if let loc = meeting.location {
                NSAttributedString(string: "Yer: \(loc)", attributes: bodyAttrs).draw(at: CGPoint(x: margin, y: y)); y += 12
            }

            ctx.cgContext.setStrokeColor(UIColor.lightGray.cgColor); ctx.cgContext.setLineWidth(0.5)
            ctx.cgContext.move(to: CGPoint(x: margin, y: y)); ctx.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y)); ctx.cgContext.strokePath(); y += 10

            // Attendees
            if !meeting.attendees.isEmpty {
                NSAttributedString(string: "KATILIMCİLAR", attributes: boldAttrs).draw(at: CGPoint(x: margin, y: y)); y += 14
                for att in meeting.attendees {
                    if y + 14 > pageHeight - margin { ctx.beginPage(); y = margin }
                    let line = "\(att.name)\(att.title.map { ", \($0)" } ?? "")\(att.company.map { " (\($0))" } ?? "")"
                    NSAttributedString(string: "• \(line)", attributes: smallAttrs).draw(at: CGPoint(x: margin + 8, y: y)); y += 12
                }
                y += 8
            }

            // Agenda
            if let agenda = meeting.agendaItems, !agenda.isEmpty {
                if y + 40 > pageHeight - margin { ctx.beginPage(); y = margin }
                NSAttributedString(string: "GÜNDEM", attributes: boldAttrs).draw(at: CGPoint(x: margin, y: y)); y += 14
                NSAttributedString(string: agenda, attributes: bodyAttrs).draw(in: CGRect(x: margin + 8, y: y, width: pageWidth - margin * 2 - 8, height: 100)); y += 60
            }

            // Minutes
            if let minutes = meeting.minutesText, !minutes.isEmpty {
                if y + 40 > pageHeight - margin { ctx.beginPage(); y = margin }
                NSAttributedString(string: "TUTANAK", attributes: boldAttrs).draw(at: CGPoint(x: margin, y: y)); y += 14
                NSAttributedString(string: minutes, attributes: bodyAttrs).draw(in: CGRect(x: margin + 8, y: y, width: pageWidth - margin * 2 - 8, height: 120)); y += 80
            }

            // Decisions
            let sortedDecisions = meeting.decisions.sorted { $0.decisionNo < $1.decisionNo }
            if !sortedDecisions.isEmpty {
                if y + 40 > pageHeight - margin { ctx.beginPage(); y = margin }
                NSAttributedString(string: "KARARLAR", attributes: boldAttrs).draw(at: CGPoint(x: margin, y: y)); y += 14
                for d in sortedDecisions {
                    if y + 30 > pageHeight - margin { ctx.beginPage(); y = margin }
                    NSAttributedString(string: "Karar \(d.decisionNo): \(d.decisionText)", attributes: bodyAttrs)
                        .draw(in: CGRect(x: margin + 8, y: y, width: pageWidth - margin * 2 - 8, height: 30)); y += 14
                    NSAttributedString(string: "Sorumlu: \(d.responsiblePerson)  Termin: \(d.deadline.shortFormatted)", attributes: smallAttrs)
                        .draw(at: CGPoint(x: margin + 16, y: y)); y += 16
                }
            }

            // Footer
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.lightGray]
            NSAttributedString(string: "HakedisApp — Toplantı Tutanağı — \(Date().shortFormatted)", attributes: footerAttrs)
                .draw(at: CGPoint(x: margin, y: pageHeight - margin + 8))
        }
    }
}
