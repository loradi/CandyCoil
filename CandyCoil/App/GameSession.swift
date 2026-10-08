import SwiftUI
import SpriteKit
import GameController
import Observation
import AVFoundation

@MainActor @Observable final class GameSession {
    var playing = false
    var paused = false
    var gameOver = false
    var touchBoosting = false
    var controllerBoosting = false
    var boosting: Bool { touchBoosting || controllerBoosting }
    var score = 0
    var eaten = 0
    var rank = 1
    var best = UserDefaults.standard.integer(forKey: "best")
    var controllerName: String?
    var leaderboard: [(String, Int)] = []
    var radar: [CGPoint] = []
    var reason = ""
    var discovered = Set(UserDefaults.standard.array(forKey: "discovered") as? [Int] ?? [])
    var language: GameLanguage = GameLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "english") ?? .english {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    var appearance: SnakeAppearance = {
        let colour = SnakeColour(rawValue: UserDefaults.standard.string(forKey: "snakeColour") ?? "mint") ?? .mint
        let face = SnakeFace(rawValue: UserDefaults.standard.string(forKey: "snakeFace") ?? "classic") ?? .classic
        let pattern = SnakePattern(rawValue: UserDefaults.standard.string(forKey: "snakePattern") ?? "racingStripes") ?? .racingStripes
        return SnakeAppearance(colour: colour, face: face, pattern: pattern)
    }() {
        didSet {
            UserDefaults.standard.set(appearance.colour.rawValue, forKey: "snakeColour")
            UserDefaults.standard.set(appearance.face.rawValue, forKey: "snakeFace")
            UserDefaults.standard.set(appearance.pattern.rawValue, forKey: "snakePattern")
        }
    }
    let account = AccountSession()
    let social = SocialLobby()
    @ObservationIgnored let audio = GameAudio()
    @ObservationIgnored var scene: ArenaScene?
    @ObservationIgnored private var arena: Arena?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastInventoryCount = 0
    init() {
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refreshController() })
        }
        refreshController()
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    func refreshController() {
        guard let controller = GCController.controllers().first else { controllerName = nil; return }
        controllerName = controller.vendorName ?? controller.productCategory
    }
    func start() {
        let arena = Arena(playerPattern: appearance.pattern)
        self.arena = arena
        scene = ArenaScene(arena: arena, session: self)
        resetRound(); playing = true; audio.start()
    }
    func startOnline(with player: OnlinePlayer) {
        start()
    }
    func retry() { arena?.respawnPlayer(); resetRound() }
    private func resetRound() {
        paused = false; gameOver = false; touchBoosting = false; controllerBoosting = false; score = 0; eaten = 0; reason = ""; lastInventoryCount = 0
        scene?.resetClock()
    }
    func steer(x: Double, y: Double) { if hypot(x, y) > 0.15 { arena?.playerAngle = atan2(-y, x) } }
    func leave() { audio.stop(); touchBoosting = false; controllerBoosting = false; playing = false; scene = nil; arena = nil }
    func sync() {
        guard let arena else { return }
        audio.update(elapsed: arena.elapsed)
        do {
            score = arena.player.score; eaten = arena.player.inventory.count
            if eaten != lastInventoryCount {
                lastInventoryCount = eaten
                let oldCount = discovered.count
                discovered.formUnion(arena.player.inventory.map(\.kindID))
                if discovered.count != oldCount { UserDefaults.standard.set(Array(discovered), forKey: "discovered") }
            }
        }
        if score > best { best = score; UserDefaults.standard.set(best, forKey: "best") }
        if !arena.player.alive && !gameOver {
            gameOver = true
            reason = switch arena.deathReason {
            case .some(.boundary): language.text(.deathBorder)
            case .some(.rivalCollision): language.text(.deathSnake)
            case .none: ""
            }
            if score > best { best = score; UserDefaults.standard.set(best, forKey: "best") }
        }
        let ranked = arena.snakes.filter(\.alive).sorted { $0.score > $1.score }
        rank = (ranked.firstIndex(where: { $0.id == 0 }) ?? 0) + 1
        leaderboard = ranked.prefix(3).map { ($0.name, $0.score) }
        radar = arena.snakes.filter(\.alive).map { CGPoint(x: $0.head.x / arena.extent, y: 1 - $0.head.y / arena.extent) }
    }
}

