import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @AppStorage("companyName") private var companyName = ""
    @State private var companyInput = ""
    @State private var showRegister = false

    private let pages = OnboardingPage.allPages

    var body: some View {
        ZStack {
            Color.hakedisBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { idx in
                        if idx < pages.count - 1 {
                            OnboardingPageView(page: pages[idx])
                                .tag(idx)
                        } else {
                            OnboardingLastPageView(companyInput: $companyInput)
                                .tag(idx)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.easeInOut, value: currentPage)

                VStack(spacing: Spacing.cardSmall) {
                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("İleri")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.cardSmall)
                                .background(Color.hakedisOrange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("İleri")
                    } else {
                        Button {
                            if !companyInput.isEmpty { companyName = companyInput }
                            hasSeenOnboarding = true
                            showRegister = true
                        } label: {
                            Text("Başla")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.cardSmall)
                                .background(Color.hakedisOrange)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("Uygulamayı başlat")
                    }

                    Button("Atla") { hasSeenOnboarding = true }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Onboardingı atla")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let bullets: [String]

    static let allPages: [OnboardingPage] = [
        OnboardingPage(
            icon: "building.2.crop.circle.fill",
            iconColor: .hakedisOrange,
            title: "Hoş Geldiniz",
            subtitle: "İnşaat projelerinizi tek yerden yönetin",
            bullets: [
                "Hakediş hazırlama ve takip",
                "Saha girişleri ve şantiye günlüğü",
                "Finansal kontrol ve raporlama"
            ]
        ),
        OnboardingPage(
            icon: "hammer.circle.fill",
            iconColor: .hakedisSuccess,
            title: "Şantiye Yönetimi",
            subtitle: "Sahadan veri girişini kolaylaştırın",
            bullets: [
                "Günlük iş girişleri ve metraj",
                "Puantaj ve işçi takibi",
                "Malzeme, ekipman ve İSG kayıtları"
            ]
        ),
        OnboardingPage(
            icon: "banknote.fill",
            iconColor: .hakedisPaid,
            title: "Finansal Kontrol",
            subtitle: "Tüm finans süreçleri parmak ucunuzda",
            bullets: [
                "Hakediş ve ödeme takibi",
                "Fiyat farkı ve nakit akış analizi",
                "EVM maliyet kontrol sistemi"
            ]
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconColor: .hakedisSuccess,
            title: "Başlayalım",
            subtitle: "Şirket bilginizi girerek başlayın",
            bullets: []
        )
    ]
}

// MARK: - Info Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Spacing.section) {
            Spacer()
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.iconColor)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(page.bullets, id: \.self) { bullet in
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(page.iconColor)
                            .font(.subheadline)
                        Text(bullet)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Last Page View

private struct OnboardingLastPageView: View {
    @Binding var companyInput: String

    var body: some View {
        VStack(spacing: Spacing.section) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(.hakedisSuccess)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text("Başlayalım")
                    .font(.title.bold())
                Text("Şirket / firma adınızı girerek başlayın")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Şirket / Firma Adı", text: $companyInput)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)
                .accessibilityLabel("Şirket adı girin")

            Text("Bu bilgi PDF hakedişlerde kullanılır. Daha sonra Ayarlar'dan değiştirebilirsiniz.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
