import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Search Result Model

struct LocationSearchResult: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: LocationSearchResult, rhs: LocationSearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// swiftlint:disable:next type_body_length
@MainActor
class LocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var placeName: String?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var error: String?

    // Search
    @Published var searchResults: [LocationSearchResult] = []
    @Published var isSearching = false

    private var locationContinuation: CheckedContinuation<(CLLocation, String?)?, Never>?
    private var searchCompleter: MKLocalSearchCompleter?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func fetchCurrentLocation() async -> (CLLocation, String?)? {
        isLoading = true
        error = nil

        // Check authorization
        let status = manager.authorizationStatus
        if status == .notDetermined {
            requestPermission()
            // Wait for authorization
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        let currentStatus = manager.authorizationStatus
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            isLoading = false
            error = "Permissão de localização não concedida"
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
            self.manager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        // Usando nova API MKReverseGeocodingRequest do iOS 26
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        do {
            let mapItems = try await request.mapItems
            if let mapItem = mapItems.first {
                // Usar address.shortAddress para endereço compacto (iOS 26)
                return mapItem.address?.shortAddress
            }
        } catch {
            print("Geocoding error: \(error)")
        }
        return nil
    }

    // MARK: - Reverse Geocode Public

    func reverseGeocodeCoordinate(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        return await reverseGeocode(location)
    }

    // MARK: - Location Search

    func searchLocation(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]

        // Se temos localização atual, usar como região de busca
        if let currentLocation = location {
            request.region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
        }

        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            searchResults = response.mapItems.compactMap { item -> LocationSearchResult? in
                guard let name = item.name else { return nil }

                // Usar nova API address do iOS 26
                let address = item.address?.shortAddress ?? ""

                return LocationSearchResult(
                    name: name,
                    address: address,
                    coordinate: item.location.coordinate
                )
            }
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }

        isSearching = false
    }

    func clearSearch() {
        searchResults = []
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            Task { @MainActor in
                self.locationContinuation?.resume(returning: nil)
                self.locationContinuation = nil
                self.isLoading = false
            }
            return
        }

        Task { @MainActor in
            self.location = location
            let placeName = await self.reverseGeocode(location)
            self.placeName = placeName
            self.isLoading = false
            self.locationContinuation?.resume(returning: (location, placeName))
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
        Task { @MainActor in
            self.error = "Não foi possível obter a localização"
            self.isLoading = false
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
