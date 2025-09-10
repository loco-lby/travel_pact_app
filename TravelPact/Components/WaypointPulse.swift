import SwiftUI

struct WaypointPulse: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.8),
                            Color.purple.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
                .scaleEffect(scale)
                .opacity(opacity)
            
            Circle()
                .fill(Color.purple)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                scale = 1.5
                opacity = 0.3
            }
        }
    }
}

#Preview {
    WaypointPulse()
        .preferredColorScheme(.dark)
        .padding()
}