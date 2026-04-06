import SwiftUI

// MARK: - HelpView

struct HelpView: View {
    @State private var expandedID: UUID? = nil

    var body: some View {
        List {
            ForEach(HelpTopic.allTopics) { topic in
                Section {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedID == topic.id },
                            set: { expandedID = $0 ? topic.id : nil }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            ForEach(topic.steps, id: \.self) { step in
                                HStack(alignment: .top, spacing: Spacing.xs) {
                                    Text("•").foregroundColor(.hakedisOrange)
                                    Text(step).font(.subheadline)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: topic.icon)
                                .foregroundColor(.hakedisOrange)
                                .frame(width: 24)
                            Text(topic.title).font(.subheadline.bold())
                        }
                    }
                    .accessibilityLabel(topic.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Yardım ve Rehber")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - HelpTopic Model

private struct HelpTopic: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let steps: [String]

    static let allTopics: [HelpTopic] = [
        HelpTopic(icon: "doc.text.fill", title: "Hakediş Nedir?", steps: [
            "Hakediş; yüklenicinin tamamladığı iş karşılığında düzenlediği ödeme belgesidir.",
            "Proje > Sözleşme > Hakediş yolunu izleyerek yeni hakediş oluşturabilirsiniz.",
            "İş kalemi miktarlarını girin, brüt/net tutarlar otomatik hesaplanır.",
            "Hakedişi onaya gönderin: Taslak → Onay Bekliyor → Onaylandı → Ödendi.",
            "PDF çıktısı almak için hakediş detayında 'PDF' düğmesine basın."
        ]),
        HelpTopic(icon: "calendar.badge.plus", title: "Şantiye Günlüğü Nasıl Tutulur?", steps: [
            "Şantiye sekmesinden 'Şantiye Günlüğü'nü seçin.",
            "'Ekle' ile yeni giriş oluşturun; tarih, hava durumu ve çalışma bilgilerini girin.",
            "Fotoğraf ekleyebilir, her güne not bırakabilirsiniz.",
            "PDF raporu oluşturmak için günlük detay ekranındaki PDF simgesini kullanın."
        ]),
        HelpTopic(icon: "person.2.fill", title: "Puantaj Nasıl Girilir?", steps: [
            "Şantiye > Puantaj menüsüne gidin.",
            "Tarih seçin ve 'Puantaj Ekle' düğmesine basın.",
            "İşçi adı, mesai saati ve mola bilgilerini girin.",
            "Fazla mesai hesaplaması (4857 sayılı Kanun) otomatik yapılır.",
            "SGK gün bildirimi ve işçilik maliyeti raporları oluşturabilirsiniz."
        ]),
        HelpTopic(icon: "shield.checkered", title: "İSG Kayıtları", steps: [
            "İSG modülüne Şantiye > İSG Yönetimi'nden erişin.",
            "Ramak kala, yaralanma ve kazaları kayıt altına alın.",
            "İş kazalarında SGK'ya 3 iş günü içinde bildirim yapılmalıdır.",
            "Düzeltici faaliyetleri takip edin; kapanışı onaylayın.",
            "Risk değerlendirmesi oluşturun ve kontrol önlemlerini belgeleyin."
        ]),
        HelpTopic(icon: "plusminus.circle", title: "Fiyat Farkı Hesaplama (4735 Md.8)", steps: [
            "Finans > Fiyat Farkı menüsüne gidin.",
            "Temel endeks (İo) ve güncel endeks (İn) değerlerini girin.",
            "Formül: Pn = P × (İn / İo) — Fark otomatik hesaplanır.",
            "Her hakediş dönemi için ayrı fiyat farkı kaydı oluşturabilirsiniz.",
            "Toplam fiyat farkı Kesin Hesap'a otomatik aktarılır."
        ]),
        HelpTopic(icon: "building.2", title: "Taşeron Hakediş ve Kâr Analizi", steps: [
            "Sözleşme detayından 'Taşeron Hakedişleri' bölümüne gidin.",
            "Her taşeron hakedişi için brüt/net tutarları girin.",
            "Kâr marjı = (Ana sözleşme geliri – Taşeron ödemesi) / Ana gelir × 100.",
            "Dönem bazında kâr analizi raporuna erişin."
        ]),
        HelpTopic(icon: "chart.xyaxis.line", title: "EVM Maliyet Kontrol", steps: [
            "Projeler > EVM Kontrolü menüsünden erişin.",
            "Bütçe kalemleri (BAC) oluşturun ve dönemsel EVM anlık görüntüsü kaydedin.",
            "SPI (Zaman) ve CPI (Maliyet) göstergelerini takip edin.",
            "CPI < 1.0 ise bütçe aşımı, SPI < 1.0 ise gecikme uyarısı verilir."
        ]),
        HelpTopic(icon: "shippingbox.fill", title: "Malzeme ve Stok Takibi", steps: [
            "Şantiye > Malzeme Yönetimi menüsünden erişin.",
            "Malzeme ekleyin, minimum stok seviyesi belirleyin.",
            "Giriş/çıkış hareketleri ile stok otomatik güncellenir.",
            "Kritik stok uyarıları Ana Ekran'da görüntülenir.",
            "Test sonucu ekleyebilir, uygunsuz malzemeleri işaretleyebilirsiniz."
        ]),
        HelpTopic(icon: "gearshape.2.fill", title: "Ekipman Yönetimi", steps: [
            "Şantiye > Ekipman Yönetimi menüsünden ekipman ekleyin.",
            "Günlük çalışma saatlerini kaydedin; toplam saat otomatik artar.",
            "Bakım aralığı dolduğunda otomatik bildirim gelir.",
            "Arıza kaydı oluşturun, tamir maliyetlerini takip edin.",
            "Kiralık ekipman için günlük kiralama maliyeti tanımlayın."
        ]),
        HelpTopic(icon: "doc.text.magnifyingglass", title: "PDF Raporları", steps: [
            "Her modülün detay ekranında PDF ikonu bulunur.",
            "Şirket adınızı Ayarlar > Şirket Bilgileri'nden girin.",
            "PDF'i paylaşmak, yazdırmak veya kaydetmek için paylaşım menüsünü kullanın.",
            "Hakediş, şantiye günlüğü, puantaj ve EVM raporları desteklenmektedir."
        ]),
        HelpTopic(icon: "arrow.triangle.2.circlepath", title: "Yedekleme ve Geri Yükleme", steps: [
            "Ayarlar > Veri Yönetimi > Yedekleme bölümüne gidin.",
            "JSON formatında tam yedek alın.",
            "Yedeği Files app veya iCloud'a kaydedin.",
            "Geri yüklemek için yedek dosyasını seçin ve 'İçe Aktar' düğmesine basın."
        ]),
        HelpTopic(icon: "magnifyingglass", title: "Arama Nasıl Kullanılır?", steps: [
            "Ana Ekran veya Projeler sekmesinde arama simgesine dokunun.",
            "En az 2 karakter girerek arama başlatın.",
            "Projeler, taşeronlar, iş kalemleri, hakedişler ve daha fazlasında arama yapılır.",
            "Kategori filtreleri ile sonuçları daraltabilirsiniz."
        ]),
        HelpTopic(icon: "bell.badge.fill", title: "Bildirimler", steps: [
            "Ayarlar > Bildirim Ayarları menüsünden bildirimleri yapılandırın.",
            "Günlük saha hatırlatıcısı her gün saat 17:00'da bildirim gönderir.",
            "Sertifika son kullanma tarihleri 30, 15 ve 7 gün öncesinde hatırlatılır.",
            "İş kazalarında SGK bildirimi geri sayım bildirimleri otomatik oluşturulur."
        ]),
        HelpTopic(icon: "lock.fill", title: "Uygulama Kilidi (Face ID)", steps: [
            "Ayarlar > Güvenlik menüsünden uygulama kilidini etkinleştirin.",
            "Uygulama arka plana geçtiğinde 30 saniye içinde kilitlenir.",
            "Face ID veya Touch ID ile kilit açılır.",
            "Biyometrik kimlik doğrulama başarısız olursa şifre ile giriş yapılabilir."
        ])
    ]
}
