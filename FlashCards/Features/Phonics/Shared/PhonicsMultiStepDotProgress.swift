//
//  PhonicsMultiStepDotProgress.swift
//  FlashCards
//
//  Blue fill for completed + current step; black for upcoming. First dot is blue on step 0; second turns blue on step 1.
//

import SwiftUI

struct PhonicsMultiStepDotProgress: View {
    /// Zero-based index of the word currently shown (0 = first word).
    let activeIndex: Int
    let stepCount: Int

    private static let dotDiameter: CGFloat = 24
    private static let dotSpacing: CGFloat = 28

    var body: some View {
        HStack(spacing: Self.dotSpacing) {
            ForEach(0..<stepCount, id: \.self) { index in
                Circle()
                    .fill(index <= activeIndex ? Color.blue : Color.black)
                    .frame(width: Self.dotDiameter, height: Self.dotDiameter)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Word \(activeIndex + 1) of \(stepCount)")
    }
}
