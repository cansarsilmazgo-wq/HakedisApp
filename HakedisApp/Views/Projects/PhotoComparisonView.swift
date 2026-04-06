import SwiftUI
import SwiftData

// MARK: - PhotoComparisonView

struct PhotoComparisonView: View {
    @Query(sort: \SiteDiary.date, order: .forward) private var allDiaries: [SiteDiary]
    @State private var leftIndex: Int = 0
    @State private var rightIndex: Int = 0
    @State private var selectedProject: Project? = nil

    private var filteredDiaries: [SiteDiary] {
        guard let project = selectedProject else { return allDiaries }
        return allDiaries.filter { $0.project?.id == project.id }
    }

    private var diariesWithPhotos: [SiteDiary] {
        filteredDiaries.filter { !$0.photoData.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if diariesWithPhotos.isEmpty {
                    EmptyStateView(
                        icon: "photo.stack",
                        title: "Fotoğraf bulunamadı",
                        subtitle: "Fotoğraf içeren şantiye günlüğü girişi bulunmuyor",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    comparisonContent
                }
            }
            .navigationTitle("Fotoğraf Karşılaştırma")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var comparisonContent: some View {
        VStack(spacing: 0) {
            // Date pickers
            HStack(spacing: 12) {
                DatePickerColumn(
                    label: "Sol",
                    diaries: diariesWithPhotos,
                    selectedIndex: $leftIndex
                )
                Divider().frame(height: 44)
                DatePickerColumn(
                    label: "Sağ",
                    diaries: diariesWithPhotos,
                    selectedIndex: $rightIndex
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.secondarySystemGroupedBackground))

            Divider()

            // Side-by-side photos
            GeometryReader { geo in
                HStack(spacing: 1) {
                    PhotoPane(diary: diariesWithPhotos[safe: leftIndex])
                        .frame(width: (geo.size.width - 1) / 2)
                    PhotoPane(diary: diariesWithPhotos[safe: rightIndex])
                        .frame(width: (geo.size.width - 1) / 2)
                }
            }
        }
    }
}

// MARK: - DatePickerColumn

private struct DatePickerColumn: View {
    let label: String
    let diaries: [SiteDiary]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Picker(label, selection: $selectedIndex) {
                ForEach(diaries.indices, id: \.self) { i in
                    Text(diaries[i].date.shortFormatted)
                        .tag(i)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(label) tarih seç")
    }
}

// MARK: - PhotoPane

private struct PhotoPane: View {
    let diary: SiteDiary?

    var body: some View {
        if let diary, let imageData = diary.photoData.first, let uiImage = UIImage(data: imageData) {
            VStack(spacing: 0) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .accessibilityLabel("Fotoğraf: \(diary.date.shortFormatted)")
                HStack {
                    Text(diary.date.shortFormatted)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(diary.photoData.count) fotoğraf")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(6)
                .background(Color.black.opacity(0.5))
            }
        } else {
            ZStack {
                Color(UIColor.secondarySystemGroupedBackground)
                VStack(spacing: 6) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Fotoğraf yok")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Safe Index Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
