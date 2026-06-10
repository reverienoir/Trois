import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var coordinate: Coordinate? = nil
    @Published var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.startUpdatingLocation()
    }

    var isAvailable: Bool {
        coordinate != nil && (status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    var statusText: String {
        switch status {
        case .notDetermined: return String(localized: "位置情報を確認中…")
        case .denied, .restricted: return String(localized: "位置情報の許可が必要です")
        case .authorizedWhenInUse, .authorizedAlways:
            return coordinate != nil
                ? String(localized: "現在地を取得しました")
                : String(localized: "現在地を取得中…")
        @unknown default: return ""
        }
    }

    var statusIcon: String {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return coordinate != nil ? "location.fill" : "location"
        case .denied, .restricted: return "location.slash"
        default: return "location"
        }
    }

    var statusColor: Color {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return coordinate != nil ? .green : .orange
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.coordinate = Coordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.status = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.startUpdatingLocation()
            }
        }
    }
}
