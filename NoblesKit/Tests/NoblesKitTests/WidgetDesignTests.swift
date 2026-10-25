import Foundation
import Testing
@testable import NoblesKit

struct WidgetDesignTests {
    @Test(arguments: [
        WidgetContent.menu(MenuConfiguration()),
        .menu(MenuConfiguration(meal: .upcoming, filter: .only(sections: ["Hot Entree", "Vegan Entree"]), showsDescriptions: true)),
        .menu(MenuConfiguration(meal: .dinner, filter: .excluding(sections: ["Dessert"]), showsSectionHeaders: false)),
        .menu(MenuConfiguration(filter: .withoutSaladsAndSoups)),
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

    @Test func defaultsMatchTheirKind() {
        for kind in WidgetKind.allCases {
            #expect(WidgetDesign.makeDefault(kind).kind == kind)
        }
    }
}
