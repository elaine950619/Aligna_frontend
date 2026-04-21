import SwiftUI
import MapKit
import CoreLocation

// MARK: - Equatable conformance

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Aspect (相位) calculations

enum Aspect: String {
    case conjunction                    // 0°
    case sextile                        // 60°
    case square                         // 90°
    case trine                          // 120°
    case opposition                     // 180°

    /// Stable (English) identifier used in MKOverlay.title so sectorColor() stays i18n-safe.
    var titleID: String { rawValue }

    var displayName: String {
        switch self {
        case .conjunction: return String(localized: "cosmic_map.aspect.conjunction.name")
        case .sextile:     return String(localized: "cosmic_map.aspect.sextile.name")
        case .square:      return String(localized: "cosmic_map.aspect.square.name")
        case .trine:       return String(localized: "cosmic_map.aspect.trine.name")
        case .opposition:  return String(localized: "cosmic_map.aspect.opposition.name")
        }
    }

    var color: UIColor {
        switch self {
        case .conjunction, .trine: return UIColor.systemGreen.withAlphaComponent(0.85)
        case .sextile:             return UIColor.white.withAlphaComponent(0.75)
        case .square, .opposition: return UIColor.systemOrange.withAlphaComponent(0.85)
        }
    }

    var meaning: String {
        switch self {
        case .conjunction: return String(localized: "cosmic_map.aspect.conjunction.meaning")
        case .sextile:     return String(localized: "cosmic_map.aspect.sextile.meaning")
        case .square:      return String(localized: "cosmic_map.aspect.square.meaning")
        case .trine:       return String(localized: "cosmic_map.aspect.trine.meaning")
        case .opposition:  return String(localized: "cosmic_map.aspect.opposition.meaning")
        }
    }
}

// MARK: - Astro body identity (used for body-specific aspect semantics)

enum AstroBody: String {
    case sun, moon, ascendant

    var label: String {
        switch self {
        case .sun:       return String(localized: "cosmic_map.body.sun.label")
        case .moon:      return String(localized: "cosmic_map.body.moon.label")
        case .ascendant: return String(localized: "cosmic_map.body.ascendant.label")
        }
    }

    /// Body-specific aspect reading — Sun's square ≠ Moon's square. One-sentence explanation.
    /// Key format: `cosmic_map.meaning.<body>.<aspect>` where aspect is rawValue or "none".
    func meaning(for aspect: Aspect?) -> String {
        let aspectKey = aspect?.rawValue ?? "none"
        let key = "cosmic_map.meaning.\(rawValue).\(aspectKey)"
        return String(localized: String.LocalizationValue(key))
    }
}

// Calculate aspect between two ecliptic longitudes
func calculateAspect(lon1: Double, lon2: Double) -> Aspect? {
    let diff = abs(lon1 - lon2)
    let angle = min(diff, 360 - diff)  // take smaller angle
    
    if angle <= 10 { return .conjunction }           // 0° ± 10°
    if abs(angle - 60) <= 6 { return .sextile }      // 60° ± 6°
    if abs(angle - 90) <= 8 { return .square }       // 90° ± 8°
    if abs(angle - 120) <= 8 { return .trine }       // 120° ± 8°
    if abs(angle - 180) <= 10 { return .opposition } // 180° ± 10°
    
    return nil  // no significant aspect
}

// MARK: - Data model  (ecliptic longitudes, 0–360°)

struct AstroWheelData {
    let sunLongitude:       Double
    let moonLongitude:      Double
    let ascendantLongitude: Double
    let sunSign:            String
    let moonSign:           String
    let ascendantSign:      String
}

// MARK: - Continuous location tracker

@MainActor
final class CompassLocationFetcher: NSObject, CLLocationManagerDelegate, ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var heading: CLLocationDirection = 0  // magnetic heading (0-360°)
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = 100   // redraw every 100 m
        manager.headingFilter   = 5     // update heading every 5°
    }

    func startTracking() {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let coord = locations.last?.coordinate else { return }
        Task { @MainActor in self.coordinate = coord }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {}
    
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }  // invalid heading
        Task { @MainActor in
            self.heading = newHeading.magneticHeading
        }
    }
}

// MARK: - Geographic helper (great-circle destination)

private func destinationCoord(from origin: CLLocationCoordinate2D,
                               azimuth: Double,
                               distance: Double) -> CLLocationCoordinate2D {
    let R    = 6_371_000.0
    let d    = distance / R
    let lat1 = origin.latitude  * .pi / 180
    let lon1 = origin.longitude * .pi / 180
    let brng = azimuth          * .pi / 180
    let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(brng))
    let lon2 = lon1 + atan2(sin(brng) * sin(d) * cos(lat1),
                            cos(d) - sin(lat1) * sin(lat2))
    return CLLocationCoordinate2D(latitude:  lat2 * 180 / .pi,
                                  longitude: lon2 * 180 / .pi)
}

// MARK: - Create annular sector polygon

