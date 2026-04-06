import SwiftUI

// MARK: - DrawingAnnotationView

struct DrawingAnnotationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var strokes: [AnnotationStroke] = []
    @State private var currentPoints: [CGPoint] = []
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 3
    @State private var annotationText: String = ""
    @State private var showTextInput = false
    @State private var textPosition: CGPoint = CGPoint(x: 100, y: 100)
    @State private var textAnnotations: [TextAnnotation] = []
    @State private var renderedImage: UIImage? = nil
    @State private var showShareSheet = false

    private let palette: [Color] = [.red, .blue, .green, .orange, .black, .white]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toolbar
                HStack(spacing: 12) {
                    ForEach(palette, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(selectedColor == color ? Color.hakedisOrange : Color.clear, lineWidth: 2))
                            .onTapGesture { selectedColor = color }
                            .accessibilityLabel("\(colorName(color)) renk seç")
                    }
                    Divider().frame(height: 24)
                    Slider(value: $lineWidth, in: 1...12, step: 1)
                        .frame(width: 80)
                        .accessibilityLabel("Çizgi kalınlığı")
                    Divider().frame(height: 24)
                    Button {
                        showTextInput = true
                    } label: {
                        Image(systemName: "textformat")
                            .foregroundColor(.hakedisOrange)
                    }
                    .accessibilityLabel("Metin ekle")
                    Spacer()
                    Button {
                        if !strokes.isEmpty { strokes.removeLast() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(.secondary)
                    }
                    .disabled(strokes.isEmpty)
                    .accessibilityLabel("Geri al")
                    Button {
                        strokes.removeAll()
                        textAnnotations.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.hakedisDanger)
                    }
                    .disabled(strokes.isEmpty && textAnnotations.isEmpty)
                    .accessibilityLabel("Tümünü temizle")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.secondarySystemGroupedBackground))

                Divider()

                // Canvas
                GeometryReader { geo in
                    ZStack {
                        // Background grid
                        Color.white
                        AnnotationCanvas(
                            strokes: strokes,
                            currentPoints: currentPoints,
                            currentColor: selectedColor,
                            lineWidth: lineWidth
                        )
                        // Text annotations
                        ForEach(textAnnotations) { ann in
                            Text(ann.text)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ann.color)
                                .padding(4)
                                .background(Color.white.opacity(0.7))
                                .position(ann.position)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                currentPoints.append(value.location)
                            }
                            .onEnded { _ in
                                if !currentPoints.isEmpty {
                                    strokes.append(AnnotationStroke(
                                        points: currentPoints,
                                        color: selectedColor,
                                        lineWidth: lineWidth
                                    ))
                                    currentPoints = []
                                }
                            }
                    )
                    .clipped()
                }
            }
            .navigationTitle("Çizim Anotasyonu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        renderAndShare()
                    } label: {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                    .disabled(strokes.isEmpty && textAnnotations.isEmpty)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = renderedImage {
                    ShareSheet(items: [img])
                }
            }
            .alert("Metin Ekle", isPresented: $showTextInput) {
                TextField("Metin girin", text: $annotationText)
                Button("Ekle") {
                    if !annotationText.isEmpty {
                        textAnnotations.append(TextAnnotation(
                            text: annotationText,
                            position: textPosition,
                            color: selectedColor
                        ))
                        annotationText = ""
                        textPosition.x += 20
                        textPosition.y += 20
                    }
                }
                Button("İptal", role: .cancel) { annotationText = "" }
            } message: {
                Text("Tuval üzerine metin anotasyonu ekleyin")
            }
        }
    }

    private func colorName(_ color: Color) -> String {
        switch color {
        case .red: return "Kırmızı"
        case .blue: return "Mavi"
        case .green: return "Yeşil"
        case .orange: return "Turuncu"
        case .black: return "Siyah"
        case .white: return "Beyaz"
        default: return "Renk"
        }
    }

    private func renderAndShare() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 600))
        renderedImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 600))
            for stroke in strokes {
                guard stroke.points.count > 1 else { continue }
                let path = UIBezierPath()
                path.move(to: stroke.points[0])
                for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
                UIColor(stroke.color).setStroke()
                path.lineWidth = stroke.lineWidth
                path.stroke()
            }
        }
        showShareSheet = true
    }
}

// MARK: - AnnotationCanvas

private struct AnnotationCanvas: View {
    let strokes: [AnnotationStroke]
    let currentPoints: [CGPoint]
    let currentColor: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, _ in
            for stroke in strokes {
                guard stroke.points.count > 1 else { continue }
                var path = Path()
                path.move(to: stroke.points[0])
                for pt in stroke.points.dropFirst() { path.addLine(to: pt) }
                context.stroke(path, with: .color(stroke.color),
                               style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
            }
            if currentPoints.count > 1 {
                var path = Path()
                path.move(to: currentPoints[0])
                for pt in currentPoints.dropFirst() { path.addLine(to: pt) }
                context.stroke(path, with: .color(currentColor),
                               style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Models

private struct AnnotationStroke: Identifiable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}

private struct TextAnnotation: Identifiable {
    let id = UUID()
    let text: String
    let position: CGPoint
    let color: Color
}
