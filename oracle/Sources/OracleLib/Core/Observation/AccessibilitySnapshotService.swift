import Foundation
#if os(macOS)
import ApplicationServices
import AppKit
#endif

public final class AccessibilitySnapshotService {
    public init() {}
    
    /// Recursively snapshot an application's UI tree via the Accessibility API.
    public func captureSnapshot(for pid: Int) -> [UIElementModel] {
        #if os(macOS)
        let appElement = AXUIElementCreateApplication(pid_t(pid))
        
        var elements = [UIElementModel]()
        // In a real robust implementation, we would recursively walk AXChildren.
        // For right now, extracting the application-level data to ensure types connect.
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? "AXApplication"
        
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String
        
        // Push root element
        elements.append(UIElementModel(
            id: "pid_\(pid)_root",
            role: role,
            title: title,
            frame: .zero
        ))
        
        return elements
        #else
        return []
        #endif
    }
}
