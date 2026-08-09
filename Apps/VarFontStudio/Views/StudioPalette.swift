import AppKit
import SwiftUI

// MARK: - StudioPalette
//
// Chromatic accent families from Tailwind CSS v4 (`theme.css` OKLCH → sRGB hex).
// Prefer role tokens on `StudioColors` at call sites; reach for `StudioPalette`
// only when binding a new semantic role.
//
// Neutrals (slate/gray/zinc/…) stay out — panel chrome uses Apple system labels
// and `StudioPrimaryWash` / opaque panel washes.
//
// ## Step guidance (light / dark)
// One scale per family (50 lightest → 950 darkest). Pick different steps for
// light vs dark appearance via `color(_:light:dark:)`:
// - **Primary** mark: richest step that still clears WCAG 3:1 non-text (often
//   600 in light / 300–400 in dark).
// - **Secondary**: mid step in the same family.
// - **Tertiary** (sparse): lightest legible step.
// Exemplar: `statFormat1/2/3` = purple primary / secondary / tertiary.
//
// Soft fills / banners: 50–200 in light, 800–950 in dark.
// Solid CTAs: 300–500 in light, 500–600 in dark (verify label contrast).

enum StudioPalette {
    /// Tailwind v4 chromatic families.
    enum Family: String, CaseIterable, Sendable {
        case red
        case orange
        case amber
        case yellow
        case lime
        case green
        case emerald
        case teal
        case cyan
        case sky
        case blue
        case indigo
        case violet
        case purple
        case fuchsia
        case pink
        case rose
        case neutral
        case stone
        case paper
        case ink
    }

    /// Tailwind shade steps 50 (lightest) … 950 (darkest).
    enum Step: Int, CaseIterable, Sendable {
        case s50 = 50
        case s100 = 100
        case s200 = 200
        case s300 = 300
        case s400 = 400
        case s500 = 500
        case s600 = 600
        case s700 = 700
        case s800 = 800
        case s900 = 900
        case s950 = 950
    }

    /// Dynamic sRGB color for a family × step pair (different steps per appearance).
    static func color(_ family: Family, light: Step, dark: Step) -> Color {
        let lightRGB = rgb(family, step: light)
        let darkRGB = rgb(family, step: dark)
        return makeDynamic(
            name: "\(family.rawValue).L\(light.rawValue).D\(dark.rawValue)",
            light: lightRGB,
            dark: darkRGB
        )
    }

    /// Convenience when light and dark use the same step number.
    static func color(_ family: Family, step: Step) -> Color {
        color(family, light: step, dark: step)
    }

    private static func rgb(_ family: Family, step: Step) -> (r: Double, g: Double, b: Double) {
        let index = Step.allCases.firstIndex(of: step) ?? 0
        return Self.hexToRGB(hexes(family)[index])
    }

