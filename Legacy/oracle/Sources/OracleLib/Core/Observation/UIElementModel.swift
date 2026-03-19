import Foundation

public struct UIElementModel: Equatable {
    public let id: String
    public let role: String
    public let title: String?
    public let frame: CGRect
    
    public init(id: String, role: String, title: String?, frame: CGRect) {
        self.id = id
        self.role = role
        self.title = title
        self.frame = frame
    }
}
