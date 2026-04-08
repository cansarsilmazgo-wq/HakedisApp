import Foundation

// MARK: - Türkiye İl / İlçe Listesi

enum TurkiyeIller {

    static let iller: [String] = [
        "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Amasya",
        "Ankara", "Antalya", "Artvin", "Aydın", "Balıkesir",
        "Bilecik", "Bingöl", "Bitlis", "Bolu", "Burdur",
        "Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli",
        "Diyarbakır", "Edirne", "Elazığ", "Erzincan", "Erzurum",
        "Eskişehir", "Gaziantep", "Giresun", "Gümüşhane", "Hakkari",
        "Hatay", "Isparta", "Mersin", "İstanbul", "İzmir",
        "Kars", "Kastamonu", "Kayseri", "Kırklareli", "Kırşehir",
        "Kocaeli", "Konya", "Kütahya", "Malatya", "Manisa",
        "Kahramanmaraş", "Mardin", "Muğla", "Muş", "Nevşehir",
        "Niğde", "Ordu", "Rize", "Sakarya", "Samsun",
        "Siirt", "Sinop", "Sivas", "Tekirdağ", "Tokat",
        "Trabzon", "Tunceli", "Şanlıurfa", "Uşak", "Van",
        "Yozgat", "Zonguldak", "Aksaray", "Bayburt", "Karaman",
        "Kırıkkale", "Batman", "Şırnak", "Bartın", "Ardahan",
        "Iğdır", "Yalova", "Karabük", "Kilis", "Osmaniye", "Düzce"
    ]

    // Seçili ile göre temsili ilçe listesi (tam liste yerine en çok kullanılanlar)
    static func districts(for city: String) -> [String] {
        districtMap[city] ?? []
    }

