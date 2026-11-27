import Foundation

/// Music EQ presets. The earbuds take a full list of filters (command AA A2), not a preset name,
/// so each preset is a 10-band peaking EQ with the JBL app's gains (assets/CommonPreset.json).
/// The raw value is the EQ category the earbuds report back (0 off, 1 Jazz, 2 Vocal, 3 Bass).
enum EQPreset: UInt8, CaseIterable, Identifiable {
    case off = 0
    case jazz = 1
    case vocal = 2
    case bass = 3

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .jazz: return String(localized: "Jazz")
        case .vocal: return String(localized: "Vocal")
        case .bass: return String(localized: "Bass")
        }
    }

    static let frequencies: [Double] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    var gains: [Double] {
        switch self {
        case .off: return Array(repeating: 0, count: 10)
        case .jazz: return [4, 3, 1, 2.5, -1.5, -1.5, 0, 1, 3, 4]
        case .vocal: return [-1.5, -3, -3, 1, 3.5, 3.5, 3, 1.5, 0, -1.5]
        case .bass: return [6, 4, 3, 2.5, 0.5, 0, 0, 0, 0, 0]
        }
    }

    /// AA A2 <len LE16> 03 <category> <calibration f32> <48 kHz> <left gain f32> <right gain f32> <10>
    ///   then per band: <type 1 = peaking> <gain f32> <frequency f32> <Q × 10>
    /// Matches what the JBL app sends for this model ("QMultiply10EQ"). Floats are little-endian.
    func command(design: [EQFilter]) -> [UInt8] {
        let bands = zip(Self.frequencies, gains).map { EQFilter(type: 1, gain: $1, frequency: $0, q: 1) }
        var body: [UInt8] = [0x03, rawValue]
        body += f32(EQMath.calibration(design: design, custom: bands))
        body += [48] + f32(0) + f32(0) + [UInt8(bands.count)]
        for band in bands {
            body += [band.type] + f32(band.gain) + f32(band.frequency) + [UInt8(band.q * 10)]
        }
        return [0xAA, 0xA2, UInt8(body.count & 0xFF), UInt8(body.count >> 8)] + body
    }

    private func f32(_ value: Double) -> [UInt8] {
        withUnsafeBytes(of: Float(value).bitPattern.littleEndian, Array.init)
    }
}

/// One biquad filter, as the earbuds describe it. Type 1 = peaking, 2 = high shelf.
struct EQFilter: Equatable {
    var type: UInt8
    var gain: Double
    var frequency: Double
    var q: Double
}

enum EQMath {
    /// The earbuds' own tuning (EQ category 202), used when the earbuds haven't reported it.
    /// Read from a Tune Flex 2 on firmware 3.5.0.
    static let fallbackDesign: [EQFilter] = [
        EQFilter(type: 1, gain: 2, frequency: 60, q: 1.0), EQFilter(type: 1, gain: -8, frequency: 120, q: 0.5),
        EQFilter(type: 1, gain: -4, frequency: 200, q: 1.4), EQFilter(type: 1, gain: -12, frequency: 400, q: 0.6),
        EQFilter(type: 1, gain: -3, frequency: 1300, q: 0.7), EQFilter(type: 1, gain: 7, frequency: 3100, q: 1.5),
        EQFilter(type: 1, gain: -3, frequency: 7000, q: 1.0), EQFilter(type: 2, gain: 6, frequency: 9500, q: 1.0),
    ]

    /// Pre-gain the earbuds expect with every EQ: the peak of the combined response of their own tuning
    /// plus the chosen EQ, in dB, plus 1 dB of headroom. Reproduces the JBL app's native EqCalibration:
    /// for Jazz it gives 11.553, the value the earbuds report.
    static func calibration(design: [EQFilter], custom: [EQFilter]) -> Double {
        let filters = (design + custom).map(coefficients)
        var peak = -Double.infinity
        for i in 0...2000 {
            let f = 20 * pow(1000, Double(i) / 2000)  // 20 Hz to 20 kHz, log-spaced
            let db = filters.reduce(0) { $0 + 20 * log10(magnitude($1, at: f)) }
            peak = max(peak, db)
        }
        return peak + 1
    }

    private static let sampleRate = 48_000.0

    /// RBJ audio-EQ-cookbook biquad coefficients (b0, b1, b2, a0, a1, a2).
    private static func coefficients(_ filter: EQFilter) -> [Double] {
        let a = pow(10, filter.gain / 40)
        let w = 2 * Double.pi * filter.frequency / sampleRate
        let alpha = sin(w) / (2 * filter.q)
        let c = cos(w)
        if filter.type == 2 {  // high shelf
            let s = 2 * sqrt(a) * alpha
            return [a * ((a + 1) + (a - 1) * c + s), -2 * a * ((a - 1) + (a + 1) * c), a * ((a + 1) + (a - 1) * c - s),
                    (a + 1) - (a - 1) * c + s, 2 * ((a - 1) - (a + 1) * c), (a + 1) - (a - 1) * c - s]
        }
        return [1 + alpha * a, -2 * c, 1 - alpha * a, 1 + alpha / a, -2 * c, 1 - alpha / a]  // peaking
    }

    private static func magnitude(_ k: [Double], at frequency: Double) -> Double {
        let w = 2 * Double.pi * frequency / sampleRate
        // H(z) at z = e^{jw}: (b0 + b1 z^-1 + b2 z^-2) / (a0 + a1 z^-1 + a2 z^-2)
        func eval(_ x0: Double, _ x1: Double, _ x2: Double) -> (Double, Double) {
            (x0 + x1 * cos(w) + x2 * cos(2 * w), -(x1 * sin(w) + x2 * sin(2 * w)))
        }
        let (nr, ni) = eval(k[0], k[1], k[2])
        let (dr, di) = eval(k[3], k[4], k[5])
        return sqrt(nr * nr + ni * ni) / sqrt(dr * dr + di * di)
    }
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