/// Build a polygon approximating an annular sector (piece of a ring), with `numSegments` points per arc.
/// Uses the SHORTEST signed arc between startBearing → endBearing, so sectors that straddle the
/// 0°/360° boundary (e.g. Pisces when natalAsc ≠ 0°) stay 30° wide instead of wrapping 330°
/// the wrong way around the ring.
private func createAnnularSector(
    center: CLLocationCoordinate2D,
    innerRadius: Double,
    outerRadius: Double,
    startBearing: Double,
    endBearing: Double,
    numSegments: Int = 20
) -> MKPolygon {
    // Shortest signed angular difference, in [-180, 180]
    var signedDiff = endBearing - startBearing
    while signedDiff >  180 { signedDiff -= 360 }
    while signedDiff < -180 { signedDiff += 360 }

    var coords = [CLLocationCoordinate2D]()

    // Outer arc (start → end, shortest way)
    for i in 0...numSegments {
        let frac = Double(i) / Double(numSegments)
        let brng = startBearing + signedDiff * frac
        coords.append(destinationCoord(from: center, azimuth: brng, distance: outerRadius))
    }

    // Inner arc (end → start, reversed)
    for i in 0...numSegments {
        let frac = Double(numSegments - i) / Double(numSegments)
        let brng = startBearing + signedDiff * frac
        coords.append(destinationCoord(from: center, azimuth: brng, distance: innerRadius))
    }

    return MKPolygon(coordinates: &coords, count: coords.count)
}

// MARK: - Custom annotation

final class AstroWheelAnnotation: NSObject, MKAnnotation {
    let coordinate:   CLLocationCoordinate2D
    let glyph:        String
    let color:        UIColor
    let fontSize:     CGFloat
    let useAstroFont: Bool
    let isBody:       Bool   // body symbols get heavier backdrop

    init(coordinate: CLLocationCoordinate2D, glyph: String, color: UIColor,
         fontSize: CGFloat, useAstroFont: Bool, isBody: Bool) {
        self.coordinate   = coordinate
        self.glyph        = glyph
        self.color        = color
        self.fontSize     = fontSize
        self.useAstroFont = useAstroFont
        self.isBody       = isBody
    }
}

// MARK: - Globe + bi-wheel (UIViewRepresentable)

struct AstroGlobeChart: UIViewRepresentable {
    let center:       CLLocationCoordinate2D
    let transit:      AstroWheelData?
    let natal:        AstroWheelData?
    let transitColor: UIColor
    let natalColor:   UIColor

    let showSunSector: Bool
    let showMoonSector: Bool
    let showAscSector: Bool

    // Camera — city-level zoom (shows central city + adjacent districts)
    static let initialCameraAlt: Double = 15_000   // 15 km altitude → ~city coverage
    // Tell MapKit the bottom strip is obscured by the Legend so the user pin rises above centre.
    static let mapBottomInset: CGFloat = 180

    // Dynamic geometry — outer zodiac ring (zebra) + sectors radiating from center
    static func zodiacOuter(cameraAlt: Double) -> Double { cameraAlt * 0.105 }     // ring outer edge
    static func zodiacInner(cameraAlt: Double) -> Double { cameraAlt * 0.097 }     // ring inner edge
    /// Body token centres — sit just inside the ring's inner edge. After shrinking the disks
    /// to fontSize × 1.5 we can push closer; the small remaining gap keeps disks from
    /// touching the zebra band.
    static func bodyRadius(cameraAlt: Double)  -> Double { cameraAlt * 0.090 }
    static func sectorStart(cameraAlt: Double) -> Double { cameraAlt * 0.008 }     // aspect sector starts near user dot

    // Zodiac glyphs — U+FE0E forces TEXT presentation, not Apple Color Emoji.
    private static let zodiacGlyphs = [
        "♈\u{FE0E}","♉\u{FE0E}","♊\u{FE0E}","♋\u{FE0E}",
        "♌\u{FE0E}","♍\u{FE0E}","♎\u{FE0E}","♏\u{FE0E}",
        "♐\u{FE0E}","♑\u{FE0E}","♒\u{FE0E}","♓\u{FE0E}"
    ]
    static let astroFont = "NotoSansSymbols2-Regular"

    func makeCoordinator() -> Coordinator {
        Coordinator(
            center: center,
            transit: transit,
            natal: natal,
            transitColor: transitColor,
            natalColor: natalColor,
            showSunSector: showSunSector,
            showMoonSector: showMoonSector,
            showAscSector: showAscSector
        )
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass      = false  // native compass hidden — we own the top-right chrome
        map.pointOfInterestFilter = .excludingAll
        map.overrideUserInterfaceStyle = .dark
        map.isScrollEnabled = false   // lock centre on user

        // Shift the visible centre UP so the user pin isn't hidden behind the bottom Legend.
        map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: Self.mapBottomInset, right: 0)

        // Map rotates to match device heading (compass mode)
        map.userTrackingMode = .followWithHeading

        // Flat 2D map (iOS 16+) — prevents ring flickering on curved globe
        map.preferredConfiguration = MKStandardMapConfiguration(
            elevationStyle: .flat,
            emphasisStyle: .muted
        )

        // 2D top-down camera (pitch = 0 for flat overhead view)
        let cam = MKMapCamera(
            lookingAtCenter: center,
            fromDistance: Self.initialCameraAlt,
            pitch: 0,  // flat overhead view
            heading: 0
        )
        map.setCamera(cam, animated: false)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Sync data to coordinator
        context.coordinator.center       = center
        context.coordinator.transit      = transit
        context.coordinator.natal        = natal
        context.coordinator.transitColor = transitColor
        context.coordinator.natalColor   = natalColor
        context.coordinator.showSunSector = showSunSector
        context.coordinator.showMoonSector = showMoonSector
        context.coordinator.showAscSector = showAscSector
        
        // Ensure tracking mode stays active (in case user interaction changed it)
        if uiView.userTrackingMode != .followWithHeading {
            uiView.setUserTrackingMode(.followWithHeading, animated: true)
        }
        
