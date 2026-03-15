import Foundation

public struct WindowModel: Equatable {
    public let id: String
    public let title: String
    public let frame: CGRect
    
    public init(id: String, title: String, frame: CGRect) {
        self.id = id
        self.title = title
        self.frame = frame
    }
}

public final class WindowScanner {
    public init() {}
    
    public func scanWindows(for pid: Int) -> [WindowModel] {
        return []
    }
}
