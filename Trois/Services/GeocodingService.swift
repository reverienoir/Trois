import Foundation
import CoreLocation

struct GeocodingService {
    // シミュレータでは CLGeocoder が "No Results" を返しがちなため、
    // HTTPベースの無料ジオコーディングAPI（Open-Meteo Geocoding、キー不要）を優先的に使う。
    func geocode(address: String) async throws -> Coordinate {
        let trimmed = address.trimmingCharacters(in: .whitespaces)

        // 1. そのまま試す
        if let coord = try? await geocodeViaOpenMeteo(address: trimmed) {
            return coord
        }

        // 2. 「駅」「市」「区」「町」などの接尾辞を除いて再試行（駅名はジオコーディングDBに無いことが多い）
        for suffix in ["駅", "市", "区", "町", "村"] {
            if trimmed.hasSuffix(suffix) {
                let stripped = String(trimmed.dropLast(suffix.count))
                if !stripped.isEmpty, let coord = try? await geocodeViaOpenMeteo(address: stripped) {
                    return coord
                }
            }
        }

        // 3. フォールバック: CLGeocoder
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.geocodeAddressString(trimmed),
           let location = placemarks.first?.location {
            return Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }

        throw APIError.geocodingFailed
    }

    private func geocodeViaOpenMeteo(address: String) async throws -> Coordinate {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: address),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "ja"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)
        guard let result = decoded.results?.first else {
            throw APIError.geocodingFailed
        }
        return Coordinate(latitude: result.latitude, longitude: result.longitude)
    }

    private struct OpenMeteoGeocodingResponse: Decodable {
        let results: [Result]?
        struct Result: Decodable {
            let latitude: Double
            let longitude: Double
        }
    }
}