        // Re-snap centre to user if location changed (preserve zoom, let heading follow device)
        if context.coordinator.lastCenter != center {
            let cur = uiView.camera
            let newCam = MKMapCamera(
                lookingAtCenter: center,
                fromDistance: cur.centerCoordinateDistance,
                pitch: 0,  // keep flat 2D view
                heading: cur.heading  // keep current heading (device-driven)
            )
            uiView.setCamera(newCam, animated: true)
            context.coordinator.lastCenter = center
        }

        // Refresh overlays/annotations if data OR camera altitude changed
        let sig = signature(cameraAlt: uiView.camera.centerCoordinateDistance)
        if sig != context.coordinator.lastSignature {
            context.coordinator.lastSignature = sig
            context.coordinator.refreshOverlays(on: uiView)
        }
    }

    // MARK: - Build overlays + annotations

    private func signature(cameraAlt: Double) -> String {
        """
        \(center.latitude),\(center.longitude),\
        \(transit?.sunLongitude ?? -1),\(transit?.moonLongitude ?? -1),\(transit?.ascendantLongitude ?? -1),\
        \(natal?.sunLongitude ?? -1),\(natal?.moonLongitude ?? -1),\(natal?.ascendantLongitude ?? -1),\
        \(transitColor),\(natalColor),\(Int(cameraAlt)),\
        \(showSunSector),\(showMoonSector),\(showAscSector)
        """
    }

    // MARK: - Coordinator (map delegate)

    final class Coordinator: NSObject, MKMapViewDelegate {
        var center:        CLLocationCoordinate2D
        var transit:       AstroWheelData?
        var natal:         AstroWheelData?
        var transitColor:  UIColor
        var natalColor:    UIColor
        var showSunSector: Bool
        var showMoonSector: Bool
        var showAscSector: Bool
        var lastCenter:    CLLocationCoordinate2D?
        var lastSignature: String = ""
        var lastRefreshCenter: CLLocationCoordinate2D?  // track last refresh position
        var lastRefreshAltitude: Double = 0  // track last refresh camera altitude

        init(center: CLLocationCoordinate2D, transit: AstroWheelData?, natal: AstroWheelData?,
             transitColor: UIColor, natalColor: UIColor,
             showSunSector: Bool, showMoonSector: Bool, showAscSector: Bool) {
            self.center       = center
            self.transit      = transit
            self.natal        = natal
            self.transitColor = transitColor
            self.natalColor   = natalColor
            self.showSunSector = showSunSector
            self.showMoonSector = showMoonSector
            self.showAscSector = showAscSector
        }

        // Refresh when map center moves significantly OR zoom changes significantly
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let currentCenter = mapView.centerCoordinate
            let currentAltitude = mapView.camera.centerCoordinateDistance
            
            var shouldRefresh = false
            
            // Check if center moved significantly (> 50 meters)
            if let lastRefresh = lastRefreshCenter {
                let distance = distanceBetween(lastRefresh, currentCenter)
                if distance > 50 {
                    shouldRefresh = true
                }
            } else {
                shouldRefresh = true  // first time
            }
            
            // Check if zoom changed significantly (> 20% altitude change)
            if lastRefreshAltitude > 0 {
                let altitudeChange = abs(currentAltitude - lastRefreshAltitude) / lastRefreshAltitude
                if altitudeChange > 0.20 {
                    shouldRefresh = true
                }
            } else {
                shouldRefresh = true  // first time
            }
            
            if shouldRefresh {
                lastRefreshCenter = currentCenter
                lastRefreshAltitude = currentAltitude
                refreshOverlays(on: mapView)
            }
        }
        
        // Calculate distance between two coordinates (in meters)
        private func distanceBetween(_ coord1: CLLocationCoordinate2D, 
                                    _ coord2: CLLocationCoordinate2D) -> Double {
            let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            return loc1.distance(from: loc2)
        }
        
        // Keep heading mode active even if user accidentally exits it
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            if mode != .followWithHeading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    mapView.setUserTrackingMode(.followWithHeading, animated: true)
                }
            }
        }
        
        // Refresh overlays and annotations based on current camera altitude
        func refreshOverlays(on map: MKMapView) {
            map.removeOverlays(map.overlays)
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
            guard let transit = transit else { return }

            // Dynamic radii based on current camera altitude
            let cameraAlt = map.camera.centerCoordinateDistance
            let zodOuter  = AstroGlobeChart.zodiacOuter(cameraAlt: cameraAlt)
            let zodInner  = AstroGlobeChart.zodiacInner(cameraAlt: cameraAlt)
            let bodyR     = AstroGlobeChart.bodyRadius(cameraAlt: cameraAlt)
            let sectStart = AstroGlobeChart.sectorStart(cameraAlt: cameraAlt)

            // Rotation: natal ascendant → compass 270° (screen 9 o'clock); no natal → 0° Aries at 9 o'clock.
            let natalAsc = natal?.ascendantLongitude ?? 0

            // Ecliptic longitude (CCW on wheel) → compass bearing (CW on map).
            func bearing(from L: Double) -> Double {
                var b = 270 + natalAsc - L
                b = b.truncatingRemainder(dividingBy: 360)
                return b < 0 ? b + 360 : b
            }

            // Shortest signed arc difference in bearing space
            func angleDiff(_ a1: Double, _ a2: Double) -> Double {
                var diff = a2 - a1
                while diff > 180  { diff -= 360 }
                while diff < -180 { diff += 360 }
                return diff
            }

            // ---- 1. Outer zodiac ring — zebra stripe (12 MKPolygon sectors) ----
            for i in 0..<12 {
                let startL = Double(i) * 30
                let endL   = startL + 30
                let sector = createAnnularSector(
                    center: center,
                    innerRadius: zodInner,
                    outerRadius: zodOuter,
                    startBearing: bearing(from: startL),
                    endBearing:   bearing(from: endL)
                )
                sector.title = i % 2 == 0 ? "zodiac_even" : "zodiac_odd"
                map.addOverlay(sector, level: .aboveLabels)   // sit above street/place labels
            }

            // 12 zodiac symbols at ring centre radius — colour depends on zebra band parity:
            //  • even-indexed segments sit on the light (off-white) band → BLACK glyph
            //  • odd-indexed segments sit on the dark (grey) band       → WHITE glyph
            let midR = (zodInner + zodOuter) / 2
            for i in 0..<12 {
                let midL = Double(i) * 30 + 15
                let coord = destinationCoord(from: center, azimuth: bearing(from: midL), distance: midR)
                let onLightBand = i.isMultiple(of: 2)
                let glyphColor: UIColor = onLightBand
                    ? UIColor.black.withAlphaComponent(0.88)
                    : UIColor.white.withAlphaComponent(0.95)
                map.addAnnotation(AstroWheelAnnotation(
                    coordinate: coord, glyph: AstroGlobeChart.zodiacGlyphs[i],
                    color: glyphColor, fontSize: 12,
                    useAstroFont: true, isBody: false
                ))
            }

            // ---- 2. Six bodies — all at zodiacInner (紧贴内边缘) ----
            // Transit and natal bodies are distinguished by color (NOT identity color per body type).
            struct BodyInfo {
                let glyph: String; let lon: Double
                let isArrow: Bool; let color: UIColor; let fontSize: CGFloat
            }
            var bodies: [BodyInfo] = [
                BodyInfo(glyph: "☉", lon: transit.sunLongitude,       isArrow: false,
                         color: transitColor, fontSize: 18),
                BodyInfo(glyph: "☽", lon: transit.moonLongitude,      isArrow: false,
                         color: transitColor, fontSize: 18),
                BodyInfo(glyph: "↑", lon: transit.ascendantLongitude, isArrow: true,
                         color: transitColor, fontSize: 18),
            ]
            if let natal = natal {
                bodies += [
                    BodyInfo(glyph: "☉", lon: natal.sunLongitude,       isArrow: false,
                             color: natalColor, fontSize: 16),
                    BodyInfo(glyph: "☽", lon: natal.moonLongitude,      isArrow: false,
                             color: natalColor, fontSize: 16),
                    BodyInfo(glyph: "↑", lon: natal.ascendantLongitude, isArrow: true,
                             color: natalColor, fontSize: 16),
                ]
            }
            for body in bodies {
                let coord = destinationCoord(from: center, azimuth: bearing(from: body.lon), distance: bodyR)
                map.addAnnotation(AstroWheelAnnotation(
                    coordinate: coord, glyph: body.glyph,
                    color: body.color, fontSize: body.fontSize,
                    useAstroFont: !body.isArrow, isBody: true
                ))
            }

            // ---- 3. Aspect sectors — radiate from centre to zodiacInner ----
            guard let natal = natal else { return }

            func drawSector(transitLon: Double, natalLon: Double, aspect: Aspect?, prefix: String) {
                let startB = bearing(from: transitLon)
                let diff   = angleDiff(startB, bearing(from: natalLon))
                let sector = createAnnularSector(
                    center: center,
                    innerRadius: sectStart,
                    outerRadius: zodInner,
                    startBearing: startB,
                    endBearing:   startB + diff
                )
                // Always draw the sector — when aspect is nil, it shows as a neutral white wedge
                // so the toggle's visual effect is always obvious.
                // Use titleID (stable English identifier) so sectorColor() stays locale-safe.
                sector.title = "\(prefix)_\(aspect?.titleID ?? "none")"
                map.addOverlay(sector, level: .aboveLabels)   // sit above street/place labels
            }

            if showSunSector {
                let asp = calculateAspect(lon1: transit.sunLongitude, lon2: natal.sunLongitude)
                drawSector(transitLon: transit.sunLongitude, natalLon: natal.sunLongitude, aspect: asp, prefix: "sun")
            }
            if showMoonSector {
                let asp = calculateAspect(lon1: transit.moonLongitude, lon2: natal.moonLongitude)
                drawSector(transitLon: transit.moonLongitude, natalLon: natal.moonLongitude, aspect: asp, prefix: "moon")
            }
            if showAscSector {
                let asp = calculateAspect(lon1: transit.ascendantLongitude, lon2: natal.ascendantLongitude)
                drawSector(transitLon: transit.ascendantLongitude, natalLon: natal.ascendantLongitude, aspect: asp, prefix: "asc")
            }
        }

        // Render overlays: zodiac zebra ring + aspect sectors
        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolygonRenderer(polygon: poly)
            r.strokeColor = .clear
            guard let title = poly.title else { return r }

            if title == "zodiac_even" {
                r.fillColor = UIColor(white: 0.85, alpha: 1.0)   // opaque off-white
            } else if title == "zodiac_odd" {
                r.fillColor = UIColor(white: 0.32, alpha: 1.0)   // opaque medium grey
            } else if title.hasPrefix("sun_") || title.hasPrefix("moon_") || title.hasPrefix("asc_") {
                r.fillColor = sectorColor(title: title)
            }
            return r
        }

        /// Aspect-driven sector fill — matched by stable English title IDs (locale-safe).
        private func sectorColor(title: String) -> UIColor {
            if title.hasSuffix(Aspect.conjunction.titleID) || title.hasSuffix(Aspect.trine.titleID) {
                return UIColor.systemGreen.withAlphaComponent(0.60)
            } else if title.hasSuffix(Aspect.square.titleID) || title.hasSuffix(Aspect.opposition.titleID) {
                return UIColor.systemOrange.withAlphaComponent(0.60)
            } else if title.hasSuffix(Aspect.sextile.titleID) {
                return UIColor.systemCyan.withAlphaComponent(0.48)
            } else {
                return UIColor.white.withAlphaComponent(0.28)   // "none" fallback
            }
        }

        // Sign + body markers (no backdrop circles)
        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Custom user location dot WITHOUT the heading sector —
            // map still rotates with heading (followWithHeading mode), but the cone is gone.
            if annotation is MKUserLocation {
                let id = "userLocationDot"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                let size: CGFloat = 16
                view.frame = CGRect(x: 0, y: 0, width: size, height: size)
                view.backgroundColor = .clear
                view.canShowCallout = false
                view.subviews.forEach { $0.removeFromSuperview() }
                // Blue dot with white ring (iOS-style)
                let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                dot.backgroundColor = UIColor.systemBlue
                dot.layer.cornerRadius = size / 2
                dot.layer.borderColor = UIColor.white.cgColor
                dot.layer.borderWidth = 2.5
                dot.layer.shadowColor = UIColor.black.cgColor
                dot.layer.shadowOpacity = 0.35
                dot.layer.shadowRadius = 2.5
                dot.layer.shadowOffset = CGSize(width: 0, height: 1)
                view.addSubview(dot)
                return view
            }

            guard let a = annotation as? AstroWheelAnnotation else { return nil }
            let view = MKAnnotationView(annotation: a, reuseIdentifier: nil)
            view.canShowCallout = false

            let viewSize: CGFloat = a.fontSize * 2.4

            if a.isBody {
                // Body markers — fill circle with body's COLOR (transit vs natal distinction),
                // glyph inside is BLACK for high contrast and clear identity.
                // bgSize = fontSize × 1.5 → very tight; centering must be exact.
                let bgSize = a.fontSize * 1.5
                let bg = UIView(frame: CGRect(
                    x: (viewSize - bgSize) / 2,
                    y: (viewSize - bgSize) / 2,
                    width: bgSize, height: bgSize
                ))
                bg.backgroundColor   = a.color.withAlphaComponent(0.95)   // colored fill
                bg.layer.cornerRadius = bgSize / 2
                bg.layer.borderColor  = UIColor.white.withAlphaComponent(0.35).cgColor
                bg.layer.borderWidth  = 0.8
                bg.layer.shadowColor   = UIColor.black.cgColor
                bg.layer.shadowOpacity = 0.40
                bg.layer.shadowOffset  = CGSize(width: 0, height: 1)
                bg.layer.shadowRadius  = 2.5
                view.addSubview(bg)
            }

            // Glyph:
            //  • Body → always BLACK (sits on colored circle → maximum contrast)
            //  • Zodiac → whatever colour the annotation carries (caller picks black or white
            //    depending on zebra band parity) with a complementary shadow.
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: viewSize, height: viewSize))
            label.text          = a.glyph
            label.textAlignment = .center
            label.textColor     = a.isBody
                ? UIColor.black.withAlphaComponent(0.90)
                : a.color
            let glyphFont: UIFont = {
                if a.useAstroFont,
                   let f = UIFont(name: AstroGlobeChart.astroFont, size: a.fontSize) {
                    return f
                }
                return .systemFont(ofSize: a.fontSize, weight: .semibold)
            }()
            label.font = glyphFont

            // Center body glyph EXACTLY using CoreText ink bounds (not empirical guess).
            // UILabel centres the typographic line box (ascender + descender), but the visible
            // glyph rectangle for ☉ / ☽ / ↑ doesn't fill that box — so we calculate the precise
            // y-offset that makes the glyph's actual ink-rect midpoint coincide with the
            // container's geometric centre.
            if a.isBody {
                let attr = NSAttributedString(string: a.glyph, attributes: [.font: glyphFont])
                let line = CTLineCreateWithAttributedString(attr)
                let inkBounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
                let lineHeight = glyphFont.ascender + abs(glyphFont.descender) + glyphFont.leading
                // Derivation:
                //   baseline_y_in_label = (label.h - lineHeight)/2 + ascender
                //   visible glyph centre y = baseline_y - inkBounds.midY  (CT y-up flipped)
                //   want visible centre = label.h / 2  →  origin shift = lineHeight/2 - ascender + inkBounds.midY
                label.frame.origin.y = lineHeight / 2 - glyphFont.ascender + inkBounds.midY
            }
            // Complementary shadow: dark glyph → white glow; light glyph → black glow.
            if !a.isBody {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, al: CGFloat = 0
                a.color.getRed(&r, green: &g, blue: &b, alpha: &al)
                let brightness = (r + g + b) / 3
                let useLightShadow = brightness < 0.5
                label.layer.shadowColor   = useLightShadow
                    ? UIColor.white.cgColor
                    : UIColor.black.cgColor
                label.layer.shadowOpacity = 0.70
                label.layer.shadowOffset  = .zero
                label.layer.shadowRadius  = 2.0
            }
            view.addSubview(label)

            view.frame = CGRect(x: 0, y: 0, width: viewSize, height: viewSize)
            return view
        }
    }
}

