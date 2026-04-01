import SwiftUI

struct PozLibraryView: View {
    let onSelect: (PozItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: PozCategory? = nil

    private var filtered: [PozItem] {
        PozLibrary.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.code.localizedCaseInsensitiveContains(searchText) ||
                item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(title: "Tümü", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(PozCategory.allCases, id: \.self) { cat in
                            CategoryChip(title: cat.rawValue, isSelected: selectedCategory == cat) {
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
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.code)
                                    .font(.caption.bold())
                                    .foregroundColor(.hakedisOrange)
                                    .frame(width: 60, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline).foregroundColor(.primary)
                                    Text(item.category.rawValue).font(.caption2).foregroundColor(.secondary)
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
        }
    }
}

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