final class ArenaScene: SKScene {
    let arena: Arena
    weak var session: GameSession?
    private let followCamera = SKCameraNode()
    private var snakeNodes: [Int: SKNode] = [:]
    private var foodNodes: [UUID: SKSpriteNode] = [:]
    private var textures: [Int: SKTexture] = [:]
    private var previous = 0.0
    private var accumulator = 0.0
    private var hudClock = 0.0
    private let colors: [UIColor] = [.cyan, .systemPink, .systemYellow, .systemMint, .systemOrange, .systemPurple]
    init(arena: Arena, session: GameSession) {
        self.arena = arena; self.session = session
        super.init(size: CGSize(width: 430, height: 932))
        scaleMode = .resizeFill; backgroundColor = UIColor(red: 0.035, green: 0.045, blue: 0.09, alpha: 1)
        camera = followCamera; addChild(followCamera)
        let path = CGMutablePath()
        for value in stride(from: 0.0, through: arena.extent, by: 200) {
            path.move(to: CGPoint(x: value, y: 0)); path.addLine(to: CGPoint(x: value, y: arena.extent))
            path.move(to: CGPoint(x: 0, y: value)); path.addLine(to: CGPoint(x: arena.extent, y: value))
        }
        let grid = SKShapeNode(path: path); grid.strokeColor = UIColor.cyan.withAlphaComponent(0.065); grid.lineWidth = 1; addChild(grid)
        let border = SKShapeNode(rect: CGRect(x: 0, y: 0, width: arena.extent, height: arena.extent))
        border.strokeColor = .systemPink; border.lineWidth = 12; border.glowWidth = 12; addChild(border)
        followCamera.position = CGPoint(x: arena.player.head.x, y: arena.player.head.y)
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func resetClock() { previous = 0; accumulator = 0 }
    override func update(_ currentTime: TimeInterval) {
        defer { previous = currentTime }
        guard let session else { return }
        guard !session.paused && !session.gameOver else { session.audio.pause(); return }
        session.audio.resumeIfNeeded()
        if let controller = GCController.controllers().first {
            if let pad = controller.extendedGamepad {
                let stick = pad.leftThumbstick
                let x = Double(stick.xAxis.value), y = Double(stick.yAxis.value)
                let dpadX = Double(pad.dpad.xAxis.value), dpadY = Double(pad.dpad.yAxis.value)
                if hypot(x, y) > 0.18 { arena.playerAngle = atan2(y, x) }
                else if hypot(dpadX, dpadY) > 0.18 { arena.playerAngle = atan2(dpadY, dpadX) }
                session.controllerBoosting = pad.buttonA.isPressed || pad.rightTrigger.isPressed
            } else if let pad = controller.gamepad {
                let x = Double(pad.dpad.xAxis.value), y = Double(pad.dpad.yAxis.value)
                if hypot(x, y) > 0.18 { arena.playerAngle = atan2(y, x) }
                session.controllerBoosting = pad.buttonA.isPressed
            } else if let pad = controller.microGamepad {
                let x = Double(pad.dpad.xAxis.value), y = Double(pad.dpad.yAxis.value)
                if hypot(x, y) > 0.18 { arena.playerAngle = atan2(y, x) }
                session.controllerBoosting = pad.buttonA.isPressed
            } else {
                session.controllerBoosting = false
            }
        } else {
            session.controllerBoosting = false
        }
        let dt = previous == 0 ? 0 : min(currentTime - previous, 0.1)
        accumulator += dt
        while accumulator >= 1.0 / 60 {
            // The arena retains the final inventory after death for an exact result.
            arena.step(1.0 / 60, boost: session.boosting); accumulator -= 1.0 / 60
            if !arena.player.alive { session.sync(); break }
        }
        hudClock += dt
        if hudClock >= 0.1 { session.sync(); hudClock = 0 }
        renderArena()
    }
    private func texture(for kind: CandyKind) -> SKTexture {
        if let cached = textures[kind.id] { return cached }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80))
        let image = renderer.image { _ in (kind.emoji as NSString).draw(at: CGPoint(x: 2, y: 0), withAttributes: [.font: UIFont.systemFont(ofSize: 62)]) }
        let texture = SKTexture(image: image); textures[kind.id] = texture; return texture
    }
    private func renderArena() {
        for event in arena.takeEatenEvents() {
            if event.snakeID == 0 { session?.audio.playEat(tier: event.candy.kind.tier, radiant: event.candy.power == .radiant) }
            guard let node = foodNodes.removeValue(forKey: event.candy.id) else { continue }
            node.removeAction(forKey: "sweet-idle")
            node.removeAction(forKey: "sweet-sway")
            let grow = SKAction.sequence([.scale(to: 1.22, duration: 0.07), .scale(to: 1.52, duration: 0.09)])
            let vanish = SKAction.sequence([.wait(forDuration: 0.04), .fadeOut(withDuration: 0.14)])
            let spin = SKAction.rotate(byAngle: .pi * 0.65, duration: 0.22)
            node.run(.group([grow, vanish, spin])) { node.removeFromParent() }
        }
        if arena.player.alive { followCamera.position = CGPoint(x: arena.player.head.x, y: arena.player.head.y) }
        let zoom = min(2.1, 1.15 + Double(arena.player.body.count) / 1500 + (arena.player.bodyWidth - 22) / 100)
        followCamera.setScale(zoom)
        let visible = CGRect(x: followCamera.position.x - size.width * zoom / 2 - 80, y: followCamera.position.y - size.height * zoom / 2 - 80, width: size.width * zoom + 160, height: size.height * zoom + 160)
        let visibleFood = arena.candies.filter { visible.contains(CGPoint(x: $0.position.x, y: $0.position.y)) }
        let visibleIDs = Set(visibleFood.map(\.id))
        for id in Array(foodNodes.keys) where !visibleIDs.contains(id) { foodNodes.removeValue(forKey: id)?.removeFromParent() }
        for candy in visibleFood {
            if foodNodes[candy.id] == nil {
                let node = SKSpriteNode(texture: texture(for: candy.kind))
                let diameter = (candy.kind.radius + 4) * 2
                node.size = CGSize(width: diameter, height: diameter)
                node.position = CGPoint(x: candy.position.x, y: candy.position.y); node.zPosition = 1
                node.setScale(0.92)
                let bob = SKAction.sequence([.scale(to: 1.06, duration: 0.72), .scale(to: 0.94, duration: 0.84)])
                node.run(.repeatForever(bob), withKey: "sweet-idle")
                let sway = SKAction.sequence([.rotate(toAngle: 0.07, duration: 0.9), .rotate(toAngle: -0.07, duration: 1.1)])
                node.run(.repeatForever(sway), withKey: "sweet-sway")
                if candy.power == .radiant {
                    node.color = .white; node.colorBlendFactor = 0.24
                    let halo = SKShapeNode(circleOfRadius: diameter * 0.7)
                    halo.strokeColor = .systemYellow; halo.lineWidth = 3; halo.glowWidth = 8; halo.alpha = 0.9
                    halo.zPosition = -1; node.addChild(halo)
                    let pulse = SKAction.sequence([.scale(to: 1.18, duration: 0.6), .scale(to: 0.92, duration: 0.75)])
                    halo.run(.repeatForever(pulse))
                    let sparkle = SKLabelNode(text: "✦")
                    sparkle.fontName = "AvenirNext-Bold"; sparkle.fontSize = diameter * 0.9; sparkle.fontColor = .white; sparkle.position = CGPoint(x: diameter * 0.36, y: diameter * 0.2); sparkle.zPosition = 2
                    node.addChild(sparkle)
                }
                if candy.dropped { node.color = .systemYellow; node.colorBlendFactor = 0.18 }
                foodNodes[candy.id] = node; addChild(node)
            }
        }
        for snake in arena.snakes {
            guard snake.alive && snake.body.contains(where: { visible.contains(CGPoint(x: $0.x, y: $0.y)) }) else {
                snakeNodes.removeValue(forKey: snake.id)?.removeFromParent()
                continue
            }
            let container: SKNode
            if let node = snakeNodes[snake.id] { container = node }
            else { container = SKNode(); container.zPosition = 2; snakeNodes[snake.id] = container; addChild(container) }
            container.removeAllChildren()
            let color = snake.id == 0 ? UIColor(session?.appearance.colour.colour ?? .mint) : colors[snake.id % colors.count]
            let bodyWidth = CGFloat(snake.bodyWidth)
            // Draw a continuous rounded body; self-intersections are intentionally harmless.
            let path = CGMutablePath()
            path.move(to: CGPoint(x: snake.head.x, y: snake.head.y))
            for point in snake.body.dropFirst() { path.addLine(to: CGPoint(x: point.x, y: point.y)) }
            let body = SKShapeNode(path: path)
            body.strokeColor = color.withAlphaComponent(0.9); body.lineWidth = bodyWidth; body.lineCap = .round; body.lineJoin = .round
            if snake.id == 0 || snake.score >= 80 {
                let aura = SKShapeNode(path: path); aura.strokeColor = color.withAlphaComponent(0.25); aura.lineWidth = bodyWidth + 14; aura.lineCap = .round; aura.lineJoin = .round; aura.glowWidth = bodyWidth * 0.35; container.addChild(aura)
            }
            let outline = SKShapeNode(path: path); outline.strokeColor = .white.withAlphaComponent(0.72); outline.lineWidth = bodyWidth + 4; outline.lineCap = .round; outline.lineJoin = .round; container.addChild(outline)
            container.addChild(body)
            // Bundle the decorative marks into one path per snake to keep the larger arena smooth.
            let patternPath = CGMutablePath()
            let ringPath = CGMutablePath()
            let lightningPath = CGMutablePath()
            let patternStep = max(7, snake.body.count / 28)
            for index in stride(from: patternStep, to: snake.body.count - 1, by: patternStep) {
                let point = snake.body[index]
                guard visible.contains(CGPoint(x: point.x, y: point.y)) else { continue }
                let previousPoint = snake.body[index - 1], nextPoint = snake.body[index + 1]
                let tangent = atan2(nextPoint.y - previousPoint.y, nextPoint.x - previousPoint.x)
                switch snake.pattern {
                case .racingStripes:
                    let mark = CGRect(x: -bodyWidth * 0.11, y: -bodyWidth * 0.42, width: bodyWidth * 0.22, height: bodyWidth * 0.84)
                    patternPath.addRect(mark, transform: CGAffineTransform(translationX: point.x, y: point.y).rotated(by: tangent + .pi / 2))
                case .bubbleSpots:
                    let diameter = bodyWidth * 0.46
                    patternPath.addEllipse(in: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter))
                case .starTrail:
                    let radius = bodyWidth * 0.27
                    let star = CGMutablePath()
                    for arm in 0..<10 {
                        let angle = Double(arm) * .pi / 5 - .pi / 2
                        let r = arm.isMultiple(of: 2) ? radius : radius * 0.45
                        let vertex = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
                        arm == 0 ? star.move(to: vertex) : star.addLine(to: vertex)
                    }
                    star.closeSubpath()
                    patternPath.addPath(star, transform: CGAffineTransform(translationX: point.x, y: point.y))
                case .confetti:
                    let mark = CGRect(x: -bodyWidth * 0.12, y: -bodyWidth * 0.30, width: bodyWidth * 0.24, height: bodyWidth * 0.60)
                    patternPath.addRect(mark, transform: CGAffineTransform(translationX: point.x, y: point.y).rotated(by: tangent + .pi / 4))
                case .checkerboard:
                    let side = bodyWidth * 0.24
                    patternPath.addRect(CGRect(x: -side/2, y: -side/2, width: side, height: side), transform: CGAffineTransform(translationX: point.x, y: point.y).rotated(by: tangent + .pi/4))
                case .scales:
                    let radius = bodyWidth * 0.15, nx = -sin(tangent), ny = cos(tangent)
                    for side in [-1.0, 1.0] { patternPath.addEllipse(in: CGRect(x: point.x + nx * bodyWidth * 0.22 * side - radius, y: point.y + ny * bodyWidth * 0.22 * side - radius, width: radius * 2, height: radius * 2)) }
                case .hearts:
                    let heart = CGMutablePath(); let r = bodyWidth * 0.13
                    heart.addEllipse(in: CGRect(x: -r, y: 0, width: r, height: r)); heart.addEllipse(in: CGRect(x: 0, y: 0, width: r, height: r)); heart.move(to: CGPoint(x: -r, y: r * 0.5)); heart.addLine(to: CGPoint(x: r * 0.5, y: -r * 1.35)); heart.addLine(to: CGPoint(x: r * 2, y: r * 0.5))
                    patternPath.addPath(heart, transform: CGAffineTransform(translationX: point.x, y: point.y).rotated(by: tangent + .pi / 2))
                case .neonRings:
                    let r = bodyWidth * 0.28; ringPath.addEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
                case .lightning:
                    let transform = CGAffineTransform(translationX: point.x, y: point.y).rotated(by: tangent + .pi / 2)
                    let bolt = CGMutablePath(); bolt.move(to: CGPoint(x: -bodyWidth * 0.12, y: bodyWidth * 0.30)); bolt.addLine(to: CGPoint(x: bodyWidth * 0.08, y: bodyWidth * 0.03)); bolt.addLine(to: CGPoint(x: -bodyWidth * 0.04, y: bodyWidth * 0.03)); bolt.addLine(to: CGPoint(x: bodyWidth * 0.12, y: -bodyWidth * 0.30)); lightningPath.addPath(bolt, transform: transform)
                }
            }
            let pattern = SKShapeNode(path: patternPath); pattern.fillColor = .white.withAlphaComponent(0.76); pattern.strokeColor = .clear; container.addChild(pattern)
            if snake.pattern == .neonRings { let rings = SKShapeNode(path: ringPath); rings.strokeColor = .white; rings.lineWidth = max(2, bodyWidth * 0.07); rings.glowWidth = bodyWidth * 0.14; rings.fillColor = .clear; container.addChild(rings) }
            if snake.pattern == .lightning { let bolts = SKShapeNode(path: lightningPath); bolts.strokeColor = .white; bolts.lineWidth = max(2, bodyWidth * 0.09); bolts.lineCap = .round; bolts.glowWidth = bodyWidth * 0.12; container.addChild(bolts) }
            let headRadius = bodyWidth * 0.68
            let head = SKShapeNode(circleOfRadius: headRadius); head.fillColor = color; head.strokeColor = .white.withAlphaComponent(0.5); head.lineWidth = max(1, bodyWidth * 0.045)
            head.position = CGPoint(x: snake.head.x, y: snake.head.y); head.zRotation = snake.angle
            let face = snake.id == 0 ? session?.appearance.face ?? .classic : .classic
            let eyeRadius = max(3.5, min(8, bodyWidth * 0.17))
            for y in [-headRadius * 0.38, headRadius * 0.38] {
                let eye = SKShapeNode(circleOfRadius: eyeRadius); eye.position = CGPoint(x: headRadius * 0.4, y: y); eye.fillColor = .white; eye.strokeColor = .clear; head.addChild(eye)
                let pupil = SKShapeNode(circleOfRadius: eyeRadius * 0.52); pupil.position = CGPoint(x: headRadius * 0.58, y: y); pupil.fillColor = .black; pupil.strokeColor = .clear; head.addChild(pupil)
            }
            if face == .wink {
                let wink = SKShapeNode(rectOf: CGSize(width: eyeRadius * 1.7, height: max(2, eyeRadius * 0.38)), cornerRadius: 1); wink.fillColor = .black; wink.strokeColor = .clear; wink.position = CGPoint(x: headRadius * 0.4, y: -headRadius * 0.38); head.addChild(wink)
            } else if face == .star {
                let star = SKLabelNode(text: "✦"); star.fontSize = headRadius * 0.78; star.fontColor = .systemYellow; star.position = CGPoint(x: headRadius * 0.42, y: headRadius * 0.64); head.addChild(star)
            } else if face == .sleepy {
                for y in [-headRadius * 0.38, headRadius * 0.38] { let lid = SKShapeNode(rectOf: CGSize(width: eyeRadius * 1.7, height: max(2, eyeRadius * 0.38)), cornerRadius: 1); lid.fillColor = .black; lid.strokeColor = .clear; lid.position = CGPoint(x: headRadius * 0.4, y: y); head.addChild(lid) }
            }
            container.addChild(head)
            container.alpha = snake.grace > 0 ? 0.6 : 1
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold"); label.text = snake.name; label.fontSize = max(11, min(16, bodyWidth * 0.42)); label.fontColor = color; label.position = CGPoint(x: snake.head.x, y: snake.head.y + headRadius + 10); container.addChild(label)
        }
    }
}