    private static let districtMap: [String: [String]] = [
        "Adana": ["Seyhan", "Çukurova", "Yüreğir", "Sarıçam", "Ceyhan", "Kozan", "Karaisalı", "Karataş", "Pozantı", "Aladağ", "İmamoğlu", "Tufanbeyli", "Yumurtalık"],
        "Ankara": ["Çankaya", "Keçiören", "Mamak", "Etimesgut", "Sincan", "Altındağ", "Yenimahalle", "Pursaklar", "Gölbaşı", "Polatlı", "Beypazarı", "Elmadağ", "Haymana"],
        "İstanbul": ["Kadıköy", "Beşiktaş", "Üsküdar", "Fatih", "Beyoğlu", "Bakırköy", "Şişli", "Maltepe", "Ataşehir", "Ümraniye", "Kartal", "Pendik", "Tuzla", "Çekmeköy", "Sancaktepe", "Sultanbeyli", "Beykoz", "Sarıyer", "Eyüpsultan", "Avcılar", "Esenyurt", "Bağcılar", "Güngören", "Esenler", "Sultangazi", "Gaziosmanpaşa", "Kağıthane", "Zeytinburnu", "Bayrampaşa", "Başakşehir", "Büyükçekmece", "Arnavutköy", "Beylikdüzü", "Silivri", "Çatalca", "Adalar", "Şile"],
        "İzmir": ["Konak", "Bornova", "Karşıyaka", "Buca", "Çiğli", "Gaziemir", "Balçova", "Narlıdere", "Bayraklı", "Güzelbahçe", "Karabağlar", "Aliağa", "Bergama", "Çeşme", "Dikili", "Foça", "Karaburun", "Kınık", "Kiraz", "Menderes", "Menemen", "Ödemiş", "Seferihisar", "Selçuk", "Tire", "Torbalı", "Urla"],
        "Antalya": ["Muratpaşa", "Kepez", "Konyaaltı", "Aksu", "Döşemealtı", "Alanya", "Manavgat", "Serik", "Kaş", "Kemer", "Side", "Finike", "Gazipaşa"],
        "Bursa": ["Osmangazi", "Yıldırım", "Nilüfer", "Gemlik", "İnegöl", "Mudanya", "Orhangazi", "Mustafakemalpaşa", "Karacabey"],
        "Konya": ["Selçuklu", "Meram", "Karatay", "Ereğli", "Akşehir", "Beyşehir", "Çumra", "Ilgın", "Kulu"],
        "Kayseri": ["Melikgazi", "Kocasinan", "Talas", "Develi", "Pınarbaşı", "Yahyalı"],
        "Gaziantep": ["Şahinbey", "Şehitkamil", "İslahiye", "Nurdağı", "Oğuzeli", "Araban", "Yavuzeli"],
        "Hatay": ["Antakya", "İskenderun", "Dörtyol", "Erzin", "Payas", "Reyhanlı", "Kırıkhan", "Samandağ"],
        "Samsun": ["İlkadım", "Canik", "Atakum", "Tekkeköy", "Bafra", "Çarşamba", "Terme", "Vezirköprü"],
        "Trabzon": ["Ortahisar", "Akçaabat", "Arsin", "Araklı", "Of", "Yomra", "Çaykara", "Vakfıkebir"],
        "Sakarya": ["Adapazarı", "Serdivan", "Erenler", "Hendek", "Akyazı", "Geyve", "Sapanca"],
        "Kocaeli": ["İzmit", "Gebze", "Darıca", "Körfez", "Dilovası", "Çayırova", "Başiskele", "Karamürsel"],
        "Tekirdağ": ["Süleymanpaşa", "Ergene", "Çorlu", "Çerkezköy", "Malkara", "Hayrabolu"],
        "Eskişehir": ["Odunpazarı", "Tepebaşı", "Sivrihisar", "Mihalıçcık", "Alpu"],
        "Diyarbakır": ["Bağlar", "Kayapınar", "Sur", "Yenişehir", "Ergani", "Bismil", "Çermik"],
        "Şanlıurfa": ["Eyyübiye", "Haliliye", "Karaköprü", "Siverek", "Birecik", "Bozova", "Ceylanpınar"],
        "Malatya": ["Battalgazi", "Yeşilyurt", "Doğanşehir", "Akçadağ", "Darende"],
        "Kırklareli": ["Merkez", "Lüleburgaz", "Babaeski", "Vize", "Demirköy", "Pehlivanköy"],
        "Balıkesir": ["Altıeylül", "Karesi", "Ayvalık", "Bandırma", "Edremit", "Gönen", "Sındırgı"],
        "Aydın": ["Efeler", "Kuşadası", "Didim", "Söke", "Nazilli", "İncirliova", "Koçarlı"],
        "Denizli": ["Pamukkale", "Merkezefendi", "Çivril", "Acıpayam", "Tavas", "Honaz"],
        "Muğla": ["Menteşe", "Bodrum", "Dalaman", "Datça", "Fethiye", "Marmaris", "Milas", "Seydikemer"],
        "Mersin": ["Akdeniz", "Mezitli", "Toroslar", "Yenişehir", "Tarsus", "Erdemli", "Silifke", "Anamur"],
        "Van": ["İpekyolu", "Tuşba", "Edremit", "Erciş", "Gevaş", "Özalp"],
        "Erzurum": ["Yakutiye", "Aziziye", "Palandöken", "Horasan", "Oltu", "Pasinler"],
        "Manisa": ["Şehzadeler", "Yunusemre", "Akhisar", "Alaşehir", "Salihli", "Turgutlu", "Soma"],
        "Kahramanmaraş": ["Dulkadiroğlu", "Onikişubat", "Elbistan", "Afşin", "Pazarcık"],
        "Mardin": ["Artuklu", "Kızıltepe", "Nusaybin", "Derik", "Midyat"],
        "Sivas": ["Merkez", "Şarkışla", "Gemerek", "Kangal", "Koyulhisar"],
        "Ordu": ["Altınordu", "Ünye", "Fatsa", "Perşembe", "Gülyalı"],
        "Tokat": ["Merkez", "Erbaa", "Niksar", "Turhal", "Zile"],
        "Rize": ["Merkez", "Çayeli", "Ardeşen", "Pazar", "İyidere"],
    ]
}
