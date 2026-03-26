import SwiftUI
import UniformTypeIdentifiers

// MARK: - CSV Work Item Parser

struct CSVWorkItemRow {
    let code: String
    let name: String
    let unit: String
    let unitPrice: Double
    let contractedQuantity: Double
    let location: String
}

struct CSVImportResult {
    let rows: [CSVWorkItemRow]
    let errors: [(line: Int, message: String)]
}

struct WorkItemCSVParser {
    static func parse(_ content: String) -> CSVImportResult {
        var rows: [CSVWorkItemRow] = []
        var errors: [(Int, String)] = []

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return CSVImportResult(rows: [], errors: [(0, "Dosya boş")])
        }

        let startIndex = isHeaderLine(lines[0]) ? 1 : 0
        let dataLines = startIndex < lines.count ? Array(lines[startIndex...]) : []

        for (i, line) in dataLines.enumerated() {
            let lineNum = i + startIndex + 1
            let cols = parseCSVLine(line)

            guard cols.count >= 5 else {
                errors.append((lineNum, "Eksik sütun (\(cols.count)/5) — satır atlandı"))
                continue
            }

            let code = cols[0].trimmingCharacters(in: .whitespaces)
            let name = cols[1].trimmingCharacters(in: .whitespaces)
            let unit = cols[2].trimmingCharacters(in: .whitespaces)
            let priceStr = cols[3]
                .replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "₺", with: "")
            let qtyStr = cols[4]
                .replacingOccurrences(of: ",", with: ".")
                .replacingOccurrences(of: " ", with: "")
            let location = cols.count > 5 ? cols[5].trimmingCharacters(in: .whitespaces) : ""

            guard !code.isEmpty, !name.isEmpty else {
                errors.append((lineNum, "Poz no veya adı boş"))
                continue
            }

            guard let price = Double(priceStr), price >= 0 else {
                errors.append((lineNum, "Birim fiyat geçersiz: \(cols[3])"))
                continue
            }

            guard let qty = Double(qtyStr), qty > 0 else {
                errors.append((lineNum, "Miktar geçersiz: \(cols[4])"))
                continue
            }

            rows.append(CSVWorkItemRow(
                code: code, name: name, unit: unit.isEmpty ? "adet" : unit,
                unitPrice: price, contractedQuantity: qty, location: location
            ))
        }

        return CSVImportResult(rows: rows, errors: errors)
    }

    private static func isHeaderLine(_ line: String) -> Bool {
        let first = parseCSVLine(line).first?.trimmingCharacters(in: .whitespaces) ?? ""
        return Double(first) == nil && !first.isEmpty
    }

    static func parseCSVLine(_ line: String) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                cols.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        cols.append(current)
        return cols
    }
}

// MARK: - CSV Exporter

struct CSVExporter {
    static func exportHakedisler(_ hakedisler: [Hakedis]) -> String {
        var lines = ["Proje,Sözleşme,Taşeron,Dönem,Başlangıç,Bitiş,Durum,Brüt (₺),Teminat (₺),Net Hakediş (₺),Ödenen (₺),Kalan (₺)"]

        for h in hakedisler.sorted(by: { $0.createdAt < $1.createdAt }) {
            lines.append([
                q(h.contract?.project?.name ?? ""),
                q(h.contract?.title ?? ""),
                q(h.contract?.contractor?.name ?? ""),
                q(h.periodName),
                d(h.periodStart),
                d(h.periodEnd),
                q(h.status.rawValue),
                n(h.grossAmount),
                n(h.retentionAmount),
                n(h.netAmount),
                n(h.totalPaid),
                n(h.remainingAmount)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func exportWorkItems(_ contract: Contract) -> String {
        var lines = ["Poz No,Adı,Birimi,Birim Fiyatı (₺),Sözleşme Miktarı,Yapılan Miktar,Tamamlanma %,Tutar (₺),Mahal"]

        for item in contract.workItems.sorted(by: { $0.code < $1.code }) {
            lines.append([
                q(item.code),
                q(item.name),
                q(item.unit),
                n(item.unitPrice),
                n(item.contractedQuantity),
                n(item.completedQuantity),
                n(item.completionPercentage),
                n(item.totalAmount),
                q(item.location)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func q(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }
    private static func n(_ v: Double) -> String { String(format: "%.2f", v) }
    private static func d(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "dd.MM.yyyy"; return f.string(from: date)
    }
}

// MARK: - Document Picker

struct CSVDocumentPicker: UIViewControllerRepresentable {
    let onPick: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.commaSeparatedText, .plainText, .data]
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (String) -> Void
        init(onPick: @escaping (String) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            // UTF-8 önce, sonra Windows-1254 (Türkçe Excel)
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                onPick(content)
            } else if let content = try? String(contentsOf: url, encoding: .windowsCP1254) {
                onPick(content)
            }
        }
    }
}

// MARK: - CSV Import Preview View

struct CSVImportPreviewView: View {
    let result: CSVImportResult
    let onImport: ([CSVWorkItemRow]) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !result.errors.isEmpty {
                    Section {
                        ForEach(result.errors, id: \.line) { err in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.hakedisWarning)
                                    .font(.caption)
                                Text("Satır \(err.line): \(err.message)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Label("\(result.errors.count) satır atlandı", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.hakedisWarning)
                    }
                }

                Section {
                    ForEach(result.rows, id: \.code) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("[\(row.code)]")
                                    .font(.caption.monospaced())
                                    .foregroundColor(.secondary)
                                Text(row.name)
                                    .font(.subheadline.bold())
                            }
                            HStack {
                                Text("\(String(format: "%.0f", row.contractedQuantity)) \(row.unit)")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text((row.unitPrice * row.contractedQuantity).currencyFormatted)
                                    .font(.caption.bold()).foregroundColor(.hakedisOrange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("\(result.rows.count) iş kalemi hazır")
                }
            }
            .navigationTitle("İçe Aktarma Önizleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aktar (\(result.rows.count))") {
                        onImport(result.rows)
                        dismiss()
                    }
                    .bold()
                    .disabled(result.rows.isEmpty)
                }
            }
        }
    }
}
