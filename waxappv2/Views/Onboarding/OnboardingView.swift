import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @EnvironmentObject var storeManager: StoreManager
    
    var body: some View {
        TabView {
            OnboardingPage(
                image: "snowflake",
                title: "Welcome to WaxApp",
                description: "Get perfect ski wax recommendations based on real-time weather data."
            )
            
            OnboardingPage(
                image: "chart.xyaxis.line",
                title: "Advanced Analytics",
                description: "Visualize temperature trends and plan your skiing with our Gantt charts."
            )
            
            if storeManager.isPurchased {
                OnboardingPage(
                    image: "checkmark.seal.fill",
                    title: "You're All Set",
                    description: "You already have lifetime access to WaxApp. Enjoy all features!",
                    isLastPage: true,
                    action: {
                        showOnboarding = false
                    }
                )
            } else {
                OnboardingPage(
                    image: "lock.open.fill", // Or distinct symbol for trial
                    title: "14-Day Free Trial",
                    description: "Enjoy full access for 14 days. After the trial, a one-time purchase is required to continue using the app.",
                    isLastPage: true,
                    action: {
                        showOnboarding = false
                    }
                )
            }
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
}

struct OnboardingPage: View {
    let image: String
    let title: String
    let description: String
    var isLastPage: Bool = false
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if isLastPage {
                Button(action: {
                    action?()
                }) {
                    Text("Start Using App")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            } else {
                // Spacer to balance layout against the button on the last page
                Spacer()
                    .frame(height: 50)
            }
        }
        .padding()
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
