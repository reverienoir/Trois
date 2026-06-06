import Foundation

struct HotpepperService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchRestaurants(query: UserQuery) async throws -> [Restaurant] {
        var components = URLComponents(string: "https://webservice.recruit.co.jp/hotpepper/gourmet/v1/")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "lat", value: String(query.location.latitude)),
            URLQueryItem(name: "lng", value: String(query.location.longitude)),
            URLQueryItem(name: "range", value: String(query.hotpepperRange)),
            URLQueryItem(name: "count", value: "30"),
            URLQueryItem(name: "format", value: "json"),
        ]

        if let budgetCode = query.budget?.hotpepperCode {
            items.append(URLQueryItem(name: "budget", value: budgetCode))
        }

        // ジャンルコードがある最初のものを使用（ホットペッパーは1ジャンルのみ対応）
        if let genreCode = query.genres.compactMap({ $0.hotpepperCode }).first {
            items.append(URLQueryItem(name: "genre", value: genreCode))
        }

        components.queryItems = items
        guard let url = components.url else { throw APIError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.httpError
        }

        let decoded = try JSONDecoder().decode(HotpepperResponse.self, from: data)
        let shops = decoded.results.shop ?? []

        return shops
            .map { shop in
                let dist = distance(from: query.location,
                                    to: Coordinate(latitude: shop.lat,
                                                   longitude: shop.lng))
                return Restaurant(
                    id: shop.id,
                    name: shop.name,
                    location: Coordinate(latitude: shop.lat,
                                         longitude: shop.lng),
                    genreName: shop.genre.name,
                    budgetLabel: shop.budget.average.isEmpty ? shop.budget.name : shop.budget.average,
                    distanceMeters: dist,
                    imageURL: URL(string: shop.photo.pc.l),
                    detailURL: URL(string: shop.urls.pc),
                    address: shop.address
                )
            }
            .filter { $0.distanceMeters <= query.radiusMeters }
    }

    private func distance(from a: Coordinate, to b: Coordinate) -> Int {
        let R = 6371000.0
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let x = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(x), sqrt(1 - x))
        return Int(R * c)
    }
}

// MARK: - Decodable

private struct HotpepperResponse: Decodable {
    let results: Results

    struct Results: Decodable {
        let shop: [Shop]?
    }

    struct Shop: Decodable {
        let id: String
        let name: String
        let lat: Double
        let lng: Double
        let address: String
        let genre: Genre
        let budget: Budget
        let photo: Photo
        let urls: URLs

        struct Genre: Decodable { let name: String }
        struct Budget: Decodable {
            let name: String
            let average: String
        }
        struct Photo: Decodable {
            let pc: PC
            struct PC: Decodable { let l: String }
        }
        struct URLs: Decodable { let pc: String }
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case httpError
    case noResults
    case geocodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URLの生成に失敗しました"
        case .httpError: return "サーバーエラーが発生しました"
        case .noResults: return "条件に合うお店が見つかりませんでした"
        case .geocodingFailed: return "入力された地名から場所を特定できませんでした"
        }
    }
}
