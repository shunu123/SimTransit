import SwiftUI

struct ListeningAnimationView: View {
    var transcript: String = ""
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            VStack {
                Spacer()
                
                ZStack {
                    Circle()
                        .frame(width: 164, height: 164)
                        .foregroundStyle(.indigo.gradient)
                        .blendMode(.hardLight)
                        .overlay(
                            Image(systemName: "microphone.fill")
                                .font(.system(size: 50, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(radius: 5)
                        )
                    
                    PhaseAnimator([false, true]) { move in
                        Circle()
                            .strokeBorder(
                                style: StrokeStyle(
                                    lineWidth: 12,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    dash: [60, 400],
                                    dashPhase: move ? 220 : -220)
                            )
                            .frame(width: 160, height: 160)
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.indigo, .white, .purple, .mint, .white, .orange, .indigo]), startPoint: .trailing, endPoint: .leading)
                            )
                    } animation: { move in
                            .linear.speed(0.1).repeatForever(autoreverses: false)
                    }
                    
                    Circle()
                        .frame(width: 164, height: 164)
                        .foregroundStyle(.indigo.gradient)
                        // 1. Mask
                        .mask(
                            ZStack {
                                PhaseAnimator([false ,true]) { move in
                                    FluidWaveShape()
                                        .fill(Color.white)
                                        .frame(width: 200, height: 200)
                                        .opacity(0.4)
                                        .scaleEffect(x: 2)
                                        .offset(x: move ? 20 : -20, y: move ? 36 : 25)
                                } animation: { move in
                                        .easeIn(duration: 1.0).speed(0.25).repeatForever(autoreverses: true)
                                }
                                
                                PhaseAnimator([true, false]) { move in
                                    FluidWaveShape()
                                        .fill(Color.white)
                                        .frame(width: 200, height: 200)
                                        .opacity(0.6)
                                        .scaleEffect(x: 2)
                                        .offset(x: -20, y: move ? 30 : 36)
                                } animation: { move in
                                        .easeOut(duration: 1.0)
                                }
                                
                                PhaseAnimator([false, true]) { rotate in
                                    FluidWaveShape()
                                        .fill(Color.white)
                                        .frame(width: 200, height: 200)
                                        .rotationEffect(.degrees(rotate ? 10 : -10))
                                        .scaleEffect(x: 2, y: 1)
                                        .offset(y: 40)
                                } animation: { rotate in
                                        .easeInOut(duration: 1.0)
                                }
                            }
                        )
                }
                
                Spacer()
                
                Text(transcript.isEmpty ? "Listening..." : transcript)
                    .font(transcript.isEmpty ? .title2.bold() : .title3.weight(.medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                    .animation(.easeInOut, value: transcript)
            }
        }
    }
}
struct FluidWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height * 0.5))
        path.addCurve(
            to: CGPoint(x: width, y: height * 0.5),
            control1: CGPoint(x: width * 0.35, y: height * 0.2),
            control2: CGPoint(x: width * 0.65, y: height * 0.8)
        )
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    ListeningAnimationView()
}
