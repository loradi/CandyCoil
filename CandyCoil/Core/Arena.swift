import Foundation

enum SnakePattern: String, CaseIterable, Identifiable, Codable, Hashable {
    case racingStripes, bubbleSpots, starTrail, confetti, checkerboard, scales, hearts, neonRings, lightning

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .racingStripes: "〰️"
        case .bubbleSpots: "●"
        case .starTrail: "✦"
        case .confetti: "✿"
        case .checkerboard: "▦"
        case .scales: "◉"
        case .hearts: "♥"
        case .neonRings: "◎"
        case .lightning: "ϟ"
        }
    }
}

enum ArenaDeathReason: Equatable {
    case boundary
    case rivalCollision
}

private struct FoodCell: Hashable {
    let x: Int
    let y: Int
}

struct CandyEatenEvent {
    let snakeID: Int
    let candy: Candy
}

/// Fixed-step simulation, independent of rendering and input devices.
final class Arena {
    /// Large enough to make long sessions feel like an expedition, not a lap.
    let extent: Double = 12_000
    static let botCount = 48
    static let foodCount = 5_200
    private let playerPattern: SnakePattern
    var snakes: [Serpent] = []
    var candies: [Candy] = []
    var playerAngle = 0.0
    var player: Serpent { snakes[0] }
    var deathReason: ArenaDeathReason?
    private var pendingEatenEvents: [CandyEatenEvent] = []
    var elapsed = 0.0
    private var refillTime = 0.0
    private var randomState: UInt64
    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max), bots: Int = Arena.botCount, food: Int = Arena.foodCount, playerPattern: SnakePattern = .racingStripes) {
        randomState = seed
        self.playerPattern = playerPattern
        snakes.append(makeSnake(id: 0, name: "You", position: Point(x: extent / 2, y: extent / 2), pattern: playerPattern))
        let names = ["Mochi", "Fizz", "Truffle", "Jellybean", "Coco", "Berry", "Minty", "Cloud", "Pixel", "Kiwi", "Gumdrop", "Honey", "Lime", "Cocoa", "Sugar Rush", "Sprinkle", "Pudding", "Twinkle", "Boba", "Jelly Roll", "Taffy", "Lollipop", "Marshmallow", "Doodle", "Pop-Tart", "Skittle", "Peaches", "Pinky", "Gummy", "Comet", "Frosty", "Dazzle", "Zigzag", "Nibbles", "Sour Spark", "Caramel", "Candy Corn", "Biscuit", "Jelly Pop", "Mallow", "Luna", "Nova", "Razzle", "Blueberry", "Cherry", "Toffee", "Spritz", "Pip"]
        for i in 0..<bots {
            let angle = Double(i) * 2 * .pi / Double(max(1, bots))
            let radius = 420 + random() * 1150
            let position = Point(x: extent / 2 + cos(angle) * radius, y: extent / 2 + sin(angle) * radius)
            snakes.append(makeSnake(id: i + 1, name: names[i % names.count], position: position, angle: angle + (random() - 0.5) * 0.7))
        }
        for _ in 0..<food { candies.append(randomCandy()) }
        // A readable first trail makes the initial controls rewarding.
        if food > 0 {
        for i in 0..<14 { candies.append(Candy(kindID: (i % 10) * 5, position: Point(x: extent / 2 + 70 + Double(i) * 38, y: extent / 2 + sin(Double(i) * 0.3) * 50))) }
        }
    }
    private func random() -> Double {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        return Double(randomState >> 11) / Double(UInt64.max >> 11)
    }
    private func makeSnake(id: Int, name: String, position: Point, angle: Double = 0, pattern: SnakePattern? = nil) -> Serpent {
        let selectedPattern = pattern ?? SnakePattern.allCases[min(SnakePattern.allCases.count - 1, Int(random() * Double(SnakePattern.allCases.count)))]
        return Serpent(id: id, name: name, body: (0..<24).map { Point(x: position.x - Double($0) * 6, y: position.y) }, angle: angle, pattern: selectedPattern)
    }
    private func randomCandy() -> Candy {
        let tierRoll = random()
        let tier = tierRoll < 0.53 ? 0 : tierRoll < 0.80 ? 1 : tierRoll < 0.93 ? 2 : tierRoll < 0.985 ? 3 : 4
        let power: CandyPower = random() < 0.075 ? .radiant : .normal
        return Candy(kindID: Int(random() * 10) * 5 + tier, position: Point(x: 55 + random() * (extent - 110), y: 55 + random() * (extent - 110)), power: power)
    }
    func respawnPlayer() {
        // Keep the existing arena and dropped candy. Find a safe spawn away from bodies.
        var position = Point(x: extent / 2, y: extent / 2)
        for _ in 0..<200 {
            position = Point(x: 250 + random() * (extent - 500), y: 250 + random() * (extent - 500))
            if snakes.dropFirst().filter(\.alive).allSatisfy({ snake in snake.body.allSatisfy { $0.distance(to: position) > 220 } }) { break }
        }
        snakes[0] = makeSnake(id: 0, name: "You", position: position, pattern: playerPattern)
        playerAngle = 0; deathReason = nil
    }
    func takeEatenEvents() -> [CandyEatenEvent] {
        defer { pendingEatenEvents.removeAll(keepingCapacity: true) }
        return pendingEatenEvents
    }
    func step(_ dt: Double, boost: Bool = false) {
        guard dt > 0, dt <= 1.0 / 20 else { return }
        elapsed += dt; refillTime += dt
        let cellSize = 96.0
        var foodCells: [FoodCell: [Int]] = [:]
        for (index, candy) in candies.enumerated() {
            foodCells[foodCell(for: candy.position, cellSize: cellSize), default: []].append(index)
        }
        let candyIDs = Set(candies.map(\.id))
        let previousHeads = snakes.map(\.head)
        for index in snakes.indices where snakes[index].alive {
            var s = snakes[index]
            s.grace = max(0, s.grace - dt)
            let target = index == 0 ? playerAngle : botAngle(for: &s, foodCells: foodCells, candyIDs: candyIDs, cellSize: cellSize, dt: dt)
            let difference = atan2(sin(target - s.angle), cos(target - s.angle))
            let turnRate = index == 0 ? 3.4 : 2.35
            s.angle += min(turnRate * dt, max(-turnRate * dt, difference))
            let speed = index == 0 && boost ? 225.0 : 155.0
            let head = Point(x: s.head.x + cos(s.angle) * speed * dt, y: s.head.y + sin(s.angle) * speed * dt)
            s.body[0] = head
            // Keep body spacing independent of display refresh rate.
            for j in 1..<s.body.count {
                let preceding = s.body[j - 1], current = s.body[j]
                let distance = current.distance(to: preceding)
                if distance > 6 {
                    s.body[j] = Point(x: preceding.x + (current.x - preceding.x) * 6 / distance, y: preceding.y + (current.y - preceding.y) * 6 / distance)
                }
            }
            snakes[index] = s
        }
        // Decide all deaths from the same snapshot, including head-on collisions.
        var deaths: [Int] = []
        for index in snakes.indices where snakes[index].alive {
            let s = snakes[index]
            if s.head.x < 14 || s.head.y < 14 || s.head.x > extent - 14 || s.head.y > extent - 14 {
                deaths.append(index)
                if index == 0 { deathReason = .boundary }
                continue
            }
            if s.grace > 0 { continue }
            var collided = false
            for other in snakes where other.id != s.id && other.alive && other.grace == 0 {
                let reach = s.bodyWidth * 0.58 + other.bodyWidth * 0.5
                let reachSquared = reach * reach
                for pointIndex in stride(from: 0, to: other.body.count, by: 3) {
                    if other.body[pointIndex].distanceSquared(to: s.head) < reachSquared {
                        collided = true
                        break
                    }
                }
                if collided { break }
            }
            if collided {
                deaths.append(index)
                if index == 0 { deathReason = .rivalCollision }
            }
        }
        for index in deaths { eliminate(index) }
        var eatenIndices = Set<Int>()
        for index in snakes.indices where snakes[index].alive {
            let head = snakes[index].head
            let cell = foodCell(for: head, cellSize: cellSize)
            var eaten: [CandyReward] = []
            for x in (cell.x - 1)...(cell.x + 1) {
                for y in (cell.y - 1)...(cell.y + 1) {
                    for candyIndex in foodCells[FoodCell(x: x, y: y)] ?? [] where !eatenIndices.contains(candyIndex) {
                        let candy = candies[candyIndex]
                        // A soft pickup radius is forgiving on touch controls, and testing the
                        // whole frame's movement segment prevents fast boosts from skipping food.
                        let reach = candy.kind.radius + snakes[index].bodyWidth * 0.72 + 22
                        if distanceSquared(from: candy.position, toSegmentFrom: previousHeads[index], to: head) < reach * reach {
                            eatenIndices.insert(candyIndex)
                            eaten.append(CandyReward(kindID: candy.kindID, power: candy.power))
                            pendingEatenEvents.append(CandyEatenEvent(snakeID: index, candy: candy))
                        }
                    }
                }
            }
            if !eaten.isEmpty {
                snakes[index].inventory.append(contentsOf: eaten)
                while snakes[index].body.count < snakes[index].length { snakes[index].body.append(snakes[index].body.last!) }
            }
        }
        if !eatenIndices.isEmpty {
            candies = candies.enumerated().compactMap { eatenIndices.contains($0.offset) ? nil : $0.element }
        }
        if refillTime >= 1 {
            refillTime = 0
            if candies.filter({ !$0.dropped }).count < Self.foodCount { candies.append(randomCandy()) }
            for index in snakes.indices where index > 0 && !snakes[index].alive {
                let pos = Point(x: 200 + random() * (extent - 400), y: 200 + random() * (extent - 400))
                snakes[index] = makeSnake(id: index, name: snakes[index].name, position: pos, angle: random() * 2 * .pi)
            }
        }
    }
    func eliminate(_ index: Int) {
        guard snakes[index].alive else { return }
        let snake = snakes[index]
        for (i, reward) in snake.inventory.enumerated() {
            let point = snake.body[min(snake.body.count - 1, i * snake.body.count / max(1, snake.inventory.count))]
            candies.append(Candy(kindID: reward.kindID, position: point, dropped: true, power: reward.power))
        }
        snakes[index].alive = false
        // Keep the final tally until respawn; alive guards against duplicate drops.
    }
    private func botAngle(for snake: inout Serpent, foodCells: [FoodCell: [Int]], candyIDs: Set<UUID>, cellSize: Double, dt: Double) -> Double {
        let head = snake.head
        snake.aiIgnoreCandyIn = max(0, snake.aiIgnoreCandyIn - dt)
        snake.aiSampleIn -= dt
        if snake.aiSampleIn <= 0 {
            snake.aiSampleIn = 0.75
            snake.aiRecentHeads.append(head)
            if snake.aiRecentHeads.count > 12 { snake.aiRecentHeads.removeFirst(snake.aiRecentHeads.count - 12) }
            if snake.aiRecentHeads.count == 12 {
                let travelled = zip(snake.aiRecentHeads, snake.aiRecentHeads.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
                if head.distance(to: snake.aiRecentHeads[0]) < 175 && travelled > 650 {
                    // Break sustained orbits: ignore nearby food briefly and commit to a distant waypoint.
                    let escapeAngle = snake.angle + (random() < 0.5 ? -1 : 1) * (1.15 + random() * 0.65)
                    let escapeDistance = 1_250 + random() * 650
                    snake.aiTarget = Point(x: min(extent - 520, max(520, head.x + cos(escapeAngle) * escapeDistance)), y: min(extent - 520, max(520, head.y + sin(escapeAngle) * escapeDistance)))
                    snake.aiTargetCandyID = nil
                    snake.aiIgnoreCandyIn = 5.5
                    snake.aiRetargetIn = 2.8
                    snake.aiRecentHeads.removeAll(keepingCapacity: true)
                }
            }
        }
        snake.aiRetargetIn -= dt
        let targetStillExists = snake.aiTargetCandyID.map(candyIDs.contains) ?? true
        if snake.aiTarget == nil || !targetStillExists || (snake.aiRetargetIn <= 0 && snake.aiIgnoreCandyIn == 0) || snake.aiTarget!.distance(to: head) < 150 {
            let choice = snake.aiIgnoreCandyIn > 0
                ? chooseWaypoint(from: head, currentAngle: snake.angle)
                : chooseBotTarget(from: head, currentAngle: snake.angle, cells: foodCells, cellSize: cellSize)
            snake.aiTarget = choice.point
            snake.aiTargetCandyID = choice.candyID
            snake.aiRetargetIn = snake.aiIgnoreCandyIn > 0 ? min(snake.aiIgnoreCandyIn, 2.6) : 3.8 + random() * 2.4
        }
        guard let goal = snake.aiTarget else { return snake.angle }

        var dx = goal.x - head.x, dy = goal.y - head.y
        let distance = max(1, hypot(dx, dy))
        dx /= distance; dy /= distance

        // Steer around nearby bodies that lie in the snake's forward path.
        for other in snakes where other.id != snake.id && other.alive {
            let safeDistance = max(150, (snake.bodyWidth + other.bodyWidth) * 0.65 + 105)
            let safeSquared = safeDistance * safeDistance
            for pointIndex in stride(from: 0, to: other.body.count, by: 4) {
                let point = other.body[pointIndex]
                let offsetX = head.x - point.x, offsetY = head.y - point.y
                let distanceSquared = offsetX * offsetX + offsetY * offsetY
                guard distanceSquared < safeSquared, distanceSquared > 0 else { continue }
                let proximity = 1 - sqrt(distanceSquared) / safeDistance
                let ahead = (point.x - head.x) * dx + (point.y - head.y) * dy
                let forwardWeight = ahead > 0 ? 1.7 : 0.8
                let strength = proximity * proximity * forwardWeight * 1.9
                let invDistance = 1 / sqrt(distanceSquared)
                dx += offsetX * invDistance * strength
                dy += offsetY * invDistance * strength
            }
        }

        let margin = 560.0
        if head.x < margin { dx += 2.8 * (1 - head.x / margin) }
        if head.y < margin { dy += 2.8 * (1 - head.y / margin) }
        if head.x > extent - margin { dx -= 2.8 * (1 - (extent - head.x) / margin) }
        if head.y > extent - margin { dy -= 2.8 * (1 - (extent - head.y) / margin) }
        return atan2(dy, dx)
    }

    private func chooseBotTarget(from head: Point, currentAngle: Double, cells: [FoodCell: [Int]], cellSize: Double) -> (point: Point, candyID: UUID?) {
        let origin = foodCell(for: head, cellSize: cellSize)
        var bestIndex: Int?
        var bestValue = -Double.infinity
        for ring in 0...11 {
            for x in (origin.x - ring)...(origin.x + ring) {
                for y in (origin.y - ring)...(origin.y + ring) {
                    guard ring == 0 || x == origin.x - ring || x == origin.x + ring || y == origin.y - ring || y == origin.y + ring else { continue }
                    for index in cells[FoodCell(x: x, y: y)] ?? [] {
                        let candy = candies[index]
                        let distance = sqrt(head.distanceSquared(to: candy.position))
                        let value = (Double(candy.growth) + 9) / (distance + 180)
                        if value > bestValue { bestIndex = index; bestValue = value }
                    }
                }
            }
        }
        if let bestIndex { return (candies[bestIndex].position, candies[bestIndex].id) }

        return (chooseWaypoint(from: head, currentAngle: currentAngle).point, nil)
    }

    private func chooseWaypoint(from head: Point, currentAngle: Double) -> (point: Point, candyID: UUID?) {
        // When food is sparse, choose a forward waypoint instead of spinning around one spot.
        let direction = currentAngle + (random() - 0.5) * 1.1
        let distance = 900 + random() * 700
        let goal = Point(x: min(extent - 520, max(520, head.x + cos(direction) * distance)), y: min(extent - 520, max(520, head.y + sin(direction) * distance)))
        return (goal, nil)
    }

    private func distanceSquared(from point: Point, toSegmentFrom start: Point, to end: Point) -> Double {
        let dx = end.x - start.x, dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return point.distanceSquared(to: start) }
        let projection = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let closest = Point(x: start.x + projection * dx, y: start.y + projection * dy)
        return point.distanceSquared(to: closest)
    }

    private func foodCell(for point: Point, cellSize: Double) -> FoodCell {
        FoodCell(x: Int(floor(point.x / cellSize)), y: Int(floor(point.y / cellSize)))
    }
}
