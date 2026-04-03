import SwiftUI
import SwiftData

struct FinansTabView: View {
    @State private var selectedSegment = 0
    @Query private var hakedisler: [Hakedis]
    private let segments = ["Hakediş", "Ödemeler", "Nakit Akış", "Fiyat Farkı", "Teminat"]

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
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

                ZStack {
                    switch selectedSegment {
                    case 0:
                        AllHakedisListView()
                    case 1:
                        AllPaymentsView()
                    case 2:
                        CashFlowView(hakedisler: hakedisler)
                    case 3:
                        PriceDifferenceListView()
                    case 4:
                        AllGuaranteeListView()
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Finans")
        .navigationBarTitleDisplayMode(.inline)
        }
    }
}
