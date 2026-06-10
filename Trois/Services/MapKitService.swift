import Foundation
import MapKit

struct MapKitService {

    func fetchFastFood(query: UserQuery) async throws -> [Restaurant] {
        // 複数キーワードで検索してマージ（チェーン網羅率を上げる）
        let keywords = ["ファストフード", "バーガー", "牛丼", "ファミレス", "コンビニ"]
        var seen = Set<String>()
        var results: [Restaurant] = []

        for keyword in keywords {
            let items = try await search(keyword: keyword, query: query)
            for item in items {
                let key = item.name
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                results.append(item)
            }
        }

        return results
            .sorted { $0.distanceMeters < $1.distanceMeters }
            .prefix(15)
            .map { $0 }
    }

    private func search(keyword: String, query: UserQuery) async throws -> [Restaurant] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: query.location.latitude,
                longitude: query.location.longitude
            ),
            latitudinalMeters: Double(query.radiusMeters) * 2,
            longitudinalMeters: Double(query.radiusMeters) * 2
        )
        request.resultTypes = .pointOfInterest

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        return response.mapItems.compactMap { item -> Restaurant? in
            guard let location = item.placemark.location else { return nil }
            let coord = Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            let dist = haversineMeters(from: query.location, to: coord)
            guard dist <= query.radiusMeters else { return nil }
            guard let name = item.name, !name.isEmpty else { return nil }

            let address = [item.placemark.thoroughfare, item.placemark.subLocality]
                .compactMap { $0 }.joined(separator: " ")

            return Restaurant(
                id: "\(name)_\(coord.latitude)_\(coord.longitude)",
                name: name,
                location: coord,
                genreName: String(localized: "ファストフード"),
                budgetLabel: "",
                distanceMeters: dist,
                imageURL: nil,
                detailURL: nil,
                address: address.isEmpty ? nil : address
            )
        }
    }

    private func haversineMeters(from a: Coordinate, to b: Coordinate) -> Int {
        let R = 6371000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let x = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return Int(R * 2 * atan2(sqrt(x), sqrt(1 - x)))
    }
}
