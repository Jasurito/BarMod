/// Control Center owns every Apple menu bar item, so its app icon says nothing
/// about which one an item is. Picks an SF Symbol from the item's description.
public enum SystemIcon {
    public static let fallback = "switch.2"

    /// Matching is English only. Other languages get `fallback`.
    private static let symbols: [(keyword: String, symbol: String)] = [
        ("wi-fi", "wifi"),
        ("wi\u{2011}fi", "wifi"),
        ("bluetooth", "antenna.radiowaves.left.and.right"),
        ("battery", "battery.75percent"),
        ("sound", "speaker.wave.2.fill"),
        ("now playing", "play.fill"),
        ("clock", "clock"),
        ("focus", "moon.fill"),
        ("display", "display"),
        ("screen mirroring", "airplayvideo"),
        ("keyboard", "keyboard"),
    ]

    public static func symbolName(forDescription description: String) -> String {
        let lowercased = description.lowercased()
        return symbols.first { lowercased.contains($0.keyword) }?.symbol ?? fallback
    }
}
