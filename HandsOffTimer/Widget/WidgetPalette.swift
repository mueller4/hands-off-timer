import SwiftUI

/// Color-only lock from the first Home Screen frame sheet.
/// Titles use app-icon navy in light mode. Timer glyph and countdown use `#0A84FF`.
/// No purple, indigo, or extra chrome.
enum WidgetPalette {
    /// Mail / icon accent `#0A84FF`.
    static let accent = Color(red: 10.0 / 255.0, green: 132.0 / 255.0, blue: 255.0 / 255.0)
    /// App-icon navy `~#091A46`.
    static let navy = Color(red: 9.0 / 255.0, green: 26.0 / 255.0, blue: 70.0 / 255.0)

    static func title(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .primary : navy
    }
}