// MARK: - Aspect toggle card (rich, vertical)

private struct AspectToggleCard: View {
    let astroBody:    AstroBody
    let glyph:        String       // ☉ / ☽ / ↑
    let aspect:       Aspect?
    let transitSign:  String
    let natalSign:    String
    let transitColor: Color
    let natalColor:   Color
    @Binding var isOn: Bool

    // Legend cards use a **dark, muted "forest" palette** — decoupled from the map sectors
    // so white text stays highly readable. The vivid aspect colour re-enters through the
    // border as an "electric rim" so the aspect signal isn't lost.
    //
    // OFF and ON+nil go in OPPOSITE directions on the material: OFF darkens (black overlay),
    // ON+nil lifts (white overlay). This keeps them clearly distinguishable even without
    // an aspect tint.
    private var bgColor: Color {
        guard isOn else { return Color.black.opacity(0.55) }
        guard let aspect else { return Color.white.opacity(0.22) }
        switch aspect {
        case .conjunction, .trine:
            return Color(red: 0.13, green: 0.36, blue: 0.22, opacity: 0.92)  // deep forest green
        case .square, .opposition:
            return Color(red: 0.52, green: 0.30, blue: 0.12, opacity: 0.92)  // burnt sienna
        case .sextile:
            return Color(red: 0.18, green: 0.40, blue: 0.50, opacity: 0.90)  // deep teal
        }
    }

