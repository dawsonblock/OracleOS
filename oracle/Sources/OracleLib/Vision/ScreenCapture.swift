import AppKit
import CoreGraphics
import Foundation

// MARK: - ScreenshotResult

/// Encoded screenshot payload and window metadata for sidecar-backed vision tools.
public struct ScreenshotResult: Sendable, Equatable {
    public let base64PNG: String
    public let width: Int
    public let height: Int
    public let windowTitle: String?
    public let mimeType: String
    public let windowX: Double
    public let windowY: Double
    public let windowWidth: Double
    public let windowHeight: Double

    public init(
        base64PNG: String,
        width: Int,
        height: Int,
        windowTitle: String? = nil,
        mimeType: String = "image/png",
        windowX: Double = 0,
        windowY: Double = 0,
        windowWidth: Double = 0,
        windowHeight: Double = 0
    ) {
        self.base64PNG = base64PNG
        self.width = width
        self.height = height
        self.windowTitle = windowTitle
        self.mimeType = mimeType
        self.windowX = windowX
        self.windowY = windowY
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
    }
}

// MARK: - ScreenCapture

/// Captures screenshots of specific windows for optional vision processing.
public enum ScreenCapture {

    /// Failure reasons returned by `captureWindowSyncWithReason`.
    public enum CaptureFailure: Sendable, Equatable {
        case noPermission
        case windowListUnavailable
        case noWindowsForApp
        case captureReturnedNil(windowID: CGWindowID)
        case imageTooSmall(width: Int, height: Int)
        case pngEncodingFailed
    }

    private static let logger = ExecutionLogger()

    /// Check if Screen Recording permission is granted.
    public static func hasPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request Screen Recording permission.
    public static func requestPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Capture a window synchronously using CoreGraphics.
    public static func captureWindowSync(
        pid: pid_t,
        fullResolution: Bool = false
    ) -> ScreenshotResult? {
        captureWindowSyncWithReason(pid: pid, fullResolution: fullResolution).0
    }

    /// Capture a window synchronously and return a detailed failure reason on nil.
    public static func captureWindowSyncWithReason(
        pid: pid_t,
        fullResolution: Bool = false
    ) -> (ScreenshotResult?, CaptureFailure?) {
        guard hasPermission() else {
            logger.log("Vision screenshot denied: Screen Recording permission missing", level: .warn)
            return (nil, .noPermission)
        }

        guard let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID)
            as? [[CFString: Any]] else {
            return (nil, .windowListUnavailable)
        }

        let candidates = windowList.filter { info in
            guard let ownerPID = info[kCGWindowOwnerPID] as? pid_t,
                  ownerPID == pid else { return false }
            let layer = info[kCGWindowLayer] as? Int ?? -1
            guard layer == 0 else { return false }
            guard let bounds = info[kCGWindowBounds] as? [String: Any],
                  let width = bounds["Width"] as? Double,
                  let height = bounds["Height"] as? Double else {
                return false
            }
            return width > 50 && height > 50
        }

        guard let bestWindow = candidates.max(by: { windowArea($0) < windowArea($1) }) else {
            return (nil, .noWindowsForApp)
        }

        guard let windowID = bestWindow[kCGWindowNumber] as? CGWindowID else {
            return (nil, .noWindowsForApp)
        }

        let imageOptions: CGWindowImageOption = fullResolution
            ? [.bestResolution, .boundsIgnoreFraming]
            : [.nominalResolution, .boundsIgnoreFraming]

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            imageOptions
        ) else {
            return (nil, .captureReturnedNil(windowID: windowID))
        }

        if cgImage.width < 10 || cgImage.height < 10 {
            return (nil, .imageTooSmall(width: cgImage.width, height: cgImage.height))
        }

        let finalImage: CGImage
        if !fullResolution && cgImage.width > 1280 {
            finalImage = downsample(cgImage, maxWidth: 1280)
        } else {
            finalImage = cgImage
        }

        let bitmap = NSBitmapImageRep(cgImage: finalImage)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return (nil, .pngEncodingFailed)
        }

        let bounds = bestWindow[kCGWindowBounds] as? [String: Any]
        return (
            ScreenshotResult(
                base64PNG: pngData.base64EncodedString(),
                width: finalImage.width,
                height: finalImage.height,
                windowTitle: bestWindow[kCGWindowName] as? String,
                mimeType: "image/png",
                windowX: bounds?["X"] as? Double ?? 0,
                windowY: bounds?["Y"] as? Double ?? 0,
                windowWidth: bounds?["Width"] as? Double ?? 0,
                windowHeight: bounds?["Height"] as? Double ?? 0
            ),
            nil
        )
    }

    private static func windowArea(_ info: [CFString: Any]) -> Double {
        guard let bounds = info[kCGWindowBounds] as? [String: Any],
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double else {
            return 0
        }
        return width * height
    }

    private static func downsample(_ image: CGImage, maxWidth: Int) -> CGImage {
        let aspectRatio = Double(image.height) / Double(image.width)
        let newHeight = Int(Double(maxWidth) * aspectRatio)

        guard let context = CGContext(
            data: nil,
            width: maxWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return image
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: maxWidth, height: newHeight))
        return context.makeImage() ?? image
    }
}
