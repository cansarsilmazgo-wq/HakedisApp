import SwiftUI
import SwiftData
import AVFoundation

// MARK: - MaterialQRDisplayView

struct MaterialQRDisplayView: View {
    let material: Material
    @Environment(\.modelContext) private var modelContext
    @State private var qrImage: UIImage?
    @State private var labelImage: UIImage?
    @State private var showingShareQR = false
    @State private var showingShareLabel = false
    @State private var shareItems: [Any] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.section) {
                    if let image = qrImage {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                            .padding(Spacing.card)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 4)
                            .accessibilityLabel("\(material.name) QR kodu")
                    } else {
                        ProgressView()
                            .frame(width: 240, height: 240)
                    }

                    VStack(spacing: Spacing.xs) {
                        Text(material.name)
                            .font(.title2.bold())
                        Text("Birim: \(material.unit)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(String(format: "Mevcut Stok: %.2f \(material.unit)", material.currentStock))
                            .font(.caption)
                            .foregroundColor(material.isLowStock ? .hakedisDanger : .hakedisSuccess)
                    }

                    VStack(spacing: Spacing.xs) {
                        Button {
                            if let label = labelImage {
                                shareItems = [label]
                                showingShareLabel = true
                            }
                        } label: {
                            Label("Etiket Paylaş", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.hakedisOrange)
                        .accessibilityLabel("Malzeme etiketini paylaş")

                        Button {
                            if let qr = qrImage {
                                shareItems = [qr]
                                showingShareQR = true
                            }
                        } label: {
                            Label("QR Kod Paylaş", systemImage: "qrcode")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.hakedisInfo)
                        .accessibilityLabel("QR kodu paylaş")
                    }
                    .padding(.horizontal, Spacing.md)
                }
                .padding(Spacing.section)
            }
            .background(Color.hakedisBackground)
            .navigationTitle("QR Etiket")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { generateImages() }
            .sheet(isPresented: $showingShareQR) {
                ShareSheet(items: shareItems)
            }
            .sheet(isPresented: $showingShareLabel) {
                ShareSheet(items: shareItems)
            }
        }
    }

    private func generateImages() {
        if let cached = material.qrCodeData, let img = UIImage(data: cached) {
            qrImage = img
        } else if let img = MaterialQRCodeManager.generateQRCode(for: material) {
            qrImage = img
            material.qrCodeData = img.pngData()
            do { try modelContext.save() } catch { }
        }
        labelImage = MaterialQRCodeManager.generateQRLabel(for: material)
    }
}

// MARK: - MaterialQRScannerView

struct MaterialQRScannerView: View {
    @Query private var materials: [Material]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var foundMaterial: Material?
    @State private var entryType: StockEntryType = .incoming
    @State private var quantity: String = ""
    @State private var supplierName: String = ""
    @State private var isScanning = true
    @State private var showResult = false
    @State private var toastMessage = ""
    @State private var toastSuccess = true
    @State private var showingToast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Giriş/Çıkış", selection: $entryType) {
                    Text("Giriş").tag(StockEntryType.incoming)
                    Text("Çıkış").tag(StockEntryType.outgoing)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                ZStack {
                    QRCameraPreview(onQRDetected: { code in
                        guard isScanning else { return }
                        isScanning = false
                        processQRCode(code)
                    })
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .cornerRadius(12)
                    .padding(.horizontal, Spacing.md)

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.hakedisOrange, lineWidth: 3)
                        .frame(width: 200, height: 200)

                    VStack {
                        Spacer()
                        Text("Malzeme QR kodunu tarayın")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                }
                .frame(height: 320)

                if let material = foundMaterial {
                    materialForm(material)
                } else if showResult {
                    EmptyStateView(
                        icon: "qrcode.viewfinder",
                        title: "Malzeme bulunamadı",
                        subtitle: "Bu QR kodu tanınmıyor"
                    )
                    .padding()
                }

