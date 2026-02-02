import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @Environment(StoreManager.self) var storeManager: StoreManager

    private enum Page: Hashable {
        case welcome
        case analytics
        case access
    }

    @State private var selection: Page = .welcome

    var body: some View {
        TabView(selection: $selection) {
            OnboardingPage(
                image: .asset("introduction"),
                title: String(localized: "Welcome to GetGrip", comment: "Onboarding welcome page title"),
                description: String(localized: "Get perfect cross-country grip recommendations based on your local weather conditions.", comment: "Onboarding welcome page description"),
                imageMaxSize: 420,
                primaryButtonTitle: String(localized: "Next", comment: "Onboarding button to proceed to next page"),
                primaryAction: {
                    goToNextPage(from: .welcome)
                }
            )
            .tag(Page.welcome)

            OnboardingPage(
                title: String(localized: "Always the best grip", comment: "Onboarding analytics page title"),
                description: String(localized: "We analyze snow type, temperature, and humidity to recommend the perfect wax or klister from Swix's full range.", comment: "Onboarding analytics page description"),
                primaryButtonTitle: String(localized: "Next", comment: "Onboarding button to proceed to next page"),
                primaryAction: {
                    goToNextPage(from: .analytics)
                }
            ) {
                OnboardingWaxCanGrid()
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .tag(Page.analytics)

            if storeManager.hasAccess {
                OnboardingPage(
                    image: .system("checkmark.seal.fill"),
                    title: String(localized: "You're All Set", comment: "Onboarding title when user already has purchase"),
                    description: String(localized: "You already have an active subscription. Enjoy full access to GetGrip!", comment: "Onboarding description when user already has purchase"),
                    primaryButtonTitle: String(localized: "Start Using App", comment: "Onboarding button to dismiss and start using app"),
                    primaryAction: {
                        showOnboarding = false
                    }
                )
                .tag(Page.access)
            } else {
                OnboardingPage(
                    image: .asset("post-introduction-background"),
                    title: String(localized: "Get started for free", comment: "Onboarding trial page title"),
                    description: String(localized: "We offer new customers a 14-day, risk-free trial. After the trial, a subscription keeps full access.", comment: "Onboarding trial page description"),
                    imageMaxSize: 420,
                    primaryButtonTitle: String(localized: "Start trial", comment: "Onboarding button to start free trial"),
                    primaryAction: {
                        Task {
                            await startTrialAndContinue()
                        }
                    }
                )
                .tag(Page.access)
            }
        }
#if os(iOS)
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
#endif
    }

    private func goToNextPage(from page: Page) {
        let next: Page
        switch page {
        case .welcome:
            next = .analytics
        case .analytics:
            next = .access
        case .access:
            next = .access
        }

        withAnimation {
            selection = next
        }
    }

    @MainActor
    private func startTrialAndContinue() async {
        if let product = storeManager.primaryProduct {
            await storeManager.purchase(product)
        }

        showOnboarding = false
    }
}

private enum OnboardingImage {
    case system(String)
    case asset(String)
}

struct OnboardingPage<Content: View>: View {
    fileprivate let image: OnboardingImage?
    let title: String
    let description: String

    /// Max size for the image area. Defaults keep the current look; can be overridden per page.
    var imageMaxSize: CGFloat = 280

    /// Primary button shown at the bottom (e.g. Next / Start Using App)
    var primaryButtonTitle: String = "Next"
    var primaryAction: (() -> Void)? = nil

    @ViewBuilder var content: Content

    /// Reserve a consistent height for the title/description block across pages.
    /// This leaves room for at least 4 lines of subtitle even if a page has shorter text.
    private let reservedTextBlockHeight: CGFloat = 170

    fileprivate init(
        image: OnboardingImage? = nil,
        title: String,
        description: String,
        imageMaxSize: CGFloat = 280,
        primaryButtonTitle: String = "Next",
        primaryAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.image = image
        self.title = title
        self.description = description
        self.imageMaxSize = imageMaxSize
        self.primaryButtonTitle = primaryButtonTitle
        self.primaryAction = primaryAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top hero area
            VStack {
                if let image {
                    Group {
                        switch image {
                        case .system(let name):
                            Image(systemName: name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundStyle(.blue)

                        case .asset(let name):
                            Image(name)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: imageMaxSize, maxHeight: imageMaxSize)
                                .accessibilityLabel(Text(title))
                        }
                    }
                } else {
                    content
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)

            // Bottom text + button area (consistent placement)
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity)
                // Reserve room for title + 4 lines of subtitle so other pages don't shift.
                .frame(height: reservedTextBlockHeight, alignment: .top)
                .padding(.horizontal)

                OnboardingPrimaryButton(title: primaryButtonTitle) {
                    primaryAction?()
                }
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
        .padding(.horizontal)
    }
}

#Preview {
    let app = AppState()

    OnboardingView(showOnboarding: .constant(true))
        .environment(app.location)
        .environment(app.weather)
        .environment(app.waxSelection)
        .environment(app.recommendation)
        .environment(app.storeManager)
}
