import Foundation

// ─────────────────────────────────────────────────────────
// RecipeStore — in-memory recipe catalogue
//
// Stores Recipe values keyed by name. Supports JSON import
// for recipe authoring. No file-system dependency — Oracle
// recipes are re-loaded from the graph store on cold start.
// ─────────────────────────────────────────────────────────

/// In-memory catalogue of named recipes.
///
/// Recipes are loaded from JSON at startup (or authored at runtime).
/// The store validates schema and parameter declarations on import.
public final class RecipeStore {

    // ── Storage ──────────────────────────────────────────

    private var recipes: [String: Recipe] = [:]

    public init() {}

    // ── Write ────────────────────────────────────────────

    /// Add or replace a recipe in the store.
    public func add(_ recipe: Recipe) {
        recipes[recipe.name] = recipe
    }

    /// Remove a recipe by name.
    @discardableResult
    public func remove(named name: String) -> Bool {
        recipes.removeValue(forKey: name) != nil
    }

    /// Import a recipe from a raw JSON string.
    ///
    /// - Returns: The recipe name on success.
    /// - Throws: `RecipeStoreError.invalidJSON` with a descriptive message.
    @discardableResult
    public func importJSON(_ jsonString: String) throws -> String {
        guard let data = jsonString.data(using: .utf8) else {
            throw RecipeStoreError.invalidJSON("Failed to encode JSON string as UTF-8")
        }
        do {
            let recipe = try JSONDecoder().decode(Recipe.self, from: data)
            add(recipe)
            return recipe.name
        } catch let DecodingError.keyNotFound(key, context) {
            throw RecipeStoreError.invalidJSON("Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch let DecodingError.typeMismatch(_, context) {
            throw RecipeStoreError.invalidJSON("Type mismatch at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(_, context) {
            throw RecipeStoreError.invalidJSON("Value not found at \(context.codingPath.map(\.stringValue).joined(separator: "."))")
        } catch {
            throw RecipeStoreError.invalidJSON(error.localizedDescription)
        }
    }

    // ── Read ─────────────────────────────────────────────

    /// Retrieve a recipe by name.
    public func recipe(named name: String) -> Recipe? {
        recipes[name]
    }

    /// All stored recipes sorted alphabetically.
    public func allRecipes() -> [Recipe] {
        recipes.values.sorted { $0.name < $1.name }
    }

    /// Total number of stored recipes.
    public var count: Int { recipes.count }
}

// MARK: – Errors

public enum RecipeStoreError: Error, Equatable {
    case invalidJSON(String)
    case recipeNotFound(String)
}
