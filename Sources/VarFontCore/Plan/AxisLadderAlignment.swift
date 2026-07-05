import Foundation

/// Tags that support reference/native coordinate display (wght, wdth). No plan warnings are emitted.
public enum AxisLadderAlignment {
    public static let supportedTags: Set<String> = ["wght", "wdth"]

    public static func supportsAlignment(_ tag: String) -> Bool {
        supportedTags.contains(tag)
    }
}