    private var borderColor: Color {
        guard isOn else { return Color.white.opacity(0.08) }
        guard let aspect else { return Color.white.opacity(0.65) }   // bright white rim for nil-aspect active state
        switch aspect {
        case .conjunction, .trine:   return Color(uiColor: .systemGreen).opacity(0.70)
        case .square, .opposition:   return Color(uiColor: .systemOrange).opacity(0.70)
        case .sextile:               return Color(uiColor: .systemCyan).opacity(0.60)
        }
    }

    private var borderWidth: CGFloat { isOn ? 1.2 : 0.5 }

    var body: some View {
        Button { isOn.toggle() } label: {
            VStack(alignment: .leading, spacing: 4) {
                // Row 1 — body + aspect + both signs on ONE line
                HStack(spacing: 6) {
                    Text(glyph).font(.system(size: 15))
                    Text(astroBody.label)
                        .font(.custom("Merriweather-Bold", size: 13))
                    if let aspect {
                        Text("·").opacity(0.55)
                        Text(aspect.displayName)
                            .font(.custom("Merriweather-Regular", size: 12))
                    }
                    Spacer(minLength: 8)
                    signTag(label: String(localized: "cosmic_map.legend_now"),
                            sign: transitSign, color: transitColor)
                    signTag(label: String(localized: "cosmic_map.legend_natal"),
                            sign: natalSign,   color: natalColor)
                }

                // Row 2 — full-sentence meaning, wraps as needed
                Text(astroBody.meaning(for: aspect))
                    .font(.custom("Merriweather-Light", size: 10.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .opacity(0.92)
                    .lineSpacing(1.5)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
        }
        .buttonStyle(.plain)
    }

    private func signTag(label: String, sign: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.custom("Merriweather-Light", size: 9.5))
                .foregroundColor(.white.opacity(0.65))
            Text(sign)
                .font(.custom("Merriweather-Regular", size: 10.5))
                .foregroundColor(.white)
        }
        .lineLimit(1)
    }
}

// MARK: - Legend panel

private struct LegendPanel: View {
    let transit:      AstroWheelData?
    let natal:        AstroWheelData?
    let transitColor: Color
    let natalColor:   Color

