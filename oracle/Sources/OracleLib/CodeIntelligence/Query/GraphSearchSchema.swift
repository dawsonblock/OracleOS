import Foundation

public enum QueryRoutingStrategy {
    case local
    case sidecar(url: URL?)
    case auto
}

public struct GraphSearchQuery: Equatable {
    public let symbol: String
    public let kind: SymbolKind
    public let scope: SearchScope
    
    public enum SymbolKind {
        case function
        case type
        case variable
        case any
    }
    
    public enum SearchScope: Equatable {
        case global
        case file(String)
        case module(String)
    }
    
    public init(symbol: String, kind: SymbolKind = .any, scope: SearchScope = .global) {
        self.symbol = symbol
        self.kind = kind
        self.scope = scope
    }
}

public struct GraphSearchResult: Equatable {
    public let file: String
    public let line: Int
    public let character: Int
    public let contextSnippet: String?
    public let confidence: Double
    
    public init(file: String, line: Int, character: Int = 0, contextSnippet: String? = nil, confidence: Double = 1.0) {
        self.file = file
        self.line = line
        self.character = character
        self.contextSnippet = contextSnippet
        self.confidence = confidence
    }
}
