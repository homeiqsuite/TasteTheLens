import SwiftUI

struct SplashView: View {
    @Binding var isPresented: Bool
    @State private var showTitle = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            Theme.darkBg
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Taste The Lens")
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .opacity(showTitle ? 1 : 0)
                    .scaleEffect(showTitle ? 1 : 0.9)

                Text("What does the world taste like?")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .opacity(showTagline ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showTitle = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                showTagline = true
            }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.5)) {
                    isPresented = false
                }
            }
        }
    }
}
