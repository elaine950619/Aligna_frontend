import Foundation
import CoreLocation
import UIKit

final class LocationPermissionCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()
    private var didBecomeActiveObserver: NSObjectProtocol?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self

        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshAuthorizationStatus()
        }
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    var isDeniedOrRestricted: Bool {
        switch authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = manager.authorizationStatus
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
        refreshAuthorizationStatus()
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