    /// Official Tailwind v4 OKLCH stops converted to sRGB hex (clamped).
    private static func hexes(_ family: Family) -> [String] {
        // Order: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950
        switch family {
        case .red:
            return ["#FEF2F2", "#FFE2E2", "#FFC9C9", "#FFA2A2", "#FF6467", "#FB2C36", "#E7000B", "#C10007", "#9F0712", "#82181A", "#460809"]
        case .orange:
            return ["#FFF7ED", "#FFEDD4", "#FFD6A7", "#FFB86A", "#FF8904", "#FF6900", "#F54900", "#CA3500", "#9F2D00", "#7E2A0C", "#441306"]
        case .amber:
            return ["#FFFBEB", "#FEF3C6", "#FEE685", "#FFD230", "#FFB900", "#FE9A00", "#E17100", "#BB4D00", "#973C00", "#7B3306", "#461901"]
        case .yellow:
            return ["#FEFCE8", "#FEF9C2", "#FFF085", "#FFDF20", "#FDC700", "#F0B100", "#D08700", "#A65F00", "#894B00", "#733E0A", "#432004"]
        case .lime:
            return ["#F7FEE7", "#ECFCCA", "#D8F999", "#BBF451", "#9AE600", "#7CCF00", "#5EA500", "#497D00", "#3C6300", "#35530E", "#192E03"]
        case .green:
            return ["#F0FDF4", "#DCFCE7", "#B9F8CF", "#7BF1A8", "#05DF72", "#00C950", "#00A63E", "#008236", "#016630", "#0D542B", "#032E15"]
        case .emerald:
            return ["#ECFDF5", "#D0FAE5", "#A4F4CF", "#5EE9B5", "#00D492", "#00BC7D", "#009966", "#007A55", "#006045", "#004F3B", "#002C22"]
        case .teal:
            return ["#F0FDFA", "#CBFBF1", "#96F7E4", "#46ECD5", "#00D5BE", "#00BBA7", "#009689", "#00786F", "#005F5A", "#0B4F4A", "#022F2E"]
        case .cyan:
            return ["#ECFEFF", "#CEFAFE", "#A2F4FD", "#53EAFD", "#00D3F2", "#00B8DB", "#0092B8", "#007595", "#005F78", "#104E64", "#053345"]
        case .sky:
            return ["#F0F9FF", "#DFF2FE", "#B8E6FE", "#74D4FF", "#00BCFF", "#00A6F4", "#0084D1", "#0069A8", "#00598A", "#024A70", "#052F4A"]
        case .blue:
            return ["#EFF6FF", "#DBEAFE", "#BEDBFF", "#8EC5FF", "#51A2FF", "#2B7FFF", "#155DFC", "#1447E6", "#193CB8", "#1C398E", "#162456"]
        case .indigo:
            return ["#EEF2FF", "#E0E7FF", "#C6D2FF", "#A3B3FF", "#7C86FF", "#615FFF", "#4F39F6", "#432DD7", "#372AAC", "#312C85", "#1E1A4D"]
        case .violet:
            return ["#F5F3FF", "#EDE9FE", "#DDD6FF", "#C4B4FF", "#A684FF", "#8E51FF", "#7F22FE", "#7008E7", "#5D0EC0", "#4D179A", "#2F0D68"]
        case .purple:
            return ["#FAF5FF", "#F3E8FF", "#E9D4FF", "#DAB2FF", "#C27AFF", "#AD46FF", "#9810FA", "#8200DB", "#6E11B0", "#59168B", "#3C0366"]
        case .fuchsia:
            return ["#FDF4FF", "#FAE8FF", "#F6CFFF", "#F4A8FF", "#ED6AFF", "#E12AFB", "#C800DE", "#A800B7", "#8A0194", "#721378", "#4B004F"]
        case .pink:
            return ["#FDF2F8", "#FCE7F3", "#FCCEE8", "#FDA5D5", "#FB64B6", "#F6339A", "#E60076", "#C6005C", "#A3004C", "#861043", "#510424"]
        case .rose:
            return ["#FFF1F2", "#FFE4E6", "#FFCCD3", "#FFA1AD", "#FF637E", "#FF2056", "#EC003F", "#C70036", "#A50036", "#8B0836", "#4D0218"]
        case .neutral:
            return ["#FAFAFA", "#F5F5F5", "#E5E5E5", "#D4D4D4", "#A3A3A3", "#737373", "#525252", "#404040", "#262626", "#171717", "#0A0A0A"]
        case .stone:
            return ["#FAFAF9", "#F5F5F4", "#E7E5E4", "#D6D3D1", "#A8A29E", "#78716C", "#57534E", "#44403C", "#292524", "#1C1917", "#0C0A09"]
        case .paper:
            return ["#fffdf9", "#f1eee9", "#e2dfd8","#d4d0c8", "#c5c1b8", "#b7b2a8", "#a9a297", 
            "9a9387", "#8c8477", "#7d7566", "#6f6656"]
        case .ink:
            return ["#231e15", "#211c14", "#1f1a12", "#1c1811", "#1a1610", "#18140f", "#16130d", "#14110c", "#110f0b", "#0f0d09", "#0d0b08"]
        }
    }

    private static func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            return (0, 0, 0)
        }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return (r, g, b)
    }

    private static func makeDynamic(
        name: String,
        light: (r: Double, g: Double, b: Double),
        dark: (r: Double, g: Double, b: Double)
    ) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name("Studio.Palette.\(name)"), dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let stop = isDark ? dark : light
            return NSColor(srgbRed: stop.r, green: stop.g, blue: stop.b, alpha: 1)
        }))
    }
}
