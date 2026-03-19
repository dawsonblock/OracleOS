import Foundation

public final class ElementLocator {
    public init() {}
    
    public func locateElement(by role: String, in elements: [UIElementModel]) -> UIElementModel? {
        return elements.first { $0.role == role }
    }
}
