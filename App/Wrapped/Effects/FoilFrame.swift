import SwiftUI

/// The foil at one moment, drawn into canvases: the sheet that's left, and the pieces in flight.
///
/// While it waits, the sheet breathes, wiggles every few seconds, and its light drifts so the
/// facets shift and shimmer, with a highlight sweeping across now and then. A tap shakes it.
/// Torn pieces fly from the tap, up and then down, tumbling over in 3D (a flip about a random
/// axis, shaded as they turn) while they shrink and fade.
struct FoilFrame: Sendable {
    /// What a canvas draws, and how far past the foil's frame it reaches (canvases clip): a
    /// little for the sheet's wiggle and shadow, and plenty for pieces, most of all below, where
    /// they fall.
    enum Layer: Sendable {
        case sheet
        case pieces

        var room: EdgeInsets {
            switch self {
            case .sheet: EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            case .pieces: EdgeInsets(top: 240, leading: 240, bottom: 400, trailing: 240)
            }
        }
    }

    let sheet: FoilSheet
    let state: FoilState
    /// Seconds since the reference date.
    let time: TimeInterval
    /// Whether the sheet breathes, wiggles, and catches the sweeping highlight.
    let isIdle: Bool
    /// Pieces fade where they are instead of flying, and the sheet doesn't shake.
    let reduceMotion: Bool

    /// Draws `layer` into a canvas of `size`, which includes the layer's room.
    func draw(_ layer: Layer, in context: GraphicsContext, size: CGSize) {
        let room = layer.room
        var context = context
        context.translateBy(x: room.leading, y: room.top)
        let foilSize = CGSize(
            width: size.width - room.leading - room.trailing,
            height: size.height - room.top - room.bottom
        )
        switch layer {
        case .sheet:
            drawSheet(in: context, size: foilSize)
        case .pieces:
            for piece in state.pieces {
                drawPiece(piece, in: context, size: foilSize)
            }
        }
    }

    // MARK: The sheet

    private func drawSheet(in context: GraphicsContext, size: CGSize) {
        let attached = sheet.facets.indices.filter { state.isAttached[$0] }
        guard !attached.isEmpty else { return }
        var context = context
        moveSheet(&context, size: size)

        let paths = attached.map { sheet.facets[$0].path(in: size) }
        var outline = Path()
        for path in paths {
            outline.addPath(path)
        }
        // The foil's thickness: a sliver of shadow below its edges, over the content.
        context.fill(outline.offsetBy(dx: 0, dy: 1.5), with: .color(.black.opacity(0.25)))

        let highlight = highlightPosition
        for (index, path) in zip(attached, paths) {
            let facet = sheet.facets[index]
            fill(facet, path: path, around: facet.center(in: size), taps: state.taps, exposure: 1, in: context, size: size)
            if let highlight {
                let along = Double(facet.center.x + facet.center.y) / 2
                let nearness = max(0, 1 - abs(along - highlight) / 0.14)
                let shine = nearness * nearness * facet.glint * 0.75
                if shine > 0.02 {
                    context.fill(path, with: .color(.white.opacity(shine)))
                }
            }
        }
        // Creases: a dark fold with a bright ridge beside it.
        context.stroke(outline.offsetBy(dx: 0.4, dy: 0.6), with: .color(.black.opacity(0.16)), lineWidth: 0.8)
        context.stroke(outline, with: .color(.white.opacity(0.55)), lineWidth: 0.45)
    }

    /// Breathing and an inviting wiggle while idle (quieter just after a tap), and a quick
    /// damped shake right after one.
    private func moveSheet(_ context: inout GraphicsContext, size: CGSize) {
        var angle = 0.0
        var scale = 1.0
        var shift = 0.0
        if isIdle {
            let settled = state.lastTapTime.map { min(max((time - $0) / 2, 0), 1) } ?? 1
            scale += 0.006 * sin(time * 2.6)
            let wiggle = time.truncatingRemainder(dividingBy: 3.6) / 0.7
            if wiggle < 1 {
                let envelope = sin(Double.pi * wiggle) * settled
                angle += 1.5 * envelope * sin(wiggle * 4 * Double.pi)
                scale += 0.02 * envelope
            }
        }
        if let tapTime = state.lastTapTime, !reduceMotion {
            let since = time - tapTime
            if since >= 0 && since < 0.6 {
                let damping = exp(-7 * since)
                shift = 4.5 * damping * sin(since * 22 * Double.pi)
                angle += 1.2 * damping * sin(since * 16 * Double.pi + 1)
                scale -= 0.015 * damping
            }
        }
        guard angle != 0 || scale != 1 || shift != 0 else { return }
        let midX = Double(size.width) / 2
        let midY = Double(size.height) / 2
        context.translateBy(x: CGFloat(midX + shift), y: CGFloat(midY))
        context.rotate(by: .degrees(angle))
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        context.translateBy(x: CGFloat(-midX), y: CGFloat(-midY))
    }

