import SwiftUI

/// Ultra-clean warm "hay" palette and layout metrics.
enum Style {
    /// The hay-colored board background.
    static let hay = Color(red: 0.937, green: 0.902, blue: 0.780)      // #EFE6C7
    /// Slightly deeper hay for hover/target highlights.
    static let hayDeep = Color(red: 0.885, green: 0.840, blue: 0.690)

    static let text = Color(red: 0.28, green: 0.26, blue: 0.17)
    static let secondary = Color(red: 0.55, green: 0.51, blue: 0.37)
    static let line = Color(red: 0.35, green: 0.31, blue: 0.18).opacity(0.18)
    static let red = Color(red: 0.85, green: 0.18, blue: 0.14)
    /// The modal cursor highlight (vim selection).
    static let focus = Color(red: 0.30, green: 0.44, blue: 0.87)

    static let cardWhite = Color.white

    static let cornerWidth: CGFloat = 180
    static let sidePadding: CGFloat = 20
    static let minCellWidth: CGFloat = 280
}

/// Hairline divider (horizontal or vertical).
struct Hairline: View {
    var vertical: Bool = false

    var body: some View {
        Rectangle()
            .fill(Style.line)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}