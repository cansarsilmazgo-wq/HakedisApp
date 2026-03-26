import SwiftUI
import SwiftData
import UIKit

// MARK: - Thumbnail Cache

private final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        c.totalCostLimit = 50 * 1024 * 1024
        return c
    }()

    func thumbnail(for data: Data, key: String) -> UIImage? {
        if let cached = cache.object(forKey: key as NSString) { return cached }
        guard let original = UIImage(data: data) else { return nil }
        let thumb = original.resized(toFit: 240)
        cache.setObject(thumb, forKey: key as NSString)
        return thumb
    }
}

private extension UIImage {
    func resized(toFit maxSide: CGFloat) -> UIImage {
        let scale = min(maxSide / size.width, maxSide / size.height)
        guard scale < 1 else { return self }
        let newSize = CGSize(width: (size.width * scale).rounded(),
                             height: (size.height * scale).rounded())
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Hakedis Comparison

struct HakedisComparisonView: View {
    let contract: Contract
    @State private var hakedis1: Hakedis?
    @State private var hakedis2: Hakedis?

    var sorted: [Hakedis] { contract.hakedisler.sorted { $0.createdAt < $1.createdAt } }

    var body: some View {
        List {
            Section("Dönem Seçimi") {
                Picker("1. Dönem", selection: $hakedis1) {
                    Text("Seçiniz").tag(Optional<Hakedis>.none)
                    ForEach(sorted) { h in Text(h.periodName).tag(Optional(h)) }
                }
                Picker("2. Dönem", selection: $hakedis2) {
                    Text("Seçiniz").tag(Optional<Hakedis>.none)
                    ForEach(sorted) { h in Text(h.periodName).tag(Optional(h)) }
                }
            }

            if let h1 = hakedis1, let h2 = hakedis2 {
                // Financial comparison
                Section("Finansal Karşılaştırma") {
                    ComparisonRow(label: "Brüt Tutar",
                                  val1: h1.grossAmount.currencyFormatted,
                                  val2: h2.grossAmount.currencyFormatted,
                                  diff: h2.grossAmount - h1.grossAmount)
                    ComparisonRow(label: "Teminat Kesintisi",
                                  val1: h1.retentionAmount.currencyFormatted,
                                  val2: h2.retentionAmount.currencyFormatted,
                                  diff: h2.retentionAmount - h1.retentionAmount)
                    ComparisonRow(label: "Net Tutar",
                                  val1: h1.netAmount.currencyFormatted,
                                  val2: h2.netAmount.currencyFormatted,
                                  diff: h2.netAmount - h1.netAmount)
                    ComparisonRow(label: "Ödenen",
                                  val1: h1.totalPaid.currencyFormatted,
                                  val2: h2.totalPaid.currencyFormatted,
                                  diff: h2.totalPaid - h1.totalPaid)
                }

                // Summary stats
                Section("Özet") {
                    let growth = h1.netAmount > 0
                        ? ((h2.netAmount - h1.netAmount) / h1.netAmount) * 100 : 0
                    HStack {
                        Text("Dönemsel Büyüme"); Spacer()
                        Text("\(growth >= 0 ? "+" : "")\(growth.percentFormatted)")
                            .bold()
                            .foregroundColor(growth >= 0 ? .hakedisSuccess : .hakedisDanger)
                    }
                    let itemCount1 = h1.items.count
                    let itemCount2 = h2.items.count
                    HStack {
                        Text("İş Kalemi Sayısı"); Spacer()
                        Text("\(itemCount1)  →  \(itemCount2)")
                            .font(.subheadline.bold())
                            .foregroundColor(itemCount2 >= itemCount1 ? .hakedisSuccess : .hakedisDanger)
                    }
                    // Cumulative totals
                    let cumul1 = h1.items.reduce(0.0) { $0 + $1.cumulativeAmount }
                    let cumul2 = h2.items.reduce(0.0) { $0 + $1.cumulativeAmount }
                    ComparisonRow(label: "Kümülatif Toplam",
                                  val1: cumul1.currencyFormatted,
                                  val2: cumul2.currencyFormatted,
                                  diff: cumul2 - cumul1)
                }

                // Work item level
                Section("İş Kalemleri") {
                    let codes = Set(h1.items.map { $0.workItemCode }
                                  + h2.items.map { $0.workItemCode })
                    ForEach(Array(codes).sorted(), id: \.self) { code in
                        WorkItemComparisonRow(
                            code: code,
                            item1: h1.items.first { $0.workItemCode == code },
                            item2: h2.items.first { $0.workItemCode == code }
                        )
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
    let label: String; let val1: String; let val2: String; let diff: Double
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
            Text("\(diff >= 0 ? "+" : "")\(diff.currencyFormatted)")
                .font(.caption.bold())
                .foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger)
        }
        .padding(.vertical, 2)
    }
}

struct WorkItemComparisonRow: View {
    let code: String; let item1: HakedisItem?; let item2: HakedisItem?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("[\(code)] \(item1?.workItemName ?? item2?.workItemName ?? "")")
                .font(.subheadline.bold())
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("1. Dönem").font(.caption2).foregroundColor(.secondary)
                    if let i1 = item1 {
                        Text("\(i1.currentQuantity.quantityFormatted) \(i1.unit)").font(.caption)
                        Text(i1.periodAmount.currencyFormatted)
                            .font(.caption.bold()).foregroundColor(.hakedisOrange)
                    } else { Text("—").font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
                if let i1 = item1, let i2 = item2 {
                    let diff = i2.periodAmount - i1.periodAmount
                    Image(systemName: diff >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(diff >= 0 ? .hakedisSuccess : .hakedisDanger)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("2. Dönem").font(.caption2).foregroundColor(.secondary)
                    if let i2 = item2 {
                        Text("\(i2.currentQuantity.quantityFormatted) \(i2.unit)").font(.caption)
                        Text(i2.periodAmount.currencyFormatted)
                            .font(.caption.bold()).foregroundColor(.hakedisOrange)
                    } else { Text("—").font(.caption).foregroundColor(.secondary) }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Photo Gallery

struct PhotoGalleryView: View {
    @Query(sort: \DailyEntry.date, order: .reverse) private var entries: [DailyEntry]
    @Query private var contracts: [Contract]

    @State private var selectedItem: PhotoItem?
    @State private var selectedContract: Contract?

    private var entriesWithPhotos: [DailyEntry] {
        let base = entries.filter { !$0.photoData.isEmpty }
        if let contract = selectedContract {
            return base.filter { $0.workItem?.contract?.id == contract.id }
        }
        return base
    }

    private var totalPhotos: Int { entriesWithPhotos.reduce(0) { $0 + $1.photoData.count } }
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                // Filter bar
                if !contracts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "Tümü", isSelected: selectedContract == nil) {
                                selectedContract = nil
                            }
                            ForEach(contracts) { c in
                                FilterChip(title: c.title, isSelected: selectedContract?.id == c.id) {
                                    selectedContract = (selectedContract?.id == c.id) ? nil : c
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }

                if entriesWithPhotos.isEmpty {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: "Fotoğraf yok",
                        subtitle: selectedContract == nil
                            ? "Saha girişlerinde fotoğraf ekleyince burada görünür"
                            : "Bu sözleşmede fotoğraflı giriş bulunamadı"
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(entriesWithPhotos) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.workItem?.name ?? "—")
                                            .font(.subheadline.bold())
                                        Text(entry.date.shortFormatted)
                                            .font(.caption).foregroundColor(.secondary)
                                        if let contractTitle = entry.workItem?.contract?.title {
                                            Text(contractTitle)
                                                .font(.caption2).foregroundColor(.hakedisOrange)
                                        }
                                        if !entry.location.isEmpty {
                                            Text(entry.location)
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("\(entry.photoData.count) fotoğraf")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.horizontal)

                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(entry.photoData.indices, id: \.self) { idx in
                                        let cacheKey = "\(entry.id.uuidString)_\(idx)"
                                        if let ui = ThumbnailCache.shared.thumbnail(
                                            for: entry.photoData[idx], key: cacheKey
                                        ) {
                                            Image(uiImage: ui)
                                                .resizable().scaledToFill()
                                                .frame(height: 120).clipped()
                                                .onTapGesture {
                                                    selectedItem = PhotoItem(
                                                        data: entry.photoData[idx],
                                                        entry: entry,
                                                        index: idx,
                                                        total: entry.photoData.count
                                                    )
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(totalPhotos) fotoğraf")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .sheet(item: $selectedItem) { item in PhotoDetailView(item: item) }
        }
    }
}

// MARK: - Photo Model

struct PhotoItem: Identifiable {
    let id = UUID()
    let data: Data
    let entry: DailyEntry
    let index: Int
    let total: Int
}

// MARK: - Photo Detail (with zoom + share)

struct PhotoDetailView: View {
    let item: PhotoItem
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let ui = UIImage(data: item.data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        scale = max(1, min(lastScale * val, 5))
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    scale = scale > 1 ? 1 : 2.5
                                    lastScale = scale
                                }
                            }
                            .animation(.interactiveSpring(), value: scale)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Metadata card
                VStack(alignment: .leading, spacing: 8) {
                    if let w = item.entry.workItem {
                        LabeledContent("İş Kalemi", value: w.name)
                        LabeledContent("Taşeron",   value: w.contract?.contractor?.name ?? "—")
                    }
                    LabeledContent("Tarih", value: item.entry.date.shortFormatted)
                    if item.total > 1 {
                        LabeledContent("Fotoğraf", value: "\(item.index + 1) / \(item.total)")
                    }
                    if !item.entry.location.isEmpty {
                        LabeledContent("Mahal", value: item.entry.location)
                    }
                    if !item.entry.notes.isEmpty {
                        LabeledContent("Not", value: item.entry.notes)
                    }
                }
                .font(.subheadline)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Fotoğraf")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $isSharing) {
                if let ui = UIImage(data: item.data) {
                    ShareSheet(items: [ui])
                }
            }
        }
    }
}
