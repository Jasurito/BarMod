import BarModCore
import Testing

// Descriptions as reported on macOS 26. Wi-Fi uses a non-breaking hyphen.
@Test func measuredDescriptionsMapToSymbols() {
    #expect(SystemIcon.symbolName(forDescription: "Wi\u{2011}Fi, connected, 3 bars") == "wifi")
    #expect(SystemIcon.symbolName(forDescription: "Battery") == "battery.75percent")
    #expect(SystemIcon.symbolName(forDescription: "Sound") == "speaker.wave.2.fill")
    #expect(SystemIcon.symbolName(forDescription: "Now Playing") == "play.fill")
    #expect(SystemIcon.symbolName(forDescription: "Clock") == "clock")
}

@Test func plainHyphenWiFiMatches() {
    #expect(SystemIcon.symbolName(forDescription: "Wi-Fi") == "wifi")
}

@Test func unknownDescriptionFallsBack() {
    #expect(SystemIcon.symbolName(forDescription: "") == SystemIcon.fallback)
    #expect(SystemIcon.symbolName(forDescription: "Something New") == SystemIcon.fallback)
}
