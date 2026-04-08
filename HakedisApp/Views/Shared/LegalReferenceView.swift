import SwiftUI

// MARK: - LegalReferenceView
// 4734 Kamu İhale Kanunu ve 4735 Kamu İhale Sözleşmeleri Kanunu referans maddeler

struct LegalReferenceView: View {
    @State private var searchText = ""
    @State private var selectedLaw: LegalLaw = .k4735

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(LegalLaw.allCases) { law in
                        Button {
                            selectedLaw = law
                        } label: {
                            Text(law.shortName)
                                .font(.caption.weight(selectedLaw == law ? .semibold : .regular))
                                .foregroundColor(selectedLaw == law ? .hakedisOrange : .secondary)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .overlay(
                                    Rectangle().frame(height: 2)
                                        .foregroundColor(selectedLaw == law ? .hakedisOrange : .clear),
                                    alignment: .bottom
                                )
                        }
                        .accessibilityLabel(law.shortName)
                    }
                }
            }
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
    case k4734  = "4734"
    case k4735  = "4735"
    case k6331  = "6331"   // İş Sağlığı ve Güvenliği
    case k4857  = "4857"   // İş Kanunu
    case k5510  = "5510"   // SGK
    case k3194  = "3194"   // İmar Kanunu
    case k6306  = "6306"   // Kentsel Dönüşüm
    case k4708  = "4708"   // Yapı Denetimi
    case yigs   = "YIGS"   // Yapım İşleri Genel Şartnamesi
    case tbdy   = "TBDY"   // TBDY 2018

    var id: String { rawValue }
    var shortName: String {
        switch self {
        case .k4734: return "4734"
        case .k4735: return "4735"
        case .k6331: return "6331 İSG"
        case .k4857: return "4857 İK"
        case .k5510: return "5510 SGK"
        case .k3194: return "3194 İmar"
        case .k6306: return "6306 KD"
        case .k4708: return "4708 YD"
        case .yigs:  return "YIGS"
        case .tbdy:  return "TBDY 2018"
        }
    }

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
        case .k6331: return articles6331
        case .k4857: return articles4857
        case .k5510: return articles5510
        case .k3194: return articles3194
        case .k6306: return articles6306
        case .k4708: return articles4708
        case .yigs:  return articlesYIGS
        case .tbdy:  return articlesTBDY
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

    // MARK: - 6331 İş Sağlığı ve Güvenliği
    static let articles6331: [LegalArticle] = [
        LegalArticle(law: .k6331, articleNo: "2", title: "Kapsam",
            body: "Bu Kanun; kamu ve özel sektöre ait bütün işlere ve işyerlerine, bu işyerlerinin işverenleri ile işveren vekillerine, çırak ve stajyerler de dahil olmak üzere tüm çalışanlarına faaliyet konularına bakılmaksızın uygulanır."),
        LegalArticle(law: .k6331, articleNo: "4", title: "İşverenin Genel Yükümlülüğü",
            body: "İşveren, çalışanların işle ilgili sağlık ve güvenliğini sağlamakla yükümlü olup bu çerçevede; mesleki risklerin önlenmesi, eğitim ve bilgi verilmesi dahil her türlü tedbirin alınması, organizasyonun yapılması, gerekli araç ve gereçlerin sağlanması, sağlık ve güvenlik tedbirlerinin değişen şartlara uygun hale getirilmesi ve mevcut durumun iyileştirilmesi için çalışmalar yapar."),
        LegalArticle(law: .k6331, articleNo: "6", title: "İş Güvenliği Uzmanı Görevlendirme",
            body: "Mesleki risklerin önlenmesi ve bu risklerden korunulmasına yönelik çalışmaları da kapsayacak iş sağlığı ve güvenliği hizmetlerinin sunulması için işveren; çalışanları arasından iş güvenliği uzmanı, işyeri hekimi ve gerektiğinde diğer sağlık personeli görevlendirir."),
        LegalArticle(law: .k6331, articleNo: "11", title: "Acil Durum Planları",
            body: "İşveren; çalışma ortamı, kullanılan maddeler, iş ekipmanı ile çevre şartlarını dikkate alarak meydana gelebilecek acil durumları önceden değerlendirerek, çalışanları ve çalışma çevresini etkilemesi mümkün ve muhtemel acil durumları belirler ve bunlara ilişkin tedbirleri alır."),
        LegalArticle(law: .k6331, articleNo: "16", title: "Çalışanların Eğitimi",
            body: "İşveren, çalışanlara iş sağlığı ve güvenliği eğitimi verilmesini sağlar. Bu eğitim özellikle; işe başlamadan önce, çalışma yeri veya iş değişikliğinde, iş ekipmanının değişmesi hâlinde veya yeni teknoloji uygulanması hâlinde verilir. Eğitimler, değişen ve ortaya çıkan yeni risklere uygun olarak yenilenir, gerektiğinde ve düzenli aralıklarla tekrarlanır.")
    ]

    // MARK: - 4857 İş Kanunu
    static let articles4857: [LegalArticle] = [
        LegalArticle(law: .k4857, articleNo: "2", title: "Tanımlar",
            body: "İşveren: Bir iş sözleşmesine dayanarak çalıştırdığı işçinin işini yapan gerçek veya tüzel kişi. Alt işveren: Bir işverenden, işyerinde yürüttüğü mal veya hizmet üretimine ilişkin yardımcı işlerinde veya asıl işin bir bölümünde işletmenin ve işin gereği ile teknolojik nedenlerle uzmanlık gerektiren işlerde iş alan ve bu iş için görevlendirdiği işçilerini sadece bu işyerinde aldığı işte çalıştıran diğer işveren."),
        LegalArticle(law: .k4857, articleNo: "17", title: "Belirsiz Süreli İş Sözleşmelerinde Fesih Bildirimi",
            body: "Belirsiz süreli iş sözleşmelerinin feshinden önce durumun diğer tarafa bildirilmesi gerekir. İş sözleşmeleri; işçinin işyerindeki kıdemine göre: 6 aydan az kıdemi olan: 2 hafta önceden; 6 ay – 1,5 yıl: 4 hafta önceden; 1,5 yıl – 3 yıl: 6 hafta önceden; 3 yıldan fazla kıdemi olan: 8 hafta önceden ihbar bildiriminde bulunulmalıdır."),
        LegalArticle(law: .k4857, articleNo: "41", title: "Fazla Çalışma",
            body: "Ülkenin genel yararları yahut işin niteliği veya üretimin artırılması gibi nedenlerle fazla çalışma yaptırılabilir. Fazla çalışma, Kanunda yazılı koşullar çerçevesinde, haftalık kırkbeş saati aşan çalışmalardır. Her bir saat fazla çalışma için verilecek ücret normal çalışma ücretinin saat başına düşen miktarının yüzde elli yükseltilmesi suretiyle ödenir."),
        LegalArticle(law: .k4857, articleNo: "53", title: "Yıllık Ücretli İzin Hakkı ve İzin Süreleri",
            body: "İşyerinde işe başladığı günden itibaren, deneme süresi de içinde olmak üzere, en az bir yıl çalışmış olan işçilere yıllık ücretli izin verilir. Yıllık ücretli izin süresi: 1–5 yıl arası: 14 günden az olamaz. 5–15 yıl arası: 20 günden az olamaz. 15 yıl ve üzeri: 26 günden az olamaz.")
    ]

    // MARK: - 5510 SGK
    static let articles5510: [LegalArticle] = [
        LegalArticle(law: .k5510, articleNo: "4", title: "Sigortalı Sayılanlar",
            body: "Hizmet akdi ile bir veya birden fazla işveren tarafından çalıştırılanlar bu Kanun kapsamında sigortalı sayılır. Alt işverenin işçileri için de asıl işveren alt işverenle birlikte müteselsilen sorumludur."),
        LegalArticle(law: .k5510, articleNo: "8", title: "Sigortalı Bildirimi",
            body: "İşverenler, sigortalı sayılan kişileri, işyerini ve işyerinde çalışanları Kuruma bildirmekle yükümlüdür. İşçi çalıştırılmaya başlandığında en geç çalıştırılmaya başlandığı gün Kuruma bildirilmesi zorunludur. Çalışma sona erdiğinde 10 gün içinde bildirilmesi gerekir."),
        LegalArticle(law: .k5510, articleNo: "86", title: "Belge ve Bilgi Verme",
            body: "İşverenler, işyerlerini, sigortalıları, sigortalıların işe alınış ve işten çıkış tarihlerini, sigortalıların çalışma gün sayısını, prim ödeme gün sayısını, sigortalıların ücretlerini Kuruma bildirmekle yükümlüdür.")
    ]

    // MARK: - 3194 İmar Kanunu
    static let articles3194: [LegalArticle] = [
        LegalArticle(law: .k3194, articleNo: "21", title: "Ruhsat Alınması Zorunluluğu",
            body: "Bu Kanunun kapsamına giren bütün yapılar için Madde 26'da belirtilen istisna dışında belediye veya valiliklerden önce yapı ruhsatı alınması mecburidir."),
        LegalArticle(law: .k3194, articleNo: "28", title: "Yapı Kullanma İzni",
            body: "Yapının tamamlanması halinde tamamının, kısmen kullanılması mümkün kısımların tamamlanması halinde bu kısımların kullanılabilmesi için yapı kullanma izninin alınması zorunludur."),
        LegalArticle(law: .k3194, articleNo: "32", title: "Ruhsatsız Yapılar",
            body: "Bu Kanun hükümlerine aykırı yapı yapan veya yaptıran kişi hakkında ruhsatsız yapılar durdurulur; yapı durdurulmasına rağmen yapılmaya devam edildiği tespit edildiğinde para cezası uygulanır ve yapı yıktırılır.")
    ]

    // MARK: - 6306 Kentsel Dönüşüm
    static let articles6306: [LegalArticle] = [
        LegalArticle(law: .k6306, articleNo: "2", title: "Tanımlar",
            body: "Riskli yapı: Riskli alan içinde veya dışında olup ekonomik ömrünü tamamlamış olan ya da yoğun hasara uğrama riski taşıdığı ilmi ve teknik verilere dayanılarak tespit edilen yapıdır. Riskli alan: Zemin yapısı veya üzerindeki yapılaşma sebebiyle can ve mal kaybına yol açma riski taşıyan, Cumhurbaşkanınca kararlaştırılan alandır."),
        LegalArticle(law: .k6306, articleNo: "3", title: "Riskli Yapıların Tespiti",
            body: "Riskli yapıların tespiti, Bakanlıkça hazırlanacak yönetmelikte belirlenen usul ve esaslar çerçevesinde masrafları kendilerine ait olmak üzere, öncelikle yapı malikleri veya kanuni temsilcilerince yaptırılır. Bakanlık, riskli yapıların tespiti için başvuru yapılmaması halinde bu tespiti re'sen yaptırabilir."),
        LegalArticle(law: .k6306, articleNo: "6", title: "Dönüşüm Projesi",
            body: "Üzerindeki yapılar tamamen yıkılarak arsa haline getirilen riskli alan veya rezerv yapı alanlarında ve tamamen yıkılan riskli yapıların maliklerine, anlaşma sağlanamaması halinde, taşınmazın değerinin tespitinde %15 artırımlı değer esas alınır.")
    ]

    // MARK: - 4708 Yapı Denetimi
    static let articles4708: [LegalArticle] = [
        LegalArticle(law: .k4708, articleNo: "1", title: "Amaç ve Kapsam",
            body: "Bu Kanun; can ve mal güvenliğini teminen, imar planına, fen, sanat ve sağlık kurallarına, standartlara uygun kaliteli yapı yapılması için proje ve yapı denetimini sağlamak, yapı denetim kuruluşlarının kuruluş, görev, yetki ve sorumlulukları ile bu kuruluşların denetimine ilişkin usul ve esasları düzenler."),
        LegalArticle(law: .k4708, articleNo: "2", title: "Tanımlar",
            body: "Yapı denetim kuruluşu: Bu Kanun kapsamındaki yapıların denetimini üstlenen, ortaklarının tamamı mimar ve mühendislerden oluşan tüzel kişi. Yapı denetçisi: Yapı denetim kuruluşu adına, yapının denetimine katılan mimar veya mühendis.")
    ]

    // MARK: - YIGS Yapım İşleri Genel Şartnamesi
    static let articlesYIGS: [LegalArticle] = [
        LegalArticle(law: .yigs, articleNo: "7", title: "Muayene ve Kabul",
            body: "Yapılan işlerin muayene ve kabulü sözleşmede belirlenen hükümlere göre yetkili muayene ve kabul komisyonlarınca yapılır. Kabulde, işin ihale dokümanında belirlenen şartlara uygunluğu aranır."),
        LegalArticle(law: .yigs, articleNo: "8", title: "Hakediş Raporları",
            body: "Yüklenici, belirli dönemlere ait müstahak hakedişini hesaplamak için hakediş raporu düzenler. Ödeme belgesi olarak düzenlenen hakediş raporlarının ilgili idare tarafından onaylanması gerekir. Onaylanan hakediş raporlarının muhasebe birimine intikali gereken süre içinde gerçekleştirilmez ise faiz uygulanır."),
        LegalArticle(law: .yigs, articleNo: "12", title: "Hakediş Ödemeleri",
            body: "Yükleniciye yapılacak ara ödemeler sözleşmede belirtilen hakediş dönemlerine göre yapılır. Onaylanan hakediş tutarından kesin teminat, avans geri ödemesi, KDV tevkifatı ve diğer kesintiler yapıldıktan sonra kalan tutar ödenir."),
        LegalArticle(law: .yigs, articleNo: "43", title: "Geçici Kabul",
            body: "Sözleşmede aksi belirtilmedikçe, kesin hesap ve kesin kabul yapılmadan önce geçici kabul yapılır. Geçici kabulde komisyon, yapılan işi inceleyerek kabul veya reddeder; eksiklikler listesi tutulur ve giderilmesi için süre verilir.")
    ]

    // MARK: - TBDY 2018
    static let articlesTBDY: [LegalArticle] = [
        LegalArticle(law: .tbdy, articleNo: "3", title: "Deprem Bölgeleri ve Sismik Parametreler",
            body: "Türkiye Deprem Tehlike Haritasına göre deprem bölgeleri ve sismik parametreler tanımlanmıştır. DD-2 deprem yer hareketi düzeyi (50 yılda %10 aşılma olasılığı, 475 yıl tekrar periyodu) tasarım depremi olarak kullanılır."),
        LegalArticle(law: .tbdy, articleNo: "4", title: "Bina Kullanım Sınıfları",
            body: "BKS 1: Normal bina kullanım sınıfı (konut, ofis, küçük ölçekli ticari). BKS 2: İnsanların kısa süreli bulunduğu depolarla bağlantılı binalar. BKS 3: Deprem sonrası işlevini sürdürmesi gereken binalar (hastane, itfaiye, okul). Kullanım sınıfına göre önem katsayısı (I) farklılaşır."),
        LegalArticle(law: .tbdy, articleNo: "5", title: "Bina Performans Hedefleri",
            body: "DD-2 deprem düzeyi için: BKS 1 binaları için Kontrollü Hasar (KH) performans hedefi; BKS 3 binaları için Sınırlı Hasar (SH) performans hedefi belirlenir. DD-3 deprem düzeyi için tüm bina sınıfları için Hemen Kullanım (HK) performansı hedeflenir.")
    ]
}
