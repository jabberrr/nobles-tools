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

    private func game(opponent: String) -> Game {
        Game(id: "1", sport: "Boys Soccer", opponent: opponent, start: .now, status: .scheduled)
    }
}
