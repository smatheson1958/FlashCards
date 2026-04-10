//
//  StandardDelayCountdownIndicator.swift
//  FlashCards
//
//  Reusable three-dot progress for the product-wide standard delay (`FlashCardsConstants.StandardDelay`).
//

import SwiftUI

/// Horizontally centered row of dots; each dot lights in order as `phase` advances (1…tick count).
/// Use with a task that sleeps `FlashCardsConstants.StandardDelay.nanosecondsPerTick` between phase updates.
struct StandardDelayCountdownIndicator: View {
    /// `0` = all dim; `1` = first dot lit; … up to `tickCount` = all lit.
    var phase: Int
    var activeColor: Color
    var tickCount: Int = FlashCardsConstants.StandardDelay.tickCount
    var dotDiameter: CGFloat = 9
    var dotSpacing: CGFloat = 12
    /// Unlit dots: use `inactiveColor` if set, otherwise `activeColor` at this opacity. Prefer a mid-opacity on light card fills so dots stay visible.
    var inactiveOpacity: Double = 0.22
    /// Override for dim dots (e.g. `primaryTextColor.opacity(0.35)` on a pastel card). When `nil`, derives from `activeColor` and `inactiveOpacity`.
    var inactiveColor: Color? = nil
    var accessibilityDescription: String = "Time until next action"

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(1...tickCount, id: \.self) { index in
                Circle()
                    .fill(dotColor(isLit: phase >= index))
                    .frame(width: dotDiameter, height: dotDiameter)
                    .accessibilityLabel(accessibilityDescription)
                    .accessibilityValue(
                        phase >= index
                            ? "Dot \(index) of \(tickCount), active"
                            : "Dot \(index) of \(tickCount), waiting"
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func dotColor(isLit: Bool) -> Color {
        guard isLit else {
            return inactiveColor ?? activeColor.opacity(inactiveOpacity)
        }
        return activeColor
    }
}

#Preview {
    VStack(spacing: 20) {
        StandardDelayCountdownIndicator(phase: 0, activeColor: .orange)
        StandardDelayCountdownIndicator(phase: 1, activeColor: .orange)
        StandardDelayCountdownIndicator(phase: 3, activeColor: .orange)
    }
    .padding()
}
