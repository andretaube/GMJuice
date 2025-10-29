import SwiftUI

@MainActor
@Observable
class DeviceOrientationManager {
    var orientation: UIDeviceOrientation
    nonisolated(unsafe) private var observer: NSObjectProtocol?
    
    init() {
        self.orientation = UIDevice.current.orientation
        
        // Enable orientation notifications
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // Listen for orientation changes
        self.observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.orientation = UIDevice.current.orientation
            }
        }
    }
    
    deinit {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    var isLandscape: Bool {
        orientation.isLandscape
    }
    
    var isPortrait: Bool {
        orientation.isPortrait
    }
    
    var isFlat: Bool {
        orientation.isFlat
    }
}
