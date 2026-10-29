import Foundation
import Testing
@testable import NoblesKit

struct ShortNameTests {
    /// Real dish names from the captured week.
    @Test(arguments: zip(
        [
            "Black Widow Soup, Sour Cream & Scallions",
            "Steamed Zombie Brains, Sea Salt & Cracked Pepper",
            "Tomato, Kale, Red Bean & Pasta Toss, Chive Oil",
            "Roasted Green Beans with Shallots",
            "Revved Up Macaroni & Cheese",
            "Chocolate Chip, Snickerdoodle, Oatmeal",
            "Hard & Soft Shells",
        ],
        [
            "Black Widow Soup",
            "Steamed Zombie Brains",
            "Tomato, Kale, Red Bean & Pasta Toss",
            "Roasted Green Beans",
            "Revved Up Macaroni & Cheese",
            "Chocolate Chip, Snickerdoodle",
            "Hard & Soft Shells",
        ]
    ))
    func dishesDropTheirTrimmings(name: String, short: String) {
        #expect(MenuItem(id: 1, name: name).shortName == short)
    }

    @Test func dishesKeepAtLeastTwoWords() {
        #expect(MenuItem(id: 1, name: "Chicken, Rice").shortName == "Chicken, Rice")
        #expect(MenuItem(id: 1, name: "Pasta with Meat Sauce, Parmesan").shortName == "Pasta with Meat Sauce")
        #expect(MenuItem(id: 1, name: "Chicken with Rice").shortName == "Chicken with Rice")
    }

    /// Real opponent names from the athletics fixtures.
    @Test(arguments: zip(
        [
            "The Rivers School",
            "Austin Preparatory School",
            "Buckingham Browne & Nichols School",
            "St. Paul's School, NH",
            "Governor's Academy",
            "The Cambridge School of Weston",
            "Dexter Southfield",
            "Fay",
        ],
        [
            "Rivers",
            "Austin",
            "Buckingham Browne & Nichols",
            "St. Paul's",
            "Governor's",
            "Cambridge School of Weston",
            "Dexter Southfield",
            "Fay",
        ]
    ))
    func opponentsGoByTheirShortNames(name: String, short: String) {
        #expect(game(opponent: name).shortOpponent == short)
    }

    @Test func opponentsNeverShortenToNothing() {
        #expect(game(opponent: "The Academy").shortOpponent == "The Academy")
        #expect(game(opponent: "").shortOpponent == "")
    }

    @Test func longOpponentsGoByTheirInitials() {
        #expect(game(opponent: "Buckingham Browne & Nichols School").opponentInitials == "BB&N")
        #expect(game(opponent: "The Cambridge School of Weston").opponentInitials == "CSW")
        #expect(game(opponent: "Beaver Country Day School").opponentInitials == "BCD")
        #expect(game(opponent: "Dexter Southfield").opponentInitials == nil)
        #expect(game(opponent: "Austin Preparatory School").opponentInitials == nil)
    }

    @Test func levelsAreShortAndVarsityGoesUnsaid() {
        #expect(game(level: "Middle School").shortLevel == "MS")
        #expect(game(level: "JV A").shortLevel == "JV A")
        #expect(game(level: "3rd").shortLevel == "3rd")
        #expect(game(level: "Varsity").shortLevel == nil)
        #expect(game(level: nil).shortLevel == nil)
    }

    private func game(opponent: String = "Thayer Academy", level: String? = nil) -> Game {
        Game(id: "1", sport: "Boys Soccer", level: level, opponent: opponent, start: .now, status: .scheduled)
    }
}
