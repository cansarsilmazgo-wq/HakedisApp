import SwiftUI
import SwiftData
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QRCodeManager

class QRCodeManager {
    static func generateQRCode(for workerId: UUID) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = workerId.uuidString.data(using: .utf8)!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func workerID(from qrString: String) -> UUID? {
        UUID(uuidString: qrString)
    }
}

// MARK: - WorkerQRCodeView

struct WorkerQRCodeView: View {
    let worker: Worker
    @State private var qrImage: UIImage?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
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
                }

                VStack(spacing: Spacing.xs) {
                    Text(worker.fullName)
                        .font(.title2.bold())
                    Text(worker.profession.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let sgk = worker.sgkSicilNo {
                        Text("SGK Sicil: \(sgk)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: Spacing.md) {
                    Button {
                        shareQRCard()
                    } label: {
                        Label("Kart Yazdır", systemImage: "printer.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.hakedisOrange)
                    .accessibilityLabel("QR Kart Yazdır")
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(Spacing.section)
            .background(Color.hakedisBackground)
            .navigationTitle("QR Kimlik Kartı")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { generateAndCache() }
        }
    }

    private func generateAndCache() {
        if let cached = worker.qrCodeData, let img = UIImage(data: cached) {
            qrImage = img
            return
        }
        if let img = QRCodeManager.generateQRCode(for: worker.id) {
            qrImage = img
            worker.qrCodeData = img.pngData()
            do { try modelContext.save() } catch { }
        }
    }

    private func shareQRCard() {
        guard let qrImage else { return }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 500))
        let cardImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 500))
            qrImage.draw(in: CGRect(x: 100, y: 40, width: 200, height: 200))
            let nameAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.black
            ]
            let name = worker.fullName as NSString
            name.draw(at: CGPoint(x: 40, y: 270), withAttributes: nameAttr)
            let roleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.gray
            ]
            let role = worker.profession.rawValue as NSString
            role.draw(at: CGPoint(x: 40, y: 306), withAttributes: roleAttr)
        }

        let av = UIActivityViewController(activityItems: [cardImage], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - QRScannerView

struct QRScannerView: View {
    @Query private var workers: [Worker]
    @Query private var attendances: [Attendance]
    @State private var scannedWorker: Worker?
    @State private var scanMode: ScanMode = .entry
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var resultSuccess = true
    @State private var isScanning = true
    @Environment(\.modelContext) private var modelContext

    enum ScanMode: String, CaseIterable {
        case entry = "Giriş"
        case exit  = "Çıkış"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Giriş/Çıkış seçimi
                Picker("Mod", selection: $scanMode) {
                    ForEach(ScanMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                // Kamera görünümü
                ZStack {
                    QRCameraPreview(onQRDetected: { code in
                        guard isScanning else { return }
                        isScanning = false
                        processQRCode(code)
                    })
                    .frame(maxWidth: .infinity, maxHeight: 340)
                    .cornerRadius(12)
                    .padding(.horizontal, Spacing.md)

                    // Tarama çerçevesi
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.hakedisOrange, lineWidth: 3)
                        .frame(width: 220, height: 220)

                    VStack {
                        Spacer()
                        Text("QR Kodu tarama alanına tutun")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                    }
                }
                .frame(height: 360)

                if showResult {
                    resultCard
                }

                Spacer()
            }
            .background(Color.hakedisBackground)
            .navigationTitle("QR Yoklama")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var resultCard: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: resultSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(resultSuccess ? .hakedisSuccess : .hakedisDanger)

            if let worker = scannedWorker {
                Text(worker.fullName)
                    .font(.title3.bold())
                Text(worker.profession.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(resultMessage)
                .font(.subheadline)
                .foregroundColor(resultSuccess ? .hakedisSuccess : .hakedisDanger)
                .multilineTextAlignment(.center)

            Button("Tekrar Tara") {
                showResult = false
                scannedWorker = nil
                isScanning = true
            }
            .foregroundColor(.hakedisOrange)
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.card)
        .background(Color.hakedisCard)
        .cornerRadius(12)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    private func processQRCode(_ code: String) {
        guard let uuid = QRCodeManager.workerID(from: code) else {
            DispatchQueue.main.async {
                resultMessage = "Bilinmeyen QR kod"
                resultSuccess = false
                showResult = true
            }
            return
        }

        guard let worker = workers.first(where: { $0.id == uuid }) else {
            DispatchQueue.main.async {
                resultMessage = "İşçi bulunamadı"
                resultSuccess = false
                showResult = true
            }
            return
        }

        let calendar = Calendar.current
        let today = Date()
        let todayAttendances = attendances.filter {
            $0.worker?.id == worker.id && calendar.isDateInToday($0.date)
        }

        if scanMode == .entry {
            if let existing = todayAttendances.first, existing.isPresent {
                DispatchQueue.main.async {
                    scannedWorker = worker
                    resultMessage = "Zaten giriş yapmış"
                    resultSuccess = false
                    showResult = true
                }
                return
            }
            let attendance = Attendance(date: today, workerName: worker.fullName)
            attendance.worker = worker
            attendance.isPresent = true
            attendance.normalHours = 8.0
            modelContext.insert(attendance)
            do { try modelContext.save() } catch { }

            DispatchQueue.main.async {
                scannedWorker = worker
                resultMessage = "Giriş Kaydedildi ✅\n\(today.formatted(date: .omitted, time: .shortened))"
                resultSuccess = true
                showResult = true
            }
        } else {
            // Çıkış
            if let attendance = todayAttendances.first {
                let hours = today.timeIntervalSince(attendance.date) / 3600
                attendance.normalHours = min(8, hours)
                do { try modelContext.save() } catch { }

                DispatchQueue.main.async {
                    scannedWorker = worker
                    resultMessage = "Çıkış Kaydedildi ✅\n\(String(format: "%.1f saat", hours))"
                    resultSuccess = true
                    showResult = true
                }
            } else {
                DispatchQueue.main.async {
                    scannedWorker = worker
                    resultMessage = "Giriş kaydı bulunamadı"
                    resultSuccess = false
                    showResult = true
                }
            }
        }
    }
}

// MARK: - QRCameraPreview (AVCaptureSession wrapper)

struct QRCameraPreview: UIViewRepresentable {
    let onQRDetected: (String) -> Void

    func makeUIView(context: Context) -> QRCameraView {
        let view = QRCameraView()
        view.onQRDetected = onQRDetected
        return view
    }

    func updateUIView(_ uiView: QRCameraView, context: Context) {}
}

class QRCameraView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    var onQRDetected: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    private func setupCamera() {
        let session = AVCaptureSession()
        captureSession = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        session.addInput(input)

        let metadataOutput = AVCaptureMetadataOutput()
        session.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                         didOutput metadataObjects: [AVMetadataObject],
                         from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = obj.stringValue else { return }
        onQRDetected?(string)
    }
}

// MARK: - AttendanceQRListView

struct AttendanceQRListView: View {
    @Query private var workers: [Worker]
    @Query private var attendances: [Attendance]
    @State private var showQRScanner = false

    private var todayAttendances: [Attendance] {
        attendances.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var presentWorkerIDs: Set<UUID> {
        Set(todayAttendances.compactMap { $0.worker?.id })
    }

    private var absentWorkers: [Worker] {
        workers.filter { $0.isActive && !presentWorkerIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Bugün Giriş Yapanlar (\(todayAttendances.count))") {
                    if todayAttendances.isEmpty {
                        Text("Henüz giriş yok.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(todayAttendances, id: \.id) { att in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.hakedisSuccess)
                                VStack(alignment: .leading) {
                                    Text(att.effectiveName)
                                        .font(.subheadline)
                                    Text(att.date.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(att.totalHours, specifier: "%.1f") sa")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("Henüz Giriş Yapmamışlar (\(absentWorkers.count))") {
                    if absentWorkers.isEmpty {
                        Text("Tüm işçiler giriş yaptı.")
                            .foregroundColor(.hakedisSuccess)
                    } else {
                        ForEach(absentWorkers, id: \.id) { worker in
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.secondary)
                                Text(worker.fullName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(worker.profession.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("QR Yoklama Listesi")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showQRScanner = true
                    } label: {
                        Label("QR Tara", systemImage: "qrcode.viewfinder")
                    }
                    .accessibilityLabel("QR Yoklama Tara")
                }
            }
            .sheet(isPresented: $showQRScanner) {
                QRScannerView()
            }
        }
    }
}
