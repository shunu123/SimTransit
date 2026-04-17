import SwiftUI

struct BusResultCard: View {
    let bus: Bus
    let from: String
    let to: String
    let action: () -> Void
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        VStack(spacing: 0) {
            // ── Top Bar: Bus No & Duration ──
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text(bus.number)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(theme.current.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if bus.isNightOwl {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.indigo)
                    }
                }
                
                Spacer()
                
                Text(bus.durationText)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.current.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Main Content: Compact Vertical Timeline ──
            HStack(alignment: .top, spacing: 16) {
                // Vertical Timeline Line
                VStack(spacing: 0) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Rectangle()
                        .fill(theme.current.border.opacity(0.5))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                    
                    Circle()
                        .fill(theme.current.accent)
                        .frame(width: 8, height: 8)
                }
                .padding(.vertical, 4)
                
                // Destination & Times
                VStack(alignment: .leading, spacing: 18) {
                    // Departure
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bus.route.from)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.current.text)
                            Text("Departure")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.current.secondaryText.opacity(0.6))
                                .textCase(.uppercase)
                        }
                        Spacer()
                        Text(bus.departsAt)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.current.text)
                    }
                    
                    // Next Stop / Live Status (Hidden if same as Destination)
                    if let nextName = bus.nextStopName, nextName.lowercased() != to.lowercased() {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nextName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.current.secondaryText)
                                Text("Next Stop")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(theme.current.secondaryText.opacity(0.6))
                                    .textCase(.uppercase)
                            }
                            Spacer()
                            Text(bus.nextStopETA)
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.current.secondaryText)
                        }
                    }
                    
                    // Destination Arrival
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bus.route.to)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(theme.current.text)
                            Text("Arrival")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.current.secondaryText.opacity(0.6))
                                .textCase(.uppercase)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(bus.arrivalsAt)
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .foregroundStyle(theme.current.accent)
                            
                            // Inline Status Badge
                            let delayText = bus.delayLabel
                            let isDelay = delayText.contains("delayed")
                            
                            Text(delayText.uppercased())
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isDelay ? Color.red : Color.green)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // ── Footer: Minimalist Action ──
            HStack {
                Spacer()
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text("Track")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.current.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.current.accent.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(theme.current.card)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(theme.current.border.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }
}