    @Binding var showSunSector:  Bool
    @Binding var showMoonSector: Bool
    @Binding var showAscSector:  Bool

    var body: some View {
        VStack(spacing: 7) {
            if let transit, let natal {
                AspectToggleCard(
                    astroBody:    .sun,
                    glyph:        "☉",
                    aspect:       calculateAspect(lon1: transit.sunLongitude,
                                                  lon2: natal.sunLongitude),
                    transitSign:  transit.sunSign,
                    natalSign:    natal.sunSign,
                    transitColor: transitColor,
                    natalColor:   natalColor,
                    isOn:         $showSunSector
                )
                AspectToggleCard(
                    astroBody:    .moon,
                    glyph:        "☽",
                    aspect:       calculateAspect(lon1: transit.moonLongitude,
                                                  lon2: natal.moonLongitude),
                    transitSign:  transit.moonSign,
                    natalSign:    natal.moonSign,
                    transitColor: transitColor,
                    natalColor:   natalColor,
                    isOn:         $showMoonSector
                )
                AspectToggleCard(
                    astroBody:    .ascendant,
                    glyph:        "↑",
                    aspect:       calculateAspect(lon1: transit.ascendantLongitude,
                                                  lon2: natal.ascendantLongitude),
                    transitSign:  transit.ascendantSign,
                    natalSign:    natal.ascendantSign,
                    transitColor: transitColor,
                    natalColor:   natalColor,
                    isOn:         $showAscSector
                )
            } else if let transit {
                // Fallback when no natal — show transit signs as a compact summary.
                HStack(spacing: 14) {
                    summaryTag(glyph: "☉", sign: transit.sunSign)
                    summaryTag(glyph: "☽", sign: transit.moonSign)
                    summaryTag(glyph: "↑", sign: transit.ascendantSign)
                    Spacer(minLength: 0)
                }
                .foregroundColor(transitColor)

                Text(String(localized: "cosmic_map.no_natal_hint"))
                    .font(.custom("Merriweather-Light", size: 11))
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 20, bottomLeading: 0,
                                   bottomTrailing: 0, topTrailing: 20)
            )
            .fill(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func summaryTag(glyph: String, sign: String) -> some View {
        HStack(spacing: 4) {
            Text(glyph).font(.system(size: 14))
            Text(sign).font(.custom("Merriweather-Regular", size: 12))
        }
    }

}


// MARK: - Compass indicator (SwiftUI overlay above the legend)

private struct CompassIndicator: View {
    let heading: CLLocationDirection   // device heading the map rotates with

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 40, height: 40)
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                .frame(width: 40, height: 40)

            // Needle points to true north relative to map rotation.
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.red.opacity(0.88))
                .rotationEffect(.degrees(-heading))
        }
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        .animation(.easeOut(duration: 0.2), value: heading)
    }
}

