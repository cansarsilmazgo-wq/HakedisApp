import SwiftUI
import SwiftData

// MARK: - EquipmentCostAnalysisView
struct EquipmentCostAnalysisView: View {
    @Query(sort: \EquipmentItem.name) private var equipment: [EquipmentItem]

    private var totalFuelCost: Double { equipment.reduce(0) { $0 + $1.totalFuelCost } }
    private var totalRepairCost: Double { equipment.reduce(0) { $0 + $1.totalRepairCost } }
    private var totalOperatingCost: Double { equipment.reduce(0) { $0 + $1.totalOperatingCost } }
    private var sortedByCost: [EquipmentItem] {
        equipment.sorted { $0.totalOperatingCost > $1.totalOperatingCost }
    }

    var body: some View {
        List {
            summarySection
            rentalVsOwnSection
            topCostSection
            fuelOverconsumptionSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ekipman Maliyet Analizi")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var summarySection: some View {
        Section("Genel Özet") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCard(title: "Toplam Yakıt", value: totalFuelCost.currencyFormatted, color: .hakedisWarning, icon: "fuelpump")
                StatCard(title: "Toplam Tamir", value: totalRepairCost.currencyFormatted, color: .hakedisDanger, icon: "wrench.fill")
                StatCard(title: "Toplam Maliyet", value: totalOperatingCost.currencyFormatted, color: .hakedisOrange, icon: "turkishlirasign.circle")
                StatCard(title: "Ekipman Sayısı", value: "\(equipment.count)", color: .hakedisInfo, icon: "gearshape.2")
            }
        }
    }

    @ViewBuilder private var rentalVsOwnSection: some View {
        Section("Kiralık vs Öz Mal") {
            let ownedItems = equipment.filter { $0.ownershipType == .owned }
            let rentedItems = equipment.filter { $0.ownershipType == .rented }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Öz Mal").font(.caption.bold())
                    Text("\(ownedItems.count) ekipman").font(.caption2).foregroundColor(.secondary)
                    let ownedCost = ownedItems.reduce(0.0) { $0 + $1.totalOperatingCost + $1.monthlyDepreciation }
                    Text(ownedCost.currencyFormatted).font(.caption).foregroundColor(.hakedisOrange)
                    Text("(+amortisman)").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Kiralık").font(.caption.bold())
                    Text("\(rentedItems.count) ekipman").font(.caption2).foregroundColor(.secondary)
                    let rentedCost = rentedItems.reduce(0.0) { $0 + $1.monthlyCost }
                    Text(rentedCost.currencyFormatted).font(.caption).foregroundColor(.hakedisInfo)
                    Text("(+yakıt)").font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private var topCostSection: some View {
        Section("En Pahalı Ekipmanlar") {
            if sortedByCost.isEmpty {
                Text("Maliyet verisi yok").font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(sortedByCost.prefix(5), id: \.id) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline.bold())
                            Text("\(String(format: "%.0f", item.totalOperatingHours)) saat çalışma")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.totalOperatingCost.currencyFormatted).font(.caption.bold())
                            if item.totalOperatingHours > 0 {
                                Text("\(item.costPerHour.currencyFormatted)/saat")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.name), \(item.totalOperatingCost.currencyFormatted)")
                }
            }
        }
    }

    @ViewBuilder private var fuelOverconsumptionSection: some View {
        let overConsuming = equipment.filter { $0.isOverConsumption }
        if !overConsuming.isEmpty {
            Section("Yakıt Tüketim Uyarıları") {
                ForEach(overConsuming, id: \.id) { item in
                    HStack {
                        Image(systemName: "fuelpump.exclamationmark.fill").foregroundColor(.hakedisDanger)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.subheadline.bold())
                            if let baseline = item.hourlyFuelConsumption {
                                Text(String(format: "Hedef: %.1f lt/saat → Gerçek: %.1f lt/saat",
                                            baseline, item.averageFuelConsumption))
                                    .font(.caption2).foregroundColor(.hakedisDanger)
                            }
                        }
                        Spacer()
                        Text(String(format: "+%%%.0f",
                                    ((item.averageFuelConsumption / (item.hourlyFuelConsumption ?? 1)) - 1) * 100))
                            .font(.caption.bold()).foregroundColor(.hakedisDanger)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.name) yakıt tüketim aşımı")
                }
            }
        }
    }
}
