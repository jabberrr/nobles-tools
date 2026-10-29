import Foundation
import Testing
@testable import NoblesKit

struct WidgetDesignTests {
    @Test(arguments: [
        WidgetContent.menu(MenuConfiguration()),
        .menu(MenuConfiguration(meal: .upcoming, filter: .only(sections: ["Hot Entree", "Vegan Entree"]))),
        .menu(MenuConfiguration(meal: .dinner, filter: .excluding(sections: ["Dessert"]), showsSectionHeaders: false)),
        .menu(MenuConfiguration(filter: .withoutSaladsAndSoups, featuredStation: "Vegan Entree")),
        .countdown(CountdownConfiguration(target: .quarter, counting: .weekdays, style: .bar)),
        .scores(ScoresConfiguration(sports: ["Soccer", "Field Hockey"], varsityOnly: false, showsUpcoming: false)),
    ])
    func roundTripsThroughJSON(content: WidgetContent) throws {
        let design = WidgetDesign(
            name: "My \(content.kind.displayName)",
            theme: Theme(palette: .crimson, font: .rounded, background: .solid),
            content: content
        )
        let data = try JSONEncoder().encode(design)
        #expect(try JSONDecoder().decode(WidgetDesign.self, from: data) == design)
    }

    @Test func missingSettingsTakeTheirDefaults() throws {
        #expect(try decode(MenuConfiguration.self, from: "{}") == MenuConfiguration())
        #expect(try decode(CountdownConfiguration.self, from: "{}") == CountdownConfiguration())
        #expect(try decode(ScoresConfiguration.self, from: "{}") == ScoresConfiguration())
        #expect(try decode(Theme.self, from: "{}") == Theme())
        #expect(try decode(ScoresConfiguration.self, from: #"{"sports": ["Boys Soccer"], "varsityOnly": null}"#)
            == ScoresConfiguration(sports: ["Boys Soccer"]))
    }

    @Test func unreadableSettingsTakeTheirDefaults() throws {
        let menu = try decode(MenuConfiguration.self, from: #"{"meal": "brunch", "showsSectionHeaders": false}"#)
        #expect(menu == MenuConfiguration(showsSectionHeaders: false))
        let theme = try decode(Theme.self, from: #"{"palette": "neon", "font": "rounded"}"#)
        #expect(theme == Theme(font: .rounded))
        #expect(try decode(CountdownConfiguration.self, from: #"{"counting": 3}"#) == CountdownConfiguration())
    }

    @Test func designsNeedOnlyAnIDAndContent() throws {
        let design = try decode(WidgetDesign.self, from: #"{"id": "6F1C4A39-2D0B-4B8E-9F4E-1D2C3B4A5E6F", "content": {"countdown": {"_0": {}}}}"#)

        #expect(design.name == "Countdown")
        #expect(design.theme == Theme())
        #expect(design.content == .countdown(CountdownConfiguration()))
        #expect(throws: DecodingError.self) {
            try decode(WidgetDesign.self, from: #"{"name": "Lunch", "content": {"menu": {"_0": {}}}}"#)
        }
        #expect(throws: DecodingError.self) {
            try decode(WidgetDesign.self, from: #"{"id": "6F1C4A39-2D0B-4B8E-9F4E-1D2C3B4A5E6F", "name": "Lunch"}"#)
        }
    }

    @Test func defaultsMatchTheirKind() {
        for kind in WidgetKind.allCases {
            #expect(WidgetDesign.makeDefault(kind).kind == kind)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
