import AppKit
import SwiftUI

// MARK: - StudioPalette
//
// Shared accent families from the VarFont Studio palette review.
// Prefer role tokens on `StudioColors` at call sites; reach for `StudioPalette`
// only when binding a new semantic role.
//
// ## Step guidance (light / dark)
// - **Primary** (common / strongest mark): richest step that still clears the
//   role contrast floor — for marks, WCAG 3:1 non-text; for Text, 4.5:1.
// - **Secondary**: mid step in the same family.
// - **Tertiary** (sparse): lightest legible step in the family.
// Exemplar: `statFormat1/2/3` = purple primary / secondary / tertiary.
//
// Do not use `.forestGreen` until its dark export is re-checked in Figma
// (currently byte-identical to light — likely an export artifact).

enum StudioPalette {
    enum Family: String, CaseIterable, Sendable {
        case pink
        case jamPink
        case magenta
        case purple
        case violet
        case indigo
        case royalBlue
        case blue
        case cyan
        case teal
        case jadeGreen
        case emeraldGreen
        case forestGreen
        case green
        case brown
        case orange
        case red
    }

    /// Palette steps 100 (lightest) … 900 (darkest) within a family.
    enum Step: Int, CaseIterable, Sendable {
        case s100 = 100
        case s200 = 200
        case s300 = 300
        case s400 = 400
        case s500 = 500
        case s600 = 600
        case s700 = 700
        case s800 = 800
        case s900 = 900
    }

