import Foundation

public final class AccessibilitySnapshotService {
    public init() {}
    
    public func captureSnapshot(for pid: Int) -> [UIElementModel] {
        return [
            UIElementModel(id: "mock_1", role: "AXButton", title: "OK", frame: CGRect(x: 10, y: 10, width: 100, height: 40))
        ]
    }
}
