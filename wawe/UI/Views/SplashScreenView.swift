import SwiftUI

struct SplashScreenView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.88

    var body: some View {
        ZStack {
            // Dark gradient: black → deep purple (matches accent)
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.03, blue: 0.06),
                    Color(red: 0.12, green: 0.05, blue: 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App name
                Text("wawe")
                    .font(.system(size: 48, weight: .thin, design: .default))
                    .tracking(12)
                    .foregroundStyle(.white)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale)

                Spacer()

                // Subtle tagline at bottom
                Text("учи английский")
                    .font(.system(size: 13, weight: .light))
                    .tracking(4)
                    .foregroundStyle(Color.white.opacity(0.35))
                    .opacity(logoOpacity)
                    .padding(.bottom, 52)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                logoOpacity = 1
                logoScale   = 1
            }
        }
    }
}
