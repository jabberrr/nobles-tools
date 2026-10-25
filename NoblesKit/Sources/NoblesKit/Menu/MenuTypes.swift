import Foundation

/// The meals a school publishes and the Nutrislice menu-type slug for each.
struct MenuTypes: Codable, Hashable, Sendable {
    /// Slug for each published meal, keyed by `Meal.rawValue`.
    var slugs: [String: String]

    /// Nobles' menu types as of October 2026 (there is no breakfast menu), used whenever
    /// discovery fails or matches nothing.
    static let fallback = MenuTypes(slugs: [Meal.lunch.rawValue: "lunch", Meal.dinner.rawValue: "dinner"])

    init(slugs: [String: String]) {
        self.slugs = slugs
    }

    /// Reads a `{base}/schools/` response: each meal maps to the school's first active menu type
    /// whose name or slug contains the meal's name. `nil` if the school isn't listed or no meal matches.
    init?(schoolsResponse data: Data, schoolSlug: String) {
        guard let schools = try? JSONDecoder().decode([Lossy<NutrisliceSchool>].self, from: data),
              let school = schools.lazy.compactMap(\.value).first(where: { $0.slug == schoolSlug })
        else { return nil }
        var slugs: [String: String] = [:]
        for meal in Meal.allCases {
            let match = school.menuTypes.first { type in
                [type.name, type.slug].contains { $0?.matchKey.contains(meal.rawValue) == true }
            }
            slugs[meal.rawValue] = match?.slug
        }
        guard !slugs.isEmpty else { return nil }
        self.slugs = slugs
    }

    /// Published meals in serving order.
    var meals: [Meal] { Meal.allCases.filter { slugs[$0.rawValue] != nil } }

    /// `nil` when the school doesn't publish `meal`.
    func slug(for meal: Meal) -> String? { slugs[meal.rawValue] }
}

extension MenuService {
    /// How long discovered menu types are trusted before the schools list is fetched again.
    static let menuTypesLifetime: TimeInterval = 7 * 24 * 60 * 60

    var menuTypesCacheKey: String { "menu-types.v1 \(endpoint.schoolsURL.absoluteString) \(endpoint.schoolSlug)" }

    /// The school's menu types: from the cache while fresh, else from `{base}/schools/`. When
    /// that fails, a stale cached copy or `MenuTypes.fallback` is used; never throws.
    func menuTypes() async -> MenuTypes {
        let key = menuTypesCacheKey
        let cached = await fetcher.cache?.data(for: key)
        let cachedTypes = cached.flatMap { try? JSONDecoder().decode(MenuTypes.self, from: $0.data) }
        if let cached, let cachedTypes, Date.now.timeIntervalSince(cached.savedAt) < Self.menuTypesLifetime {
            return cachedTypes
        }
        guard let data = try? await fetcher.http.data(from: endpoint.schoolsURL) else {
            return cachedTypes ?? .fallback
        }
        // A response that arrived but couldn't be used is remembered too, so a changed format
        // doesn't cost a request on every refresh.
        let types = MenuTypes(schoolsResponse: data, schoolSlug: endpoint.schoolSlug) ?? cachedTypes ?? .fallback
        if let encoded = try? JSONEncoder().encode(types) {
            await fetcher.cache?.store(encoded, for: key)
        }
        return types
    }
}
