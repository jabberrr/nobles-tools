/// A small seeded random number generator (SplitMix64), so effects scatter the same way on every
/// run and in every snapshot.
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A generator for one combination of values, e.g. a particle and a moment.
    init(_ first: Int, _ second: Int) {
        state = (UInt64(truncatingIfNeeded: first) &* 0xD1B5_4A32_D192_ED03) ^ UInt64(truncatingIfNeeded: second)
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }

    /// A value in `range`.
    mutating func value(in range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    /// Either sign, as a factor.
    mutating func sign() -> Double {
        Bool.random(using: &self) ? 1 : -1
    }
}
