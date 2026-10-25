import Foundation

/// Where a school's Nutrislice (Flik) menus are published.
public struct MenuEndpoint: Hashable, Sendable {
    /// e.g. `https://nobleandgreenough.api.flikisdining.com/menu/api`
    public var baseURL: URL
    /// e.g. `noble-and-greenough-school`
    public var schoolSlug: String

    public init(baseURL: URL, schoolSlug: String) {
        self.baseURL = baseURL
        self.schoolSlug = schoolSlug
    }

    /// The Nobles dining hall.
    public static let nobles = MenuEndpoint(
        baseURL: URL(string: "https://nobleandgreenough.api.flikisdining.com/menu/api")!,
        schoolSlug: "noble-and-greenough-school"
    )

    /// The week of one menu type that contains `date`:
    /// `{base}/weeks/school/{school}/menu-type/{slug}/{yyyy}/{MM}/{dd}/`.
    public func weekURL(menuType slug: String, date: LocalDate) -> URL {
        let day = date.iso.replacingOccurrences(of: "-", with: "/")
        return baseURL.appending(path: "weeks/school/\(schoolSlug)/menu-type/\(slug)/\(day)", directoryHint: .isDirectory)
    }

    /// Every school on this Nutrislice site with its active menu types: `{base}/schools/`.
    public var schoolsURL: URL {
        baseURL.appending(path: "schools", directoryHint: .isDirectory)
    }
}
