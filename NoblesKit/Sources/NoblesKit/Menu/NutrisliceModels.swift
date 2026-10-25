import Foundation

// The parts of Nutrislice's responses that Nobles Tools reads. Decoding is lenient throughout:
// unknown keys are ignored, odd values read as missing, and a malformed day or row is skipped
// rather than failing the whole response.

/// `{base}/weeks/...`: one menu type's week, Sunday through Saturday.
struct NutrisliceWeek: Decodable {
    var days: [NutrisliceDay]

    private enum CodingKeys: String, CodingKey {
        case days
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decode([Lossy<NutrisliceDay>].self, forKey: .days).compactMap(\.value)
    }

    /// Decodes a week, reporting failure as `MenuServiceError.decoding`.
    static func decoded(from data: Data) throws -> NutrisliceWeek {
        do {
            return try JSONDecoder().decode(NutrisliceWeek.self, from: data)
        } catch {
            throw MenuServiceError.decoding(String(describing: error))
        }
    }
}

struct NutrisliceDay: Decodable {
    var date: LocalDate
    var items: [NutrisliceItem]

    private enum CodingKeys: String, CodingKey {
        case date
        case items = "menu_items"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let date = container.text(forKey: .date).flatMap(LocalDate.init(iso:)) else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Missing or invalid date")
        }
        self.date = date
        items = container.lenient([Lossy<NutrisliceItem>].self, forKey: .items)?.compactMap(\.value) ?? []
    }
}

/// One row of a day's menu: a station header, a dish (as `text`, or as a `food` with a name),
/// a holiday notice, or a blank/icon row.
struct NutrisliceItem: Decodable {
    var id: Int?
    var position: Int?
    var isHeader: Bool
    var isHoliday: Bool
    var text: String?
    var category: String?
    var food: NutrisliceFood?

    private enum CodingKeys: String, CodingKey {
        case id, position, text, category, food
        case isSectionTitle = "is_section_title"
        case isStationHeader = "is_station_header"
        case isHoliday = "is_holiday"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.integer(forKey: .id)
        position = container.integer(forKey: .position)
        isHeader = container.lenient(Bool.self, forKey: .isSectionTitle) == true
            || container.lenient(Bool.self, forKey: .isStationHeader) == true
        isHoliday = container.lenient(Bool.self, forKey: .isHoliday) == true
        text = container.text(forKey: .text)
        category = container.text(forKey: .category)
        food = container.lenient(NutrisliceFood.self, forKey: .food)
    }
}

struct NutrisliceFood: Decodable {
    var name: String?
    var description: String?
    var category: String?
    var calories: Double?

    private enum CodingKeys: String, CodingKey {
        case name, description
        case category = "food_category"
        case nutrition = "rounded_nutrition_info"
    }

    private enum NutritionKeys: String, CodingKey {
        case calories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.text(forKey: .name)
        description = container.text(forKey: .description)
        category = container.text(forKey: .category)
        let nutrition = try? container.nestedContainer(keyedBy: NutritionKeys.self, forKey: .nutrition)
        calories = nutrition?.number(forKey: .calories)
    }
}

/// An entry in `{base}/schools/`.
struct NutrisliceSchool: Decodable {
    var slug: String?
    var menuTypes: [NutrisliceMenuType]

    private enum CodingKeys: String, CodingKey {
        case slug
        case menuTypes = "active_menu_types"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = container.text(forKey: .slug)
        menuTypes = container.lenient([Lossy<NutrisliceMenuType>].self, forKey: .menuTypes)?.compactMap(\.value) ?? []
    }
}

/// A menu type such as `{"name": "Lunch", "slug": "lunch"}`.
struct NutrisliceMenuType: Decodable {
    var name: String?
    var slug: String?

    private enum CodingKeys: String, CodingKey {
        case name, slug
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.text(forKey: .name)
        slug = container.text(forKey: .slug)
    }
}
