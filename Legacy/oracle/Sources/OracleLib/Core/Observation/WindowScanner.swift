import Foundation
import CoreGraphics

public struct WindowModel: Equatable {
    public let id: String
    public let title: String
    public let frame: CGRect
    public let isOnScreen: Bool
    
    public init(id: String, title: String, frame: CGRect, isOnScreen: Bool) {
        self.id = id
        self.title = title
        self.frame = frame
        self.isOnScreen = isOnScreen
    }
}

public final class WindowScanner {
    public init() {}
    
    /// Scans CGWindowList for geometry mapping
    public func scanWindows(for pid: Int) -> [WindowModel] {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows = [WindowModel]()
        for info in windowInfoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int, ownerPID == pid else {
                continue
            }
            
            let title = info[kCGWindowName as String] as? String ?? ""
            let rawID = info[kCGWindowNumber as String] as? Int ?? 0
            
            // Extract bounds dictionary
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let w = boundsDict["Width"] as? CGFloat,
                  let h = boundsDict["Height"] as? CGFloat else {
                continue
            }
            
            let frame = CGRect(x: x, y: y, width: w, height: h)
            windows.append(WindowModel(
                id: String(rawID),
                title: title,
                frame: frame,
                isOnScreen: true
            ))
        }
        
        return windows
    }
}
