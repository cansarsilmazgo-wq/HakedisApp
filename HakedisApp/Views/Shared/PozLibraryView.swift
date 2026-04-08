import SwiftUI
import SwiftData

struct PozLibraryView: View {
    let onSelect: (PozItem, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil

    @Query private var workItems: [WorkItem]
    @Query private var analyses: [UnitPriceAnalysis]

    // Seçili poz için fiyat onayı
    @State private var pendingPoz: PozItem? = nil
    @State private var showingPriceSuggestion = false

    private var filtered: [PozItem] {
        PozLibrary.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.code.localizedCaseInsensitiveContains(searchText) ||
                item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    private var allCategories: [String] { PozLibrary.allCategories }

    /// Verilen poz kodu için önerilen birim fiyat.
    /// Önce UnitPriceAnalysis'ten contractUnitPrice ortalaması,
    /// yoksa aynı kodlu WorkItem'ların unitPrice ortalaması.
    func suggestedPrice(for poz: PozItem) -> Double? {
        let analysisValues = analyses
            .filter { $0.workItemCode == poz.code && $0.contractUnitPrice > 0 }
            .map { $0.contractUnitPrice }
        if !analysisValues.isEmpty {
            return analysisValues.reduce(0, +) / Double(analysisValues.count)
        }
        let workItemValues = workItems
            .filter { $0.code == poz.code && $0.unitPrice > 0 }
            .map { $0.unitPrice }
        if !workItemValues.isEmpty {
            return workItemValues.reduce(0, +) / Double(workItemValues.count)
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "Tümü", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(allCategories, id: \.self) { cat in
                            CategoryChip(title: cat, isSelected: selectedCategory == cat) {
                                selectedCategory = (selectedCategory == cat) ? nil : cat
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.hakedisBackground)

                List {
                    ForEach(filtered, id: \.id) { item in
                        let suggestion = suggestedPrice(for: item)
                        Button {
                            if suggestion != nil {
                                pendingPoz = item
                                showingPriceSuggestion = true
                            } else {
                                onSelect(item, nil)
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.code)
                                    .font(.caption.bold())
                                    .foregroundColor(.hakedisOrange)
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline).foregroundColor(.primary)
                                    Text(item.category).font(.caption2).foregroundColor(.secondary)
                                    if let price = suggestion {
                                        Text("Önerilen fiyat: \(price.currencyFormatted)")
                                            .font(.caption2.bold())
                                            .foregroundColor(.hakedisSuccess)
                                    }
                                }
                                Spacer()
                                Text(item.unit)
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.hakedisBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Poz kodu veya adı ara...")
            .navigationTitle("Poz Kütüphanesi (\(filtered.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } }
            }
            .sheet(isPresented: $showingPriceSuggestion) {
                if let poz = pendingPoz {
                    PozPriceSuggestionSheet(
                        poz: poz,
                        suggestedPrice: suggestedPrice(for: poz) ?? 0
                    ) { accepted in
                        onSelect(poz, accepted ? suggestedPrice(for: poz) : nil)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Fiyat Öneri Sheet

struct PozPriceSuggestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let poz: PozItem
    let suggestedPrice: Double
    let onDecision: (Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "tag.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.hakedisSuccess)
                    Text("Fiyat Önerisi")
                        .font(.title2.bold())
                    Text(poz.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                VStack(spacing: 4) {
                    Text("Geçmiş verilerden hesaplanan ortalama:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(suggestedPrice.currencyFormatted)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.hakedisOrange)
                    Text("/ \(poz.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color.hakedisCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 12) {
                    Button {
                        onDecision(true)
                        dismiss()
                    } label: {
                        Label("Kabul Et", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.hakedisSuccess)

                    Button {
                        onDecision(false)
                        dismiss()
                    } label: {
                        Label("Reddet — Kendim Gireceğim", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Fiyat Önerisi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isSelected ? .white : .hakedisOrange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.hakedisOrange : Color.hakedisCard)
                .clipShape(Capsule())
        }
    }
}
