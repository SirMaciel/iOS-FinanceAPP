import Foundation

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(Int, String)
    case unauthorized
    case networkError(Error)
}

class APIClient {
    static let shared = APIClient()

    private let baseURL = "https://finance-backend-production-1aa4.up.railway.app"
    private var token: String?

    private init() {}

    func setToken(_ token: String?) {
        self.token = token
    }

    func request<T: Decodable>(
        _ endpoint: String,
        method: String = "GET",
        body: Encodable? = nil
    ) async throws -> T {
        let fullURL = baseURL + endpoint
        print("🌐 API Request: \(method) \(fullURL)")

        guard let url = URL(string: fullURL) else {
            print("❌ Invalid URL: \(fullURL)")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("🔑 Token: \(String(token.prefix(20)))...")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            print("✅ Response received")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.noData
            }

            print("📊 Status: \(httpResponse.statusCode)")

            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }

            guard 200...299 ~= httpResponse.statusCode else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ HTTP Error: \(message)")
                throw APIError.httpError(httpResponse.statusCode, message)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            print("❌ Decoding Error: \(error)")
            throw APIError.decodingError(error)
        } catch {
            print("❌ Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }

    func requestVoid(
        _ endpoint: String,
        method: String = "DELETE",
        body: Encodable? = nil
    ) async throws {
        guard let url = URL(string: baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.noData
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode, "Request failed")
        }
    }
}