    /// Where the light comes from: the upper left, drifting while the foil waits.
    private var lightAngle: Double {
        -0.75 * Double.pi + (isIdle ? 0.5 * sin(time * 0.6) : 0)
    }

    /// The sweeping highlight's place along the sheet's diagonal (0 at the top left, 1 at the
    /// bottom right), or `nil` between sweeps.
    private var highlightPosition: Double? {
        guard isIdle else { return nil }
        let progress = (time + 1.3).truncatingRemainder(dividingBy: 4.6) / 1.1
        guard progress < 1 else { return nil }
        return -0.25 + 1.5 * progress * progress * (3 - 2 * progress)
    }

    // MARK: Pieces

    /// How long a piece takes to fade under Reduce Motion.
    private static let fadeDuration: TimeInterval = 0.35

    private func drawPiece(_ piece: FoilPiece, in context: GraphicsContext, size: CGSize) {
        let facet = sheet.facets[piece.facet]
        let elapsed = max(time - piece.start, 0)
        let progress = elapsed / (reduceMotion ? Self.fadeDuration : piece.duration)
        guard progress < 1 else { return }
        let center = facet.center(in: size)
        let path = facet.centeredPath(in: size)
        var context = context

        guard !reduceMotion else {
            context.opacity = 1 - progress
            context.translateBy(x: center.x, y: center.y)
            fill(facet, path: path, around: .zero, taps: piece.taps, exposure: 1, in: context, size: size)
            return
        }

        let flight = Flight(piece: piece, facet: facet, size: size)
        let eased = 1 - (1 - progress) * (1 - progress)
        let lift = sin(Double.pi * min(progress / 0.5, 1))
        let scale = (1 + 0.18 * lift) * (1 - 0.5 * progress * progress)
        let tumble = flight.turns * eased
        let facing = cos(tumble)
        let flip = facing < 0 ? min(facing, -0.05) : max(facing, 0.05)

        context.opacity = progress < 0.5 ? 1 : 1 - (progress - 0.5) / 0.5
        context.translateBy(
            x: CGFloat(Double(center.x) + flight.directionX * flight.distance * eased),
            y: CGFloat(Double(center.y) + flight.directionY * flight.distance * eased + flight.drop * progress * progress)
        )
        context.rotate(by: .radians(flight.spin * eased + flight.axis))
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale * flip))
        context.rotate(by: .radians(-flight.axis))

        // Brightest face-on, dimmer edge-on, and a little duller on its back.
        let exposure = (0.6 + 0.4 * abs(facing)) * (facing < 0 ? 0.88 : 1)
        fill(facet, path: path, around: .zero, taps: piece.taps, exposure: exposure, in: context, size: size)
        let glint = pow(max(0, cos(tumble - 0.9)), 14) * 0.6
        if glint > 0.02 {
            context.fill(path, with: .color(.white.opacity(glint)))
        }
        context.stroke(path, with: .color(.white.opacity(0.5)), lineWidth: 0.5)
    }

    // MARK: Shading

    /// Fills a facet with its metallic gradient, running along its lean (after `taps` crinkles)
    /// through `center`.
    private func fill(
        _ facet: FoilFacet,
        path: Path,
        around center: CGPoint,
        taps: Int,
        exposure: Double,
        in context: GraphicsContext,
        size: CGSize
    ) {
        let lean = facet.lean(afterTaps: taps)
        let tones = facet.tones(lean: lean, lightAngle: lightAngle, exposure: exposure)
        let reach = facet.radius(in: size)
        let x = Double(center.x)
        let y = Double(center.y)
        context.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [tones.shine, tones.shade]),
                startPoint: CGPoint(x: x - cos(lean) * reach, y: y - sin(lean) * reach),
                endPoint: CGPoint(x: x + cos(lean) * reach, y: y + sin(lean) * reach)
            )
        )
    }
}

