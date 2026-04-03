import SwiftUI
import SwiftData

struct SantiyeTabView: View {
    @State private var selectedSegment = 0
    private let segments = ["Saha", "Günlük", "Puantaj", "Malzeme", "Ekipman", "İSG", "Taşeronlar"]

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            // Segment picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(segments.indices, id: \.self) { i in
                        Button {
                            selectedSegment = i
                        } label: {
                            Text(segments[i])
                                .font(.subheadline.weight(selectedSegment == i ? .semibold : .regular))
                                .foregroundColor(selectedSegment == i ? .hakedisOrange : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 2)
                                        .foregroundColor(selectedSegment == i ? .hakedisOrange : .clear),
                                    alignment: .bottom
                                )
                        }
                        .accessibilityLabel(segments[i])
                        .accessibilityAddTraits(selectedSegment == i ? .isSelected : [])
                    }
                }
            }
            .background(Color.hakedisCard)

            Divider()

            // Her child view kendi NavigationStack'ini yönetiyor
            ZStack {
                switch selectedSegment {
                case 0:
                    DailyEntryListView()
                case 1:
                    SiteDiaryListView()
                case 2:
                    AttendanceListView()
                case 3:
                    MaterialListView()
                case 4:
                    EquipmentManagementListView()
                case 5:
                    SafetyListView()
                case 6:
                    ContractorListView()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Şantiye")
        .navigationBarTitleDisplayMode(.inline)
        }
    }
}
