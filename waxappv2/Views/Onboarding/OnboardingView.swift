import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var storeManager: StoreManager

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
                title: "Welcome to GetGrip",
                description: "Get perfect cross-country grip recommendations based on your local weather conditions.",
                imageMaxSize: 420,
                primaryButtonTitle: "Next",
                primaryAction: {
                    goToNextPage(from: .welcome)
                }
            )
            .tag(Page.welcome)

            OnboardingPage(
                title: "Wherever You Are",
                description: "Our algorithm automatically predicts the correct grip wax or klister based on nine snow-type categories and temperature.",
                primaryButtonTitle: "Next",
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

            if storeManager.isPurchased {
                OnboardingPage(
                    image: .system("checkmark.seal.fill"),
                    title: "You're All Set",
                    description: "You already have lifetime access to WaxApp. Enjoy all features!",
                    primaryButtonTitle: "Start Using App",
                    primaryAction: {
                        showOnboarding = false
                    }
                )
                .tag(Page.access)
            } else {
                OnboardingPage(
                    image: .asset("post-introduction-background"),
                    title: "Get started for free",
                    description: "We offer new customers a 14-day, risk-free trial before the app can be unlocked with a one-time purchase.",
                    imageMaxSize: 420,
                    primaryButtonTitle: "Start trial",
                    primaryAction: {
                        showOnboarding = false
                    }
                )
                .tag(Page.access)

            }
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
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
        // Make it explicit that the trial begins upon tapping the button.
        // If purchase/trial start fails for any reason, still allow the user to continue.
        do {
            // Try to start the trial / subscription through the existing StoreManager API.
            if let product = storeManager.products.first {
                try await storeManager.purchase(product)
            }
        } catch {
            // Intentionally ignore here; user can try again from paywall later.
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
        .environmentObject(app.location)
        .environmentObject(app.weather)
        .environmentObject(app.waxSelection)
        .environmentObject(app.recommendation)
        .environmentObject(app.storeManager)
}