/// How a torn piece flies: away from the tap, fanned out and lifted a little, then falling,
/// while it tumbles about an axis and spins.
private struct Flight {
    /// The direction it's thrown (a unit vector) and how far, in points.
    let directionX: Double
    let directionY: Double
    let distance: Double
    /// How far gravity pulls it down by the end, in points.
    let drop: Double
    /// Radians it tumbles over, the tumble axis' angle, and radians it spins flat.
    let turns: Double
    let axis: Double
    let spin: Double

    init(piece: FoilPiece, facet: FoilFacet, size: CGSize) {
        var random = SeededRandom(seed: facet.seed ^ 0xF1_1E5)
        let width = Double(size.width)
        let height = Double(size.height)
        var awayX = Double(facet.center.x - piece.tap.x) * width
        var awayY = Double(facet.center.y - piece.tap.y) * height
        let length = (awayX * awayX + awayY * awayY).squareRoot()
        if length < 1 {
            let angle = random.value(in: 0...(2 * Double.pi))
            awayX = cos(angle)
            awayY = sin(angle)
        } else {
            awayX /= length
            awayY /= length
        }
        let fan = random.value(in: -0.45...0.45)
        let thrownX = awayX * cos(fan) - awayY * sin(fan)
        let thrownY = awayX * sin(fan) + awayY * cos(fan) - 0.5
        let thrown = max((thrownX * thrownX + thrownY * thrownY).squareRoot(), 0.001)
        directionX = thrownX / thrown
        directionY = thrownY / thrown

        let side = min(width, height)
        distance = side * (piece.isBurst ? random.value(in: 0.45...0.8) : random.value(in: 0.28...0.5))
        drop = height * (piece.isBurst ? random.value(in: 0.7...1.0) : random.value(in: 0.5...0.8))
        turns = random.sign() * 2 * Double.pi * (piece.isBurst ? random.value(in: 0.8...1.8) : random.value(in: 0.6...1.4))
        axis = random.value(in: 0...Double.pi)
        spin = random.sign() * Double.pi * random.value(in: 0.3...1.2)
    }
}

private extension FoilFacet {
    typealias Tint = (red: Double, green: Double, blue: Double)

    /// The light and dark ends of its gradient: silver, brighter the more it leans toward the
    /// light, with a hint of iridescent color that shifts as the light moves. `exposure` dims it.
    func tones(lean: Double, lightAngle: Double, exposure: Double) -> (shine: Color, shade: Color) {
        let facing = cos(lean - lightAngle) * steepness
        let level = (0.76 + 0.22 * facing) * exposure
        let tint = Self.iridescentTint(at: hue + 0.15 * cos(lightAngle - lean))
        return (silver(level + 0.13, tint: tint), silver(level - 0.17, tint: tint))
    }

    private func silver(_ level: Double, tint: Tint) -> Color {
        let level = min(max(level, 0), 1)
        return Color(
            red: level * (0.95 * (1 - iridescence) + tint.red * iridescence),
            green: level * (0.97 * (1 - iridescence) + tint.green * iridescence),
            blue: level * ((1 - iridescence) + tint.blue * iridescence)
        )
    }

    /// Pink, gold, mint, sky and lavender, blended around a cycle.
    private static let iridescentTints: [Tint] = [
        (1.00, 0.78, 0.90),
        (1.00, 0.93, 0.72),
        (0.74, 1.00, 0.88),
        (0.72, 0.88, 1.00),
        (0.86, 0.78, 1.00),
    ]

    private static func iridescentTint(at hue: Double) -> Tint {
        let position = (hue - hue.rounded(.down)) * Double(iridescentTints.count)
        let index = Int(position) % iridescentTints.count
        let from = iridescentTints[index]
        let to = iridescentTints[(index + 1) % iridescentTints.count]
        let blend = position - position.rounded(.down)
        return (
            from.red + (to.red - from.red) * blend,
            from.green + (to.green - from.green) * blend,
            from.blue + (to.blue - from.blue) * blend
        )
    }
}