                Spacer()
            }
            .background(Color.hakedisBackground)
            .navigationTitle("Malzeme QR Tarama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .overlay(alignment: .top) {
                if showingToast {
                    Text(toastMessage)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(toastSuccess ? Color.hakedisSuccess : Color.hakedisDanger)
                        .cornerRadius(12)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingToast)
        }
    }

    @ViewBuilder
    private func materialForm(_ material: Material) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.name).font(.headline)
                    Text("Mevcut Stok: \(material.currentStock.quantityFormatted) \(material.unit)")
                        .font(.caption)
                        .foregroundColor(material.isLowStock ? .hakedisDanger : .secondary)
                }
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.hakedisSuccess)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)

            Group {
                HStack {
                    Text("Miktar")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("0.00", text: $quantity)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    Text(material.unit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if entryType == .incoming {
                    HStack {
                        Text("Tedarikçi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("İsteğe bağlı", text: $supplierName)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)

            Button {
                saveEntry(for: material)
            } label: {
                Label(
                    entryType == .incoming ? "Giriş Kaydet" : "Çıkış Kaydet",
                    systemImage: entryType == .incoming ? "arrow.down.circle.fill" : "arrow.up.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(entryType == .incoming ? .hakedisSuccess : .hakedisWarning)
            .padding(.horizontal, Spacing.md)
            .accessibilityLabel(entryType == .incoming ? "Stok girişi kaydet" : "Stok çıkışı kaydet")

            Button {
                foundMaterial = nil
                quantity = ""
                supplierName = ""
                isScanning = true
                showResult = false
            } label: {
                Text("Tekrar Tara")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xs)
        }
        .background(Color.hakedisCard)
        .cornerRadius(12)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
    }

    private func processQRCode(_ code: String) {
        guard let uuid = MaterialQRCodeManager.materialID(from: code),
              let material = materials.first(where: { $0.id == uuid }) else {
            DispatchQueue.main.async {
                showResult = true
                isScanning = false
            }
            return
        }
        DispatchQueue.main.async {
            foundMaterial = material
            showResult = true
        }
    }

    private func saveEntry(for material: Material) {
        guard let qty = Double(quantity.replacingOccurrences(of: ",", with: ".")), qty > 0 else {
            showToast("Geçerli bir miktar girin", success: false)
            return
        }
        let entry = StockEntry(date: Date(), entryType: entryType, quantity: qty)
        if !supplierName.isEmpty { entry.supplierName = supplierName }
        entry.material = material

        if entryType == .incoming {
            material.currentStock += qty
        } else {
            if material.currentStock < qty {
                showToast("Yetersiz stok!", success: false)
                return
            }
            material.currentStock -= qty
        }
        modelContext.insert(entry)
        do {
            try modelContext.save()
            showToast("\(entryType == .incoming ? "Giriş" : "Çıkış") kaydedildi ✓", success: true)
            quantity = ""
            supplierName = ""
            foundMaterial = nil
            isScanning = true
            showResult = false
        } catch {
            showToast("Kayıt başarısız: \(error.localizedDescription)", success: false)
        }
    }

    private func showToast(_ message: String, success: Bool) {
        toastMessage = message
        toastSuccess = success
        withAnimation { showingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showingToast = false }
        }
    }
}

// MARK: - MaterialQRLabelPDFGenerator

struct MaterialQRLabelPDFGenerator {
    static func generateBulkLabelPDF(materials: [Material]) -> Data {
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let cols = 4
        let rows = 5
        let labelsPerPage = cols * rows
        let margin: CGFloat = 20
        let cellWidth = (pageWidth - margin * 2) / CGFloat(cols)
        let cellHeight = (pageHeight - margin * 2) / CGFloat(rows)

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        return renderer.pdfData { ctx in
            var index = 0
            while index < materials.count {
                ctx.beginPage()

                let pageItems = min(labelsPerPage, materials.count - index)
                for i in 0..<pageItems {
                    let col = i % cols
                    let row = i / cols
                    let x = margin + CGFloat(col) * cellWidth
                    let y = margin + CGFloat(row) * cellHeight
                    let material = materials[index + i]

                    drawLabel(
                        material: material,
                        rect: CGRect(x: x, y: y, width: cellWidth, height: cellHeight),
                        context: ctx.cgContext
                    )
                }
                index += labelsPerPage
            }
        }
    }

    private static func drawLabel(material: Material, rect: CGRect, context: CGContext) {
        // Border
        context.setStrokeColor(UIColor.systemGray4.cgColor)
        context.setLineWidth(0.5)
        context.stroke(rect.insetBy(dx: 4, dy: 4))

        let padding: CGFloat = 8
        let inner = rect.insetBy(dx: padding, dy: padding)

        // QR code
        if let qr = MaterialQRCodeManager.generateQRCode(for: material),
           let cgQR = qr.cgImage {
            let qrSize: CGFloat = min(inner.width, inner.height * 0.6)
            let qrRect = CGRect(
                x: inner.midX - qrSize / 2,
                y: inner.minY,
                width: qrSize,
                height: qrSize
            )
            context.saveGState()
            context.translateBy(x: qrRect.minX, y: qrRect.minY + qrRect.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(cgQR, in: CGRect(origin: .zero, size: qrRect.size))
            context.restoreGState()
        }

        // Text labels
        let nameFont = UIFont.boldSystemFont(ofSize: 8)
        let captionFont = UIFont.systemFont(ofSize: 6)
        let textY = inner.minY + inner.height * 0.62

        let nameStr = material.name as NSString
        nameStr.draw(
            in: CGRect(x: inner.minX, y: textY, width: inner.width, height: 14),
            withAttributes: [.font: nameFont, .foregroundColor: UIColor.black]
        )
        let unitStr = "Birim: \(material.unit)" as NSString
        unitStr.draw(
            at: CGPoint(x: inner.minX, y: textY + 14),
            withAttributes: [.font: captionFont, .foregroundColor: UIColor.darkGray]
        )
        let stockStr = String(format: "Stok: %.2f \(material.unit)", material.currentStock) as NSString
        stockStr.draw(
            at: CGPoint(x: inner.minX, y: textY + 22),
            withAttributes: [.font: captionFont, .foregroundColor: UIColor.gray]
        )
    }
}