    /// Dynamic sRGB color for a family × step pair.
    static func color(_ family: Family, light: Step, dark: Step) -> Color {
        let lightRGB = rgb(family, step: light, appearance: .light)
        let darkRGB = rgb(family, step: dark, appearance: .dark)
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

    private enum Appearance { case light, dark }

    private static func rgb(_ family: Family, step: Step, appearance: Appearance) -> (r: Double, g: Double, b: Double) {
        let index = Step.allCases.firstIndex(of: step) ?? 0
        let hexes = appearance == .light ? lightHexes(family) : darkHexes(family)
        return Self.hexToRGB(hexes[index])
    }

    private static func lightHexes(_ family: Family) -> [String] {
        switch family {
        case .pink: return ["#F7B6CB", "#ED5A8B", "#EA437B", "#E82C6A", "#E1195C", "#CA1652", "#B31449", "#9C1140", "#850F36"]
        case .jamPink: return ["#F5ADDD", "#EA53B7", "#E73CAE", "#E425A4", "#D51A97", "#BF1887", "#A81577", "#911267", "#7B0F57"]
        case .magenta: return ["#E7A1E8", "#D24ED4", "#CD3ACF", "#BF2FC1", "#AB2AAC", "#962598", "#822083", "#6E1B6F", "#59165A"]
        case .purple: return ["#D19BEE", "#A943DF", "#9F2EDC", "#9223CD", "#821FB7", "#731BA1", "#63188C", "#541476", "#441060"]
        case .violet: return ["#B8A0F9", "#9675F0", "#855EED", "#7347EB", "#6230E8", "#5019E6", "#4817CF", "#4014B8", "#3812A1"]
        case .indigo: return ["#A8A8FA", "#7171FF", "#5757FF", "#3E3EFF", "#2424FF", "#0B0BFE", "#0101EF", "#0000D6", "#0000B2"]
        case .royalBlue: return ["#6B9BFA", "#4380F9", "#256CF8", "#0858F7", "#074FDF", "#0646C6", "#053DAD", "#053594", "#042872"]
        case .blue: return ["#6BB3FA", "#0880F7", "#0773DF", "#0666C6", "#0559AD", "#054D94", "#044586", "#03386D", "#032B54"]
        case .cyan: return ["#61C7FA", "#07A1ED", "#0790D5", "#067FBC", "#056FA3", "#045E8B", "#044D72", "#033C59", "#022C40"]
        case .teal: return ["#51D6D6", "#14ADAD", "#139F9F", "#129696", "#108484", "#0E7777", "#0B6060", "#0A5151", "#073B3B"]
        case .jadeGreen: return ["#51D6AA", "#15B27E", "#14AA79", "#12966A", "#0F7F5A", "#0C684A", "#0A513A", "#073B29", "#042419"]
        case .emeraldGreen: return ["#73CF91", "#33B45E", "#30AB59", "#2B974F", "#258344", "#206F3A", "#1A5B30", "#144825", "#0F341B"]
        case .forestGreen: return ["#73CF73", "#39AF39", "#2EA32E", "#2B972B", "#258325", "#206F20", "#1A5B1A", "#144814", "#0F340F"]
        case .green: return ["#91CF73", "#5FB434", "#55A32E", "#4F972B", "#448325", "#3A6F20", "#305B1A", "#254814", "#1B340F"]
        case .brown: return ["#E4B99B", "#CD824C", "#C87438", "#B46832", "#A05D2C", "#844C24", "#6C3E1E", "#5C3519", "#482A14"]
        case .orange: return ["#F1B87E", "#E77D13", "#D07011", "#B8630F", "#A0570D", "#894A0B", "#713D09", "#5A3007", "#422405"]
        case .red: return ["#F0999D", "#E43F3F", "#E02F29", "#D2271E", "#BC251B", "#A52118", "#8F1C14", "#791811", "#63130E"]
        }
    }

    private static func darkHexes(_ family: Family) -> [String] {
        switch family {
        case .pink: return ["#EFBECE", "#DA6C91", "#D55882", "#D04372", "#C83264", "#B42D5A", "#9F2850", "#8B2345", "#761E3B"]
        case .jamPink: return ["#EFBEDE", "#DA6CB6", "#D558AB", "#D043A1", "#C83296", "#B42D87", "#9F2877", "#8B2368", "#761E59"]
        case .magenta: return ["#DCACDC", "#BD64BE", "#B552B7", "#A847A9", "#963F97", "#843885", "#723073", "#602961", "#4E214F"]
        case .purple: return ["#CCACDC", "#9F64BE", "#9452B7", "#8747A9", "#783F97", "#6A3885", "#5C3073", "#4D2961", "#3F214F"]
        case .violet: return ["#BCAAEF", "#9D85E0", "#8D70DB", "#7D5CD6", "#6C47D1", "#5C33CC", "#532EB8", "#4A29A3", "#41248F"]
        case .indigo: return ["#B1B1F1", "#7F7FF0", "#6868EE", "#5151EB", "#3A3AE9", "#2323E6", "#1919D7", "#1616C0", "#1313A9"]
        case .royalBlue: return ["#7AA0EB", "#5686E6", "#3C73E2", "#2160DE", "#1E56C8", "#1B4DB1", "#17439B", "#143A85", "#0F2C66"]
        case .blue: return ["#7AB3EB", "#2180DE", "#1E73C8", "#1B66B1", "#17599B", "#144D85", "#124578", "#0F3862", "#0B2B4B"]
        case .cyan: return ["#71C2EA", "#2099D5", "#1D89BF", "#1979A9", "#166992", "#13597C", "#0F4966", "#0C3950", "#09293A"]
        case .teal: return ["#66C1C1", "#289999", "#258E8E", "#228585", "#1E7676", "#1B6969", "#165555", "#134848", "#0D3434"]
        case .jadeGreen: return ["#66C1A3", "#299E77", "#279772", "#228564", "#1D7155", "#185D46", "#134837", "#0D3427", "#082018"]
        case .emeraldGreen: return ["#85BC98", "#4A9D66", "#469561", "#3E8455", "#36724A", "#2E613F", "#265034", "#1D3E28", "#152D1D"]
        case .forestGreen: return ["#73CF73", "#39AF39", "#2EA32E", "#2B972B", "#258325", "#206F20", "#1A5B1A", "#144814", "#0F340F"]
        case .green: return ["#85BC85", "#4B9D4B", "#438E43", "#3E843E", "#367236", "#2E612E", "#265026", "#1D3E1D", "#152D15"]
        case .brown: return ["#D7BCA8", "#B78562", "#AE7851", "#9D6C49", "#8C6041", "#734F35", "#5E412C", "#503725", "#3F2B1D"]
        case .orange: return ["#E3B88C", "#CE7D2C", "#B97027", "#A46323", "#8F571E", "#7A4A1A", "#653D15", "#503011", "#3B240C"]
        case .red: return ["#E5A8A4", "#CE5D55", "#C84A42", "#BA3E36", "#A63830", "#93312B", "#7F2B25", "#6B241F", "#571D19"]
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
