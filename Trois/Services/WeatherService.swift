import Foundation

struct WeatherInfo {
    let temperatureCelsius: Double
    let weatherText: String
}

struct WeatherService {
    // Open-Meteo: APIキー不要の無料天気API
    func fetchWeather(at coordinate: Coordinate) async -> WeatherInfo? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let current = decoded.current
            return WeatherInfo(
                temperatureCelsius: current.temperature_2m,
                weatherText: weatherText(forCode: current.weather_code)
            )
        } catch {
            return nil
        }
    }

    private func weatherText(forCode code: Int) -> String {
        switch code {
        case 0: return "快晴"
        case 1, 2: return "晴れ時々くもり"
        case 3: return "くもり"
        case 45, 48: return "霧"
        case 51, 53, 55, 56, 57: return "霧雨"
        case 61, 63, 65, 66, 67: return "雨"
        case 71, 73, 75, 77: return "雪"
        case 80, 81, 82: return "にわか雨"
        case 85, 86: return "にわか雪"
        case 95, 96, 99: return "雷雨"
        default: return "天候不明"
        }
    }

    private struct OpenMeteoResponse: Decodable {
        let current: Current
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
        }
    }
}