// MARK: - Info sheet (explain the chart) — styled to match MoonRitualSheet

private struct CosmicMapInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager

    // MARK: - Theme-derived colors (same pattern as MoonRitualSheet)

    private var isDarkTheme: Bool {
        themeManager.isNight || themeManager.isRain
    }

    private var sheetBg: Color {
        if themeManager.isNight    { return Color(hex: "#0D0D1A") }     // deep indigo-black
        if themeManager.isRain     { return Color(hex: "#17222B") }     // muted slate
        if themeManager.isVitality { return Color(hex: "#EFF4ED") }     // soft sage white
        if themeManager.isLove     { return Color(hex: "#F5EEF0") }     // dusty rose blush
        return Color(hex: "#F4ECE1")                                    // warm muted ivory
    }

    private var headingColor: Color {
        isDarkTheme ? Color.white.opacity(0.90) : themeManager.primaryText
    }

    private var bodyColor: Color {
        isDarkTheme ? Color.white.opacity(0.70) : themeManager.descriptionText
    }

    private var accent: Color { themeManager.accent }
    private let natalAccent = Color(red: 0.55, green: 0.78, blue: 1.00)

    var body: some View {
        ZStack {
            sheetBg.ignoresSafeArea()

            // Soft accent glow behind the icon
            Circle()
                .fill(accent.opacity(isDarkTheme ? 0.10 : 0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(y: -150)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // — Header
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(accent)
                        Text(String(localized: "cosmic_map.info.title"))
                            .font(.custom("Merriweather-Black", size: 22))
                            .foregroundColor(headingColor)
                        Text(String(localized: "cosmic_map.info.subtitle"))
                            .font(.custom("Merriweather-LightItalic", size: 13))
                            .foregroundColor(bodyColor)
                    }
                    .padding(.top, 28)

                    section(String(localized: "cosmic_map.info.section.ring")) {
                        bullet(String(localized: "cosmic_map.info.ring.bullet1"))
                        bullet(String(localized: "cosmic_map.info.ring.bullet2"))
                    }

                    section(String(localized: "cosmic_map.info.section.bodies")) {
                        bodyIconRow(glyph: "☉",
                                    name: String(localized: "cosmic_map.body.sun.label"),
                                    desc: String(localized: "cosmic_map.info.bodies.sun.desc"))
                        bodyIconRow(glyph: "☽",
                                    name: String(localized: "cosmic_map.body.moon.label"),
                                    desc: String(localized: "cosmic_map.info.bodies.moon.desc"))
                        bodyIconRow(glyph: "↑",
                                    name: String(localized: "cosmic_map.body.ascendant.label"),
                                    desc: String(localized: "cosmic_map.info.bodies.asc.desc"))
                        Text(String(localized: "cosmic_map.info.bodies.note"))
                            .font(.custom("Merriweather-Light", size: 12))
                            .foregroundColor(bodyColor)
                            .padding(.top, 2)
                    }

                    section(String(localized: "cosmic_map.info.section.colors")) {
                        colorRow(color: accent,
                                 label: String(localized: "cosmic_map.info.colors.transit.label"),
                                 desc:  String(localized: "cosmic_map.info.colors.transit.desc"))
                        colorRow(color: natalAccent,
                                 label: String(localized: "cosmic_map.info.colors.natal.label"),
                                 desc:  String(localized: "cosmic_map.info.colors.natal.desc"))
                    }

                    section(String(localized: "cosmic_map.info.section.aspects")) {
                        aspectRow(color: .green,
                                  name:    String(localized: "cosmic_map.info.aspects.harmonic.name"),
                                  angle:   "0° / 120°",
                                  meaning: String(localized: "cosmic_map.info.aspects.harmonic.meaning"))
                        aspectRow(color: .cyan,
                                  name:    String(localized: "cosmic_map.info.aspects.sextile.name"),
                                  angle:   "60°",
                                  meaning: String(localized: "cosmic_map.info.aspects.sextile.meaning"))
                        aspectRow(color: .orange,
                                  name:    String(localized: "cosmic_map.info.aspects.tense.name"),
                                  angle:   "90° / 180°",
                                  meaning: String(localized: "cosmic_map.info.aspects.tense.meaning"))
                        aspectRow(color: .white.opacity(0.55),
                                  name:    String(localized: "cosmic_map.info.aspects.none.name"),
                                  angle:   "—",
                                  meaning: String(localized: "cosmic_map.info.aspects.none.meaning"))
                    }

                    Text(String(localized: "cosmic_map.info.footer"))
                        .font(.custom("Merriweather-LightItalic", size: 12))
                        .foregroundColor(bodyColor.opacity(0.70))
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(isDarkTheme ? .dark : .light)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(
                        bodyColor.opacity(0.7),
                        isDarkTheme ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
                    )
            }
            .padding(.trailing, 16)
            .padding(.top, 14)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Merriweather-Bold", size: 14))
                .foregroundColor(accent)
                .tracking(0.5)
            content()
        }
    }

    private func bullet(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(accent).frame(width: 4, height: 4).offset(y: 7)
            Text(.init(s))   // markdown **bold**
                .font(.custom("Merriweather-Regular", size: 13))
                .foregroundColor(bodyColor)
                .lineSpacing(3)
        }
    }

    private func bodyIconRow(glyph: String, name: String, desc: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.90)).frame(width: 30, height: 30)
                Text(glyph)
                    .font(.system(size: 15))
                    .foregroundColor(.black.opacity(0.90))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.custom("Merriweather-Bold", size: 13))
                    .foregroundColor(headingColor)
                Text(desc)
                    .font(.custom("Merriweather-Light", size: 12))
                    .foregroundColor(bodyColor)
            }
        }
    }

    private func colorRow(color: Color, label: String, desc: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 14, height: 14)
            Text(label)
                .font(.custom("Merriweather-Bold", size: 13))
                .foregroundColor(color)
            Text("·").foregroundColor(bodyColor.opacity(0.5))
            Text(desc)
                .font(.custom("Merriweather-Regular", size: 12))
                .foregroundColor(bodyColor)
            Spacer()
        }
    }

    private func aspectRow(color: Color, name: String, angle: String, meaning: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.60))
                .frame(width: 14, height: 14)
            Text(name)
                .font(.custom("Merriweather-Bold", size: 12))
                .foregroundColor(headingColor)
                .frame(width: 78, alignment: .leading)
            Text(angle)
                .font(.custom("Merriweather-Light", size: 10))
                .foregroundColor(bodyColor.opacity(0.75))
                .frame(width: 70, alignment: .leading)
            Text(meaning)
                .font(.custom("Merriweather-Regular", size: 12))
                .foregroundColor(bodyColor)
            Spacer()
        }
    }
}

