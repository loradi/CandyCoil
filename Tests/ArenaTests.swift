import XCTest
@testable import CandyCoilCore
final class ArenaTests: XCTestCase {
    func testFiftySizesAndGrowth() {
        XCTAssertEqual(CandyKind.all.count, 50)
        XCTAssertEqual(Set(CandyKind.all.map(\.id)).count, 50)
        for family in 0..<10 { for tier in 1..<5 { XCTAssertGreaterThan(CandyKind.all[family * 5 + tier].growth, CandyKind.all[family * 5 + tier - 1].growth) } }
    }
    func testEatingGrowsActualBody() {
        let arena = Arena(seed: 1, bots: 0, food: 0)
        arena.candies = [Candy(kindID: 4, position: arena.player.head)]
        arena.step(1.0 / 60)
        XCTAssertEqual(arena.player.score, 20)
        XCTAssertEqual(arena.player.body.count, 44)
        XCTAssertTrue(arena.candies.isEmpty)
    }
    func testBoostIncreasesOnlyPlayerMovementSpeed() {
        let normal = Arena(seed: 17, bots: 0, food: 0)
        let boosted = Arena(seed: 17, bots: 0, food: 0)
        let startX = normal.player.head.x
        normal.step(1.0 / 60)
        boosted.step(1.0 / 60, boost: true)
        XCTAssertEqual(normal.player.head.x - startX, 155.0 / 60.0, accuracy: 0.001)
        XCTAssertEqual(boosted.player.head.x - startX, 225.0 / 60.0, accuracy: 0.001)
    }
    func testEatingMakesSnakeWiderWhileAnUnfedSnakeStaysSmall() {
        let arena = Arena(seed: 1, bots: 0, food: 0)
        let initialWidth = arena.player.bodyWidth
        arena.candies = [Candy(kindID: 4, position: arena.player.head)]
        arena.step(1.0 / 60)
        XCTAssertEqual(arena.player.body.count, 44)
        XCTAssertGreaterThan(arena.player.bodyWidth, initialWidth)
        XCTAssertGreaterThan(arena.player.bodyWidth - initialWidth, 4)
        let unfed = Arena(seed: 2, bots: 0, food: 0)
        XCTAssertEqual(unfed.player.bodyWidth, initialWidth)
    }
    func testCandyIsCollectedWhenHeadPassesNearbyAndAlongMovementPath() {
        let arena = Arena(seed: 1, bots: 0, food: 0)
        let start = arena.player.head
        arena.candies = [Candy(kindID: 0, position: Point(x: start.x + 40, y: start.y))]
        arena.step(1.0 / 60)
        XCTAssertEqual(arena.player.score, CandyKind.all[0].growth)
        XCTAssertTrue(arena.candies.isEmpty)
    }
    func testBotWithNoNearbyCandyMovesTowardWaypointsInsteadOfStayingInPlace() {
        let arena = Arena(seed: 8, bots: 1, food: 0)
        let start = arena.snakes[1].head
        for _ in 0..<360 { arena.step(1.0 / 60) }
        XCTAssertGreaterThan(arena.snakes[1].head.distance(to: start), 300)
    }
    func testBotEscapesARepeatedCircularPath() {
        let arena = Arena(seed: 8, bots: 1, food: 0)
        let bot = arena.snakes[1]
        let center = bot.head
        arena.snakes[1].aiRecentHeads = (0..<11).map { step in
            let angle = Double(step) * 2 * .pi / 12
            return Point(x: center.x + cos(angle) * 130, y: center.y + sin(angle) * 130)
        }
        let currentAngle = 11 * 2 * Double.pi / 12
        let current = Point(x: center.x + cos(currentAngle) * 130, y: center.y + sin(currentAngle) * 130)
        let offset = Point(x: current.x - center.x, y: current.y - center.y)
        arena.snakes[1].body = bot.body.map { Point(x: $0.x + offset.x, y: $0.y + offset.y) }
        arena.snakes[1].aiSampleIn = 0.01
        arena.step(1.0 / 60)
        XCTAssertGreaterThan(arena.snakes[1].aiIgnoreCandyIn, 5)
        XCTAssertNil(arena.snakes[1].aiTargetCandyID)
    }
    func testWildsNowHaveMoreRivalsAndSweets() {
        let arena = Arena(seed: 3)
        XCTAssertEqual(arena.snakes.count, 49)
        XCTAssertGreaterThanOrEqual(arena.candies.count, 5_200)
        XCTAssertGreaterThan(Set(arena.snakes.map(\.pattern)).count, 1)
    }
    func testExpandedArenaRunsAFullPopulation() {
        let arena = Arena(seed: 9)
        for _ in 0..<120 { arena.step(1.0 / 60) }
        XCTAssertEqual(arena.snakes.count, 49)
        XCTAssertGreaterThan(arena.snakes.filter(\.alive).count, 1)
        XCTAssertTrue(arena.snakes.allSatisfy { $0.body.allSatisfy { $0.x.isFinite && $0.y.isFinite } })
    }
    func testRadiantCandyGrowsThreeTimesMore() {
        let arena = Arena(seed: 1, bots: 0, food: 0)
        arena.candies = [Candy(kindID: 4, position: arena.player.head, power: .radiant)]
        arena.step(1.0 / 60)
        XCTAssertEqual(arena.player.score, 60)
        XCTAssertEqual(arena.player.body.count, 84)
    }
    func testSelfCrossingIsSafe() {
        let arena = Arena(seed: 1, bots: 0, food: 0)
        arena.snakes[0].grace = 0
        arena.snakes[0].body = Array(repeating: arena.player.head, count: 24)
        arena.step(1.0 / 60)
        XCTAssertTrue(arena.player.alive)
    }
    func testCollisionDropsExactInventoryAndRetryKeepsLoot() {
        let arena = Arena(seed: 1, bots: 1, food: 0)
        arena.snakes[0].inventory = [0, 4, 9, 23].map { CandyReward(kindID: $0, power: .normal) }
        arena.snakes[0].grace = 0
        arena.snakes[1].grace = 0
        arena.snakes[1].body = [arena.player.head, arena.player.head]
        arena.step(1.0 / 60)
        XCTAssertFalse(arena.player.alive)
        let dropped = arena.candies.filter(\.dropped)
        XCTAssertEqual(dropped.map(\.kindID).sorted(), [0, 4, 9, 23])
        let ids = Set(dropped.map(\.id))
        arena.respawnPlayer()
        XCTAssertTrue(arena.player.alive)
        XCTAssertEqual(arena.player.score, 0)
        XCTAssertTrue(ids.isSubset(of: Set(arena.candies.map(\.id))))
    }
    func testBoundaryKillsInsteadOfWrapping() {
        let arena = Arena(seed: 1, bots: 0, food: 0)
        arena.snakes[0].body[0] = Point(x: arena.extent - 14, y: 100)
        arena.step(1.0 / 60)
        XCTAssertFalse(arena.player.alive)
        XCTAssertEqual(arena.deathReason, .boundary)
    }
    func testSimulationStaysFinite() {
        let arena = Arena(seed: 42, bots: 5, food: 150)
        for _ in 0..<600 { arena.step(1.0 / 60) }
        XCTAssertTrue(arena.snakes.allSatisfy { $0.body.allSatisfy { $0.x.isFinite && $0.y.isFinite } })
    }
}
