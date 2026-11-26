import Foundation

/// Sound effect preset (JBL app: Sound Effect card). Feature 0x14 in AA 06 frames, value <status> <type>.
enum SoundEffect: UInt8, CaseIterable, Identifiable {
    case natural = 0
    case treble = 1
    case bass = 2

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .natural: return String(localized: "Natural")
        case .treble: return String(localized: "Treble Boost")
        case .bass: return String(localized: "Bass Boost")
        }
    }

    /// AA 06 06 00 | 00 (set) | 00 14 (feature) | 02 (len) | 01 (status, as the JBL app sends) <type>
    var command: [UInt8] { [0xAA, 0x06, 0x06, 0x00, 0x00, 0x00, 0x14, 0x02, 0x01, rawValue] }
}

/// Smart Audio & Video profiles (JBL "SmartSwitch", command AA 80): codec bitrates and latency.
/// Values come from the JBL app's product list for the Tune Flex 2.
enum SmartAVMode: CaseIterable, Identifiable {
    case normal, audio, video

    var id: Self { self }

    var title: String {
        switch self {
        case .normal: return String(localized: "Normal")
        case .audio: return String(localized: "Audio")
        case .video: return String(localized: "Video")
        }
    }

    var summary: String {
        switch self {
        case .normal: return String(localized: "Balanced quality and latency.")
        case .audio: return String(localized: "Higher quality for music.")
        case .video: return String(localized: "Lower latency for video and calls.")
        }
    }

    /// AAC kbps, SBC bitpool, latency ms.
    var values: (aac: UInt16, sbc: UInt16, latency: UInt16) {
        switch self {
        case .normal: return (197, 46, 280)
        case .audio: return (256, 46, 280)
        case .video: return (197, 46, 120)
        }
    }

    init?(aac: UInt16, sbc: UInt16, latency: UInt16) {
        guard let match = SmartAVMode.allCases.first(where: { $0.values == (aac, sbc, latency) }) else { return nil }
        self = match
    }

    /// AA 80 09 00 <aac LE16> <sbc LE16> <latency LE16> <latency2 LE16 = FFFF, unused>
    var command: [UInt8] {
        let v = values
        return [0xAA, 0x80, 0x09, 0x00] + le(v.aac) + le(v.sbc) + le(v.latency) + [0xFF, 0xFF]
    }

    private func le(_ x: UInt16) -> [UInt8] { [UInt8(x & 0xFF), UInt8(x >> 8)] }
}

/// Which earbuds are beeping (Find My Buds, command AA 23).
struct BeepState: Equatable {
    var left = false
    var right = false
    var any: Bool { left || right }

    /// AA 23 03 00 <left> <right>: 1 = beep, 0 = stop, FF = leave as is.
    static func command(left: Bool?, right: Bool?) -> [UInt8] {
        func b(_ v: Bool?) -> UInt8 { v.map { $0 ? 1 : 0 } ?? 0xFF }
        return [0xAA, 0x23, 0x03, 0x00, b(left), b(right)]
    }
}

/// Ambient Aware strength. The JBL app shows 7 steps; the earbuds accept 0...6 and ignore 7.
let ambientLevelRange = 0...6