/// Lightweight synthesized soundtrack and bite effects; no external audio assets required.
final class GameAudio {
    private let engine = AVAudioEngine()
    private let musicPlayers = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let bitePlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)!
    private var tracks: [AVAudioPCMBuffer] = []
    private var activeIndex = 0
    private var currentTheme = -1
    private var started = false
    private var wantsPlayback = false
    private var elapsedTheme = 0

    init() {
        musicPlayers.forEach { engine.attach($0); engine.connect($0, to: engine.mainMixerNode, format: format) }
        engine.attach(bitePlayer); engine.connect(bitePlayer, to: engine.mainMixerNode, format: format)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let generated = (0..<4).map { Self.makeTrack(theme: $0, format: self.format) }
            DispatchQueue.main.async { self.tracks = generated; if self.wantsPlayback { self.playTheme(self.elapsedTheme % 4) } }
        }
    }

    func start() {
        wantsPlayback = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .gameChat, options: [.mixWithOthers])
        do { try AVAudioSession.sharedInstance().setActive(true); if !engine.isRunning { try engine.start() } } catch { return }
        started = true
        if !tracks.isEmpty { playTheme(max(0, elapsedTheme) % 4) }
    }

    func stop() {
        wantsPlayback = false; started = false
        musicPlayers.forEach { $0.stop() }; bitePlayer.stop(); engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func pause() {
        guard started else { return }
        engine.pause()
    }

    func resumeIfNeeded() {
        guard wantsPlayback, !engine.isRunning else { return }
        do { try engine.start(); started = true } catch { return }
        if currentTheme >= 0 && tracks.indices.contains(currentTheme) {
            let player = musicPlayers[activeIndex]
            if !player.isPlaying { player.scheduleBuffer(tracks[currentTheme], at: nil, options: .loops); player.play() }
        }
    }

    func update(elapsed: Double) {
        let theme = Int(elapsed / 60) % 4
        elapsedTheme = theme
        if theme != currentTheme && !tracks.isEmpty { playTheme(theme) }
    }

    func playEat(tier: Int, radiant: Bool) {
        guard wantsPlayback, engine.isRunning else { return }
        let length = AVAudioFrameCount(3_528)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: length), let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = length
        let duration = Double(length) / format.sampleRate
        let base = 570.0 + Double(tier) * 105 + (radiant ? 270 : 0)
        for i in 0..<Int(length) {
            let t = Double(i) / format.sampleRate
            let envelope = exp(-t * 25)
            let frequency = base + (radiant ? 500 : 240) * t / duration
            samples[i] = Float((sin(2 * .pi * frequency * t) * 0.22 + sin(2 * .pi * frequency * 2.01 * t) * 0.06) * envelope)
        }
        bitePlayer.stop(); bitePlayer.scheduleBuffer(buffer); bitePlayer.play()
    }

    private func playTheme(_ theme: Int) {
        guard started, tracks.indices.contains(theme), theme != currentTheme else { return }
        let incoming = 1 - activeIndex, outgoing = activeIndex
        let next = musicPlayers[incoming], old = musicPlayers[outgoing]
        next.stop(); next.volume = 0; next.scheduleBuffer(tracks[theme], at: nil, options: .loops); next.play()
        currentTheme = theme; activeIndex = incoming
        for step in 1...8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * 0.1) { [weak self] in
                guard let self, self.currentTheme == theme else { return }
                let amount = Float(step) / 8
                next.volume = amount
                old.volume = 1 - amount
                if step == 8 { old.stop() }
            }
        }
    }

    private static func makeTrack(theme: Int, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * 24)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        let scales = [[0, 3, 7, 10, 12, 10, 7, 3], [0, 2, 5, 9, 12, 9, 5, 2], [0, 4, 7, 11, 14, 11, 7, 4], [0, 3, 5, 8, 10, 8, 5, 3]]
        let notes = scales[theme]
        let beat = 0.42 + Double(theme) * 0.035
        for frame in 0..<Int(frames) {
            let time = Double(frame) / format.sampleRate
            let step = Int(time / beat) % notes.count
            let local = time.truncatingRemainder(dividingBy: beat)
            let envelope = exp(-local * 4.3)
            let midi = 60 + notes[step] + (theme == 2 ? 12 : 0)
            let frequency = 440 * pow(2, Double(midi - 69) / 12)
            let melody = sin(2 * .pi * frequency * time) * 0.11 + sin(2 * .pi * frequency * 2 * time) * 0.035
            let bassFreq = 55 * pow(2, Double((step / 2) % 3) / 3)
            let bass = sin(2 * .pi * bassFreq * time) * 0.075
            let pad = sin(2 * .pi * (frequency * 0.5) * time) * 0.025
            samples[frame] = Float((melody * envelope + bass + pad) * 0.72)
        }
        return buffer
    }
}
