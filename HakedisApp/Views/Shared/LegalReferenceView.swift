import SwiftUI

// MARK: - LegalReferenceView
// 4734 Kamu İhale Kanunu ve 4735 Kamu İhale Sözleşmeleri Kanunu referans maddeler

struct LegalReferenceView: View {
    @State private var searchText = ""
    @State private var selectedLaw: LegalLaw = .k4735

    var body: some View {
        VStack(spacing: 0) {
            Picker("Kanun", selection: $selectedLaw) {
                ForEach(LegalLaw.allCases) { law in
                    Text(law.shortName).tag(law)
                }
            }
            .pickerStyle(.segmented)
            .padding(Spacing.card)
            .background(Color.hakedisBackground)

            List {
                ForEach(filteredArticles) { article in
                    LegalArticleRow(article: article)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Madde ara...")
        }
        .background(Color.hakedisBackground)
        .navigationTitle("Mevzuat Referansı")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var filteredArticles: [LegalArticle] {
        let articles = selectedLaw.articles
        if searchText.isEmpty { return articles }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText) ||
            $0.articleNo.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - LegalArticleRow

private struct LegalArticleRow: View {
    let article: LegalArticle
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Madde \(article.articleNo)").font(.caption.bold()).foregroundColor(.hakedisOrange)
                        Text(article.title).font(.subheadline.bold()).foregroundColor(.primary).multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(article.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Data Model

enum LegalLaw: String, CaseIterable, Identifiable {
    case k4734 = "4734"
    case k4735 = "4735"

    var id: String { rawValue }
    var shortName: String { rawValue + " Sayılı" }

    var articles: [LegalArticle] { LegalDatabase.articles(for: self) }
}

struct LegalArticle: Identifiable {
    let id = UUID()
    let law: LegalLaw
    let articleNo: String
    let title: String
    let body: String
}

// MARK: - Static Data

struct LegalDatabase {
    static func articles(for law: LegalLaw) -> [LegalArticle] {
        switch law {
        case .k4734: return articles4734
        case .k4735: return articles4735
        }
    }

    static let articles4734: [LegalArticle] = [
        LegalArticle(law: .k4734, articleNo: "4", title: "Temel İlkeler",
            body: "İdareler, bu Kanuna göre yapılacak ihalelerde; saydamlığı, rekabeti, eşit muameleyi, güvenirliği, gizliliği, kamuoyu denetimini, ihtiyaçların uygun şartlarla ve zamanında karşılanmasını ve kaynakların verimli kullanılmasını sağlamakla sorumludur."),
        LegalArticle(law: .k4734, articleNo: "5", title: "Temel İlkeler (İhale İlkeleri)",
            body: "Aralarında kabul edilebilir doğal bir bağlantı olmadığı sürece mal alımı, hizmet alımı ve yapım işleri bir arada ihale edilemez. Eşik değerlerin altında kalmak amacıyla mal veya hizmet alımları ile yapım işleri kısımlara bölünemez."),
        LegalArticle(law: .k4734, articleNo: "10", title: "İhaleye Katılımda Yeterlilik Kuralları",
            body: "İhaleye katılacak isteklilerden ekonomik ve mali yeterlik ile mesleki ve teknik yeterliklerinin belirlenmesine ilişkin bilgi ve belgeler istenebilir. Ekip veya organizasyon bünyesindeki personel ve ekipmana ait belgeler ile isteklinin üretim ve/veya imalat kapasitesine yönelik belgeler istenebilir."),
        LegalArticle(law: .k4734, articleNo: "22", title: "Doğrudan Temin",
            body: "Aşağıda belirtilen hallerde ihtiyaçların ilân yapılmaksızın ve teminat alınmaksızın doğrudan teminine ilişkin esaslar çerçevesinde alım yapılabilir: a) İhtiyacın sadece gerçek veya tüzel tek kişi tarafından karşılanabileceğinin tespit edilmesi. b) Sadece gerçek veya tüzel tek kişinin ihtiyacı karşılayabileceğinin belirlendiği durumlarda."),
        LegalArticle(law: .k4734, articleNo: "38", title: "Aşırı Düşük Teklifler",
            body: "İhale komisyonu verilen teklifleri değerlendirdikten sonra diğer tekliflere veya idarenin tespit ettiği yaklaşık maliyete göre teklif fiyatı aşırı düşük olanları tespit eder. Bu teklifleri reddetmeden önce, belirlediği süre içinde teklif sahiplerinden teklife ilişkin önemli bileşenler itibariyle ayrıntıları belgelemesini isteyerek açıklama ister."),
        LegalArticle(law: .k4734, articleNo: "53", title: "Kamu İhale Kurulu",
            body: "Bu Kanunla verilen görevleri yapmak üzere Kamu İhale Kurulu oluşturulmuştur. Kamu İhale Kurulu ihalelere ilişkin şikayetleri ve itirazları inceler ve karara bağlar.")
    ]

    static let articles4735: [LegalArticle] = [
        LegalArticle(law: .k4735, articleNo: "4", title: "Sözleşmelerde Yer Alan Zorunlu Hususlar",
            body: "Sözleşmelerde işin adı, niteliği, türü ve miktarı; sözleşmenin bedeli ve ödeme şartları; işin yapılacağı yer veya teslim yeri; işin başlangıç ve bitiş tarihi; fiyat farkı ödenip ödenmeyeceği, ödenecekse şartları ve hesaplama yöntemi; kesin teminat miktarı ile teminatın iade şartları yer alır."),
        LegalArticle(law: .k4735, articleNo: "8", title: "Fiyat Farkı",
            body: "Sözleşmelerde fiyat farkı verilebilmesi için ihale dokümanında ve sözleşmesinde hüküm bulunması zorunludur. Fiyat farkı hesabında kullanılacak formül: Pn = a1×(İ1n/İ1₀) + a2×(İ2n/İ2₀) + a3×(İ3n/İ3₀) + a4×(İ4n/İ4₀) + a5\nBurada a1+a2+a3+a4+a5 = 1 olmalı; a5 sabit katsayı (genellikle 0,12 olarak belirlenir). F = An × (Pn - 1) formülüyle fiyat farkı tutarı hesaplanır."),
        LegalArticle(law: .k4735, articleNo: "10", title: "Kesin Teminat",
            body: "Taahhüdün, sözleşme ve ihale dokümanı hükümlerine uygun olarak yerine getirilmesini sağlamak amacıyla sözleşmenin yapılmasından önce yükleniciden kesin teminat alınır. Kesin teminat miktarı sözleşme bedelinin %6'sıdır."),
        LegalArticle(law: .k4735, articleNo: "15", title: "Sözleşme Kapsamında Yaptırılabilecek İlave İşler",
            body: "Yapım sözleşmelerinde, işin başlangıcında öngörülemeyen durumlar nedeniyle bir iş kaleminde veya grubunda sözleşme bedelinin %20'sini aşmamak üzere süre hariç sözleşme ve ihale dokümanı hükümlerine göre ilave iş yaptırılabilir ve eksik iş bırakılabilir."),
        LegalArticle(law: .k4735, articleNo: "16", title: "İşin Devri",
            body: "Yüklenici, sözleşmenin tamamını veya bir kısmını başkasına devredemez. Bu yasağa aykırı olarak devir yapılması halinde, sözleşme feshedilerek hesabı genel hükümlere göre tasfiye edilir."),
        LegalArticle(law: .k4735, articleNo: "19", title: "İdare Tarafından Sözleşmenin Feshi",
            body: "Aşağıda belirtilen hallerde idare sözleşmeyi fesheder: a) Yüklenicinin taahhüdünü ihale dokümanı ve sözleşme hükümlerine uygun olarak yerine getirmemesi. b) Yüklenicinin sözleşmeyi devretmesi. c) Yüklenicinin iflası veya ağır hastalık, tutukluluk veya mahkumiyet gibi durumlar."),
        LegalArticle(law: .k4735, articleNo: "20", title: "Yüklenici Tarafından Sözleşmenin Feshi",
            body: "Mücbir sebep halleri dışında, yüklenicinin sözleşmeyi feshetmek istemesi halinde, en az 30 gün önceden idareye yazılı ihbarda bulunması ve idarenin bu konuda muvafakat etmesi şarttır. Bu halde hesabı tasfiye edilir ve yüklenicinin teminatı irat kaydedilir."),
        LegalArticle(law: .k4735, articleNo: "23", title: "Süre Uzatımı Verilebilecek Haller",
            body: "Mücbir sebep olarak kabul edilebilecek haller: doğal afetler; kanuni grev; genel salgın hastalık; kısmî veya genel seferberlik ilanı; gerekli ödenek aktarımının yapılmaması; idareden kaynaklanan gecikmeler. Bu hallerde yüklenicinin idareye başvurması ve idarenin kabul etmesi şartıyla süre uzatımı verilebilir.")
    ]
}
