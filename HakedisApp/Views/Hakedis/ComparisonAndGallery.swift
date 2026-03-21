import SwiftUI
import SwiftData

// MARK: - Hakediş Karşılaştırma
struct HakedisComparisonView: View {
    let contract: Contract
    @State private var hakedis1: Hakedis?
    @State private var hakedis2: Hakedis?

    var sortedHakedisler: [Hakedis] {
        contract.hakedisler.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section("Dönem Seçimi") {
                Picker("1. Dönem", selection: $hakedis1) {
                    Text("Seçiniz").tag(Optional<Hakedis>.none)
                    ForEach(sortedHakedisler) { h in
                        Text(h.periodName).tag(Optional(h))
                    }
                }
                Picker("2. Dönem", selection: $hakedis2) {
                    Text("Seçiniz").tag(Optional<Hakedis>.none)
                    ForEach(sortedHakedisler) { h in
                        Text(h.periodName).tag(Optional(h))
                    }
                }
            }

            if let h1 = hakedis1, let h2 = hakedis2 {
                Section("Finansal Karşılaştırma") {
                    ComparisonRow(
                        label: "Brüt Tutar",
                        val1: h1.grossAmount.currencyFormatted,
                        val2: h2.grossAmount.currencyFormatted,
                        diff: h2.grossAmount - h1.grossAmount,
                        isCurrency: true
                    )
                    ComparisonRow(
                        label: "Net Tutar",
                        val1: h1.netAmount.currencyFormatted,
                        val2: h2.netAmount.currencyFormatted,
                        diff: h2.netAmount - h1.netAmount,
                        isCurrency: true
                    )
                    ComparisonRow(
                        label: "Teminat Kesintisi",
                        val1: h1.retentionAmount.currencyFormatted,
                        val2: h2.retentionAmount.currencyFormatted,
                        diff: h2.retentionAmount - h1.retentionAmount,
                        isCurrency: true
                    )
                    ComparisonRow(
                        label: "Ödenen",
                        val1: h1.totalPaid.currencyFormatted,
                        val2: h2.totalPaid.currencyFormatted,
                        diff: h2.totalPaid - h1.totalPaid,
                        isCurrency: true
                    )
                }

                Section("İş Kalemi Karşılaştırması") {
                    let allCodes = Set(h1.items.map { $0.workItemCode } + h2.items.map { $0.workItemCode })
                    ForEach(Array(allCodes).sorted(), id: \.self) { code in
                        let item1 = h1.items.first { $0.workItemCode == code }
                        let item2 = h2.items.first { $0.workItemCode == code }
                        WorkItemComparisonRow(code: code, item1: item1, item2: item2)
                    }
                }

                Section("Özet") {
                    let growth = h1.netAmount > 0 ? ((h2.netAmount - h1.netAmount) / h1.netAmount) * 100 : 0
                    HStack {
                        Text("Dönemsel Büyüme")
                        Spacer()
                        Text("\(growth >= 0 ? "+" : "")\(growth.percentFormatted)")
                            .bold()
                            .foregroundColor(growth >= 0 ? .hakedisSuccess : .hakedisDanger)
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "İki dönem seçin",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Karşılaştırma için iki farklı dönem seçin")
                    )
                }
            }
        }
        .navigationTitle("Dönem Karşılaştırma")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ComparisonRow: View {
    let label: String
    let val1: String
    let val2: String
    let diff: Double
    let isCurrency: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundColor(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("1. Dönem").font(.caption2).foregroundColor(.secondary)
                    Text(val1).font(.subheadline.bold())
                }
                Spacer()
                Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("2. Dönem").font(.caption2).foregroundColor(.secondary)
                    Text(val2).font(.subheadline.bold())
                }
            }
            Text("\(diff >= 0 ? "+" : "")\(isCurrency ? diff.currencyFormatted : diff.quantityFormatted)")
                .font(.caption.bold())
                .foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger)
        }
        .padding(.vertical, 2)
    }
}

struct WorkItemComparisonRow: View {
    let code: String
    let item1: HakedisItem?
    let item2: HakedisItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[\(code)] \(item1?.workItemName ?? item2?.workItemName ?? "")")
                .font(.subheadline.bold())
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("1. Dönem").font(.caption2).foregroundColor(.secondary)
                    if let i1 = item1 {
                        Text("\(i1.currentQuantity.quantityFormatted) \(i1.unit)").font(.caption)
                        Text(i1.periodAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                    } else {
                        Text("—").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("2. Dönem").font(.caption2).foregroundColor(.secondary)
                    if let i2 = item2 {
                        Text("\(i2.currentQuantity.quantityFormatted) \(i2.unit)").font(.caption)
                        Text(i2.periodAmount.currencyFormatted).font(.caption.bold()).foregroundColor(.hakedisOrange)
                    } else {
                        Text("—").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Fotoğraf Galerisi
struct PhotoGalleryView: View {
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    @State private var selectedPhoto: (Data, DailyEntry)?
    @State private var filterWorkItem: WorkItem?

    private var entriesWithPhotos: [DailyEntry] {
        entries.filter { !$0.photoData.isEmpty }
    }

    private var totalPhotos: Int {
        entriesWithPhotos.reduce(0) { $0 + $1.photoData.count }
    }

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                if entriesWithPhotos.isEmpty {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "Fotoğraf yok",
                        subtitle: "Saha girişlerinde fotoğraf ekleyince burada görünür"
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(entriesWithPhotos) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.workItem?.name ?? "İş kalemi silinmiş")
                                            .font(.subheadline.bold())
                                        Text(entry.date.shortFormatted)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if !entry.location.isEmpty {
                                            Text(entry.location)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(entry.photoData.count) fotoğraf")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)

                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(entry.photoData.indices, id: \.self) { idx in
                                        if let ui = UIImage(data: entry.photoData[idx]) {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 120)
                                                .clipped()
                                                .onTapGesture {
                                                    selectedPhoto = (entry.photoData[idx], entry)
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Fotoğraf Galerisi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(totalPhotos) fotoğraf")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(item: Binding(
                get: { selectedPhoto.map { PhotoItem(data: $0.0, entry: $0.1) } },
                set: { if $0 == nil { selectedPhoto = nil } }
            )) { item in
                PhotoDetailView(photoData: item.data, entry: item.entry)
            }
        }
    }
}

struct PhotoItem: Identifiable {
    let id = UUID()
    let data: Data
    let entry: DailyEntry
}

struct PhotoDetailView: View {
    let photoData: Data
    let entry: DailyEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                if let ui = UIImage(data: photoData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let item = entry.workItem {
                        LabeledContent("İş Kalemi", value: item.name)
                        LabeledContent("Sözleşme", value: item.contract?.contractor?.name ?? "—")
                    }
                    LabeledContent("Tarih", value: entry.date.shortFormatted)
                    if !entry.location.isEmpty {
                        LabeledContent("Mahal", value: entry.location)
                    }
                    if !entry.notes.isEmpty {
                        LabeledContent("Not", value: entry.notes)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            .navigationTitle("Fotoğraf Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
