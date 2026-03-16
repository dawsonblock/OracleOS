import Foundation

public enum CriterionMatchType: String, Codable, Sendable, Equatable {
    case exact
    case contains
}

public struct Criterion: Codable, Sendable, Equatable {
    public let attribute: String
    public let value: String
    public let matchType: CriterionMatchType

    public init(attribute: String, value: String, matchType: CriterionMatchType) {
        self.attribute = attribute
        self.value = value
        self.matchType = matchType
    }
}

public struct Locator: Codable, Sendable, Equatable {
    public let criteria: [Criterion]
    public var computedNameContains: String?

    public init(criteria: [Criterion] = [], computedNameContains: String? = nil) {
        self.criteria = criteria
        self.computedNameContains = computedNameContains
    }
}

@MainActor
public enum LocatorBuilder {
    public static func build(
        query: String? = nil,
        role: String? = nil,
        domId: String? = nil,
        domClass: String? = nil,
        identifier: String? = nil
    ) -> Locator {
        var criteria: [Criterion] = []

        if let domId {
            criteria.append(Criterion(attribute: "AXDOMIdentifier", value: domId, matchType: .exact))
            return Locator(criteria: criteria)
        }

        if let identifier {
            criteria.append(Criterion(attribute: "AXIdentifier", value: identifier, matchType: .exact))
        }

        if let role {
            criteria.append(Criterion(attribute: "AXRole", value: role, matchType: .exact))
        }

        if let domClass {
            criteria.append(Criterion(attribute: "AXDOMClassList", value: domClass, matchType: .contains))
        }

        return Locator(criteria: criteria, computedNameContains: query)
    }

    public static func fromQuery(_ query: String) -> Locator {
        build(query: query)
    }

    public static func forRole(_ role: String, named query: String? = nil) -> Locator {
        build(query: query, role: role)
    }
}
