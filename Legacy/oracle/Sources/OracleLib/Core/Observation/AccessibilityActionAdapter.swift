import Foundation

public final class AccessibilityActionAdapter {
    public init() {}
    
    public func performAction(on element: UIElementModel, action: String) -> Bool {
        return true
    }
}