// MARK: - Full-screen view (entry point from ProfileView)

struct CosmicMapView: View {
    let natalBirthInfo: BirthInfo?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var fetcher = CompassLocationFetcher()

    @State private var mapCenter  = CLLocationCoordinate2D(latitude: 35, longitude: 105)
    @State private var transitData: AstroWheelData?
    @State private var natalData:   AstroWheelData?

    // Toggle states for the 3 aspect sectors (surfaced in the bottom panel)
    @State private var showSunSector  = true
    @State private var showMoonSector = true
    @State private var showAscSector  = true
    @State private var showInfoSheet  = false

    private var transitColor: Color { themeManager.accent }
    private let natalColor = Color(red: 0.55, green: 0.78, blue: 1.00)   // moonlight blue

    var body: some View {
        ZStack {
            // Base flat map + zebra wheel + bodies + aspect sectors
            AstroGlobeChart(
                center:         mapCenter,
                transit:        transitData,
                natal:          natalData,
                transitColor:   UIColor(themeManager.accent),
                natalColor:     UIColor(red: 0.55, green: 0.78, blue: 1.00, alpha: 1.0),
                showSunSector:  showSunSector,
                showMoonSector: showMoonSector,
                showAscSector:  showAscSector
            )
            // No saturation filter — transit/natal colors show at full strength on body tokens.
            // Modest positive brightness lifts the map out of deep black while keeping the
            // native dark + muted MapKit look.
            .brightness(0.08)
            .ignoresSafeArea()

            // Themed chrome: top bar + compass above legend + bottom legend panel
            VStack(spacing: 0) {
                topBar
                Spacer()
                HStack {
                    Spacer()
                    CompassIndicator(heading: fetcher.heading)
                        .padding(.trailing, 14)
                        .padding(.bottom, 10)
                }
                LegendPanel(
                    transit:        transitData,
                    natal:          natalData,
                    transitColor:   transitColor,
                    natalColor:     natalColor,
                    showSunSector:  $showSunSector,
                    showMoonSector: $showMoonSector,
                    showAscSector:  $showAscSector
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showInfoSheet) {
            CosmicMapInfoSheet()
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            fetcher.startTracking()
            compute()
        }
        .onDisappear {
            fetcher.stopTracking()
        }
        .onChange(of: fetcher.coordinate) { _, coord in
            guard let coord else { return }
            mapCenter = coord
            compute()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300 * 1_000_000_000)   // refresh every 5 min
                compute()
            }
        }
    }

    // MARK: Top bar (themed chrome above the map)

    private var topBar: some View {
        HStack(spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(themeManager.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            Spacer()

            Button { showInfoSheet = true } label: {
                Image(systemName: "info.circle")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(themeManager.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    // MARK: Compute ecliptic-longitude data for both wheels

    private func compute() {
        let now   = Date()
        let coord = fetcher.coordinate ?? mapCenter

        transitData = AstroWheelData(
            sunLongitude:       AstroCalculator.sunLongitudeDegrees(now),
            moonLongitude:      AstroCalculator.moonLongitudeDegrees(now),
            ascendantLongitude: AstroCalculator.ascendantLongitudeDegrees(dateUTC: now, coordinate: coord),
            sunSign:            AstroCalculator.sunSign(date: now).rawValue,
            moonSign:           AstroCalculator.moonSign(date: now).rawValue,
            ascendantSign:      AstroCalculator.ascendantSign(dateUTC: now, coordinate: coord).rawValue
        )

        guard let info = natalBirthInfo,
              info.latitude != 0 || info.longitude != 0 else { return }

        let utc = info.date.addingTimeInterval(-Double(info.timezoneOffsetMinutes * 60))

        natalData = AstroWheelData(
            sunLongitude:       AstroCalculator.sunLongitudeDegrees(utc),
            moonLongitude:      AstroCalculator.moonLongitudeDegrees(utc),
            ascendantLongitude: AstroCalculator.ascendantLongitudeDegrees(info),
            sunSign:            AstroCalculator.sunSign(date: utc).rawValue,
            moonSign:           AstroCalculator.moonSign(date: utc).rawValue,
            ascendantSign:      AstroCalculator.ascendantSign(info: info).rawValue
        )
    }
}

