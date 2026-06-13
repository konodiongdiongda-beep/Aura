import SwiftUI

struct MeshBackground: View {
    var body: some View {
        ZStack {
            AppColors.surface
            RadialGradient(
                colors: [AppColors.primary.opacity(0.12), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [AppColors.secondaryContainer.opacity(0.10), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [AppColors.primaryFixed.opacity(0.9), .clear],
                center: .topTrailing,
                startRadius: 80,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }
}
