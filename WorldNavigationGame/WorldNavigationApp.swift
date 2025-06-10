import SwiftUI
import MapKit
import SQLite3

// MARK: - Models
struct City: Identifiable {
    let id = UUID()
    let name: String
    let country: String
    let continent: String
    let coordinate: CLLocationCoordinate2D
    let isPrimary: Bool
}

struct Player: Identifiable, Codable {
    let id = UUID()
    let name: String
    var totalTime: TimeInterval
    var gamesPlayed: Int
    
    var averageTime: TimeInterval {
        gamesPlayed > 0 ? totalTime / Double(gamesPlayed) : 0
    }
}

struct GameSession {
    var currentCity: City?
    var citiesVisited: Int = 0
    var sessionStartTime: Date?
    var currentCityStartTime: Date?
    var totalTime: TimeInterval = 0
    var isActive: Bool = false
}

// MARK: - Database Manager
class DatabaseManager: ObservableObject {
    private var db: OpaquePointer?
    @Published var cities: [City] = []
    
    init() {
        openDatabase()
        createTablesIfNeeded()
        loadSampleCities()
        loadCities()
    }
    
    private func openDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("WorldNavigationGame.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
    }
    
    private func createTablesIfNeeded() {
        let createTableString = """
            CREATE TABLE IF NOT EXISTS cities(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                city TEXT NOT NULL,
                country TEXT NOT NULL,
                continent TEXT NOT NULL,
                gps_location TEXT NOT NULL,
                is_primary INTEGER DEFAULT 0
            );
        """
        
        var createTableStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, createTableString, -1, &createTableStatement, nil) == SQLITE_OK {
            if sqlite3_step(createTableStatement) == SQLITE_DONE {
                print("Cities table created.")
            }
        }
        sqlite3_finalize(createTableStatement)
    }
    
    private func loadSampleCities() {
        // Check if we already have cities
        let queryString = "SELECT COUNT(*) FROM cities"
        var queryStatement: OpaquePointer?
        var count = 0
        
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
            if sqlite3_step(queryStatement) == SQLITE_ROW {
                count = Int(sqlite3_column_int(queryStatement, 0))
            }
        }
        sqlite3_finalize(queryStatement)
        
        if count > 0 { return }
        
        // Sample cities data
        let sampleCities = [
            ("New York", "USA", "North America", -74.006, 40.7128, true),
            ("London", "UK", "Europe", -0.1276, 51.5074, true),
            ("Tokyo", "Japan", "Asia", 139.6917, 35.6762, true),
            ("Paris", "France", "Europe", 2.3522, 48.8566, true),
            ("Sydney", "Australia", "Oceania", 151.2093, -33.8688, true),
            ("Cairo", "Egypt", "Africa", 31.2357, 30.0444, true),
            ("Rio de Janeiro", "Brazil", "South America", -43.1729, -22.9068, true),
            ("Mumbai", "India", "Asia", 72.8777, 19.0760, true),
            ("Barcelona", "Spain", "Europe", 2.1734, 41.3851, false),
            ("Amsterdam", "Netherlands", "Europe", 4.9041, 52.3676, false),
            ("Bangkok", "Thailand", "Asia", 100.5018, 13.7563, false),
            ("Dubai", "UAE", "Asia", 55.2708, 25.2048, false),
            ("Toronto", "Canada", "North America", -79.3832, 43.6532, false),
            ("Mexico City", "Mexico", "North America", -99.1332, 19.4326, true),
            ("Buenos Aires", "Argentina", "South America", -58.3816, -34.6037, true),
            ("Moscow", "Russia", "Europe", 37.6173, 55.7558, true),
            ("Singapore", "Singapore", "Asia", 103.8198, 1.3521, false),
            ("Cape Town", "South Africa", "Africa", 18.4241, -33.9249, false),
            ("Istanbul", "Turkey", "Asia", 28.9784, 41.0082, false),
            ("Seoul", "South Korea", "Asia", 126.9780, 37.5665, false),
            ("Melbourne", "Australia", "Oceania", 144.9631, -37.8136, false),
            ("Lima", "Peru", "South America", -77.0428, -12.0464, false),
            ("Lagos", "Nigeria", "Africa", 3.3792, 6.5244, false),
            ("Jakarta", "Indonesia", "Asia", 106.8456, -6.2088, false),
            ("Manila", "Philippines", "Asia", 120.9842, 14.5995, false)
        ]
        
        for city in sampleCities {
            let insertString = """
                INSERT INTO cities (city, country, continent, gps_location, is_primary)
                VALUES (?, ?, ?, ?, ?);
            """
            
            var insertStatement: OpaquePointer?
            let geoJSON = "{\"type\":\"Point\",\"coordinates\":[\(city.3),\(city.4)]}"
            
            if sqlite3_prepare_v2(db, insertString, -1, &insertStatement, nil) == SQLITE_OK {
                sqlite3_bind_text(insertStatement, 1, city.0, -1, nil)
                sqlite3_bind_text(insertStatement, 2, city.1, -1, nil)
                sqlite3_bind_text(insertStatement, 3, city.2, -1, nil)
                sqlite3_bind_text(insertStatement, 4, geoJSON, -1, nil)
                sqlite3_bind_int(insertStatement, 5, city.5 ? 1 : 0)
                
                sqlite3_step(insertStatement)
            }
            sqlite3_finalize(insertStatement)
        }
    }
    
    func loadCities() {
        cities = []
        let queryString = "SELECT city, country, continent, gps_location, is_primary FROM cities"
        var queryStatement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
            while sqlite3_step(queryStatement) == SQLITE_ROW {
                let city = String(cString: sqlite3_column_text(queryStatement, 0))
                let country = String(cString: sqlite3_column_text(queryStatement, 1))
                let continent = String(cString: sqlite3_column_text(queryStatement, 2))
                let gpsLocation = String(cString: sqlite3_column_text(queryStatement, 3))
                let isPrimary = sqlite3_column_int(queryStatement, 4) == 1
                
                // Parse GeoJSON to get coordinates
                if let data = gpsLocation.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let coordinates = json["coordinates"] as? [Double],
                   coordinates.count >= 2 {
                    
                    let cityObj = City(
                        name: city,
                        country: country,
                        continent: continent,
                        coordinate: CLLocationCoordinate2D(latitude: coordinates[1], longitude: coordinates[0]),
                        isPrimary: isPrimary
                    )
                    cities.append(cityObj)
                }
            }
        }
        sqlite3_finalize(queryStatement)
    }
    
    func getRandomCity(level: Int) -> City? {
        let primaryOnly = level <= 5
        let filteredCities = primaryOnly ? cities.filter { $0.isPrimary } : cities
        return filteredCities.randomElement()
    }
}

// MARK: - Game Manager
class GameManager: ObservableObject {
    @Published var currentPlayer: String = ""
    @Published var gameSession = GameSession()
    @Published var players: [Player] = []
    @Published var showingResults = false
    @Published var lastNavigationTime: TimeInterval = 0
    
    private let userDefaults = UserDefaults.standard
    private let playersKey = "WorldNavigationPlayers"
    
    init() {
        loadPlayers()
    }
    
    func startNewGame(playerName: String, firstCity: City) {
        currentPlayer = playerName
        gameSession = GameSession(
            currentCity: firstCity,
            citiesVisited: 0,
            sessionStartTime: Date(),
            currentCityStartTime: Date(),
            totalTime: 0,
            isActive: true
        )
    }
    
    func reachedCity() {
        guard let startTime = gameSession.currentCityStartTime else { return }
        
        let navigationTime = Date().timeIntervalSince(startTime)
        lastNavigationTime = navigationTime
        gameSession.totalTime += navigationTime
        gameSession.citiesVisited += 1
        
        if gameSession.citiesVisited >= 20 {
            endGame()
        }
    }
    
    func setNextCity(_ city: City) {
        gameSession.currentCity = city
        gameSession.currentCityStartTime = Date()
    }
    
    private func endGame() {
        gameSession.isActive = false
        showingResults = true
        
        // Update player stats
        if let index = players.firstIndex(where: { $0.name == currentPlayer }) {
            players[index].totalTime += gameSession.totalTime
            players[index].gamesPlayed += 1
        } else {
            let newPlayer = Player(
                name: currentPlayer,
                totalTime: gameSession.totalTime,
                gamesPlayed: 1
            )
            players.append(newPlayer)
        }
        
        // Sort players by average time
        players.sort { $0.averageTime < $1.averageTime }
        savePlayers()
    }
    
    private func loadPlayers() {
        if let data = userDefaults.data(forKey: playersKey),
           let decoded = try? JSONDecoder().decode([Player].self, from: data) {
            players = decoded
        }
    }
    
    private func savePlayers() {
        if let encoded = try? JSONEncoder().encode(players) {
            userDefaults.set(encoded, forKey: playersKey)
        }
    }
}

// MARK: - Map View
struct GameMapView: View {
    let targetCity: City
    @Binding var planePosition: CLLocationCoordinate2D
    let onReachCity: () -> Void
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 140)
    )
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: [targetCity]) { city in
                MapAnnotation(coordinate: city.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                        Text(city.name)
                            .font(.caption)
                            .padding(4)
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                }
            }
            .overlay(
                // Plane overlay
                GeometryReader { geometry in
                    Image(systemName: "airplane")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(getRotationAngle()))
                        .position(getPlaneScreenPosition(in: geometry))
                }
            )
            .onTapGesture { location in
                // Handle tap to move plane
            }
            
            // Navigation controls
            VStack {
                Spacer()
                HStack {
                    NavigationButton(direction: "chevron.left") {
                        movePlane(longitude: -5)
                    }
                    
                    VStack {
                        NavigationButton(direction: "chevron.up") {
                            movePlane(latitude: 5)
                        }
                        NavigationButton(direction: "chevron.down") {
                            movePlane(latitude: -5)
                        }
                    }
                    
                    NavigationButton(direction: "chevron.right") {
                        movePlane(longitude: 5)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(20)
                .padding()
            }
        }
        .onAppear {
            checkIfReachedCity()
        }
    }
    
    private func movePlane(latitude: Double = 0, longitude: Double = 0) {
        withAnimation(.easeInOut(duration: 0.3)) {
            planePosition = CLLocationCoordinate2D(
                latitude: planePosition.latitude + latitude,
                longitude: planePosition.longitude + longitude
            )
        }
        checkIfReachedCity()
    }
    
    private func checkIfReachedCity() {
        let distance = calculateDistance(from: planePosition, to: targetCity.coordinate)
        if distance < 200000 { // 200km threshold
            onReachCity()
        }
    }
    
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    private func getRotationAngle() -> Double {
        let deltaLat = targetCity.coordinate.latitude - planePosition.latitude
        let deltaLon = targetCity.coordinate.longitude - planePosition.longitude
        let angle = atan2(deltaLon, deltaLat) * 180 / .pi
        return angle - 90
    }
    
    private func getPlaneScreenPosition(in geometry: GeometryProxy) -> CGPoint {
        let mapRect = MKMapRect(region)
        let planePoint = MKMapPoint(planePosition)
        
        let relativeX = (planePoint.x - mapRect.minX) / mapRect.width
        let relativeY = (planePoint.y - mapRect.minY) / mapRect.height
        
        return CGPoint(
            x: relativeX * geometry.size.width,
            y: relativeY * geometry.size.height
        )
    }
}

struct NavigationButton: View {
    let direction: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: direction)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.blue)
                .clipShape(Circle())
        }
    }
}

// MARK: - Main Game View
struct GameView: View {
    @StateObject private var gameManager = GameManager()
    @StateObject private var databaseManager = DatabaseManager()
    @State private var planePosition = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var showingCityReached = false
    @State private var currentLevel = 1
    
    var body: some View {
        ZStack {
            if let currentCity = gameManager.gameSession.currentCity {
                VStack {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Navigate to:")
                                .font(.headline)
                            Text("\(currentCity.name), \(currentCity.country)")
                                .font(.title2)
                                .bold()
                            Text(currentCity.continent)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Cities: \(gameManager.gameSession.citiesVisited)/20")
                                .font(.headline)
                            Text("Level: \(currentLevel)")
                                .font(.subheadline)
                            if let startTime = gameManager.gameSession.currentCityStartTime {
                                TimeView(startTime: startTime)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .shadow(radius: 2)
                    
                    // Map
                    GameMapView(
                        targetCity: currentCity,
                        planePosition: $planePosition,
                        onReachCity: {
                            gameManager.reachedCity()
                            showingCityReached = true
                        }
                    )
                }
                
                if showingCityReached {
                    CityReachedOverlay(
                        cityName: currentCity.name,
                        time: gameManager.lastNavigationTime,
                        onContinue: {
                            showingCityReached = false
                            currentLevel = min(10, gameManager.gameSession.citiesVisited / 2 + 1)
                            if let nextCity = databaseManager.getRandomCity(level: currentLevel) {
                                gameManager.setNextCity(nextCity)
                                planePosition = CLLocationCoordinate2D(
                                    latitude: currentCity.coordinate.latitude,
                                    longitude: currentCity.coordinate.longitude
                                )
                            }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $gameManager.showingResults) {
            GameResultsView(
                totalTime: gameManager.gameSession.totalTime,
                players: gameManager.players
            )
        }
    }
}

struct TimeView: View {
    let startTime: Date
    @State private var currentTime = Date()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text("Time: \(timeString)")
            .font(.subheadline)
            .monospacedDigit()
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }
    
    private var timeString: String {
        let elapsed = currentTime.timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CityReachedOverlay: View {
    let cityName: String
    let time: TimeInterval
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("City Reached!")
                .font(.largeTitle)
                .bold()
            
            Text("You reached \(cityName)")
                .font(.title2)
            
            Text("Time: \(timeString)")
                .font(.title3)
                .monospacedDigit()
            
            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
    }
    
    private var timeString: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Menu & Results Views
struct MenuView: View {
    @State private var playerName = ""
    @State private var showingGame = false
    @State private var showingRankings = false
    @StateObject private var gameManager = GameManager()
    @StateObject private var databaseManager = DatabaseManager()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.blue)
                    
                    Text("World Navigation Challenge")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Navigate to 20 cities as fast as you can!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                
                VStack(spacing: 20) {
                    TextField("Enter your name", text: $playerName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 300)
                    
                    Button("Start Game") {
                        if !playerName.isEmpty,
                           let firstCity = databaseManager.getRandomCity(level: 1) {
                            gameManager.startNewGame(playerName: playerName, firstCity: firstCity)
                            showingGame = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(playerName.isEmpty)
                    
                    Button("View Rankings") {
                        showingRankings = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingGame) {
                GameView()
                    .environmentObject(gameManager)
                    .environmentObject(databaseManager)
            }
            .sheet(isPresented: $showingRankings) {
                RankingsView(players: gameManager.players)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct RankingsView: View {
    let players: [Player]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    HStack {
                        Text("\(index + 1)")
                            .font(.title2)
                            .bold()
                            .frame(width: 40)
                        
                        VStack(alignment: .leading) {
                            Text(player.name)
                                .font(.headline)
                            Text("Games: \(player.gamesPlayed)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(formatTime(player.averageTime))
                            .font(.title3)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Rankings")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct GameResultsView: View {
    let totalTime: TimeInterval
    let players: [Player]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Game Complete!")
                .font(.largeTitle)
                .bold()
            
            VStack {
                Text("Total Time")
                    .font(.headline)
                Text(formatTime(totalTime))
                    .font(.system(size: 48))
                    .monospacedDigit()
                    .bold()
            }
            
            if let rank = players.firstIndex(where: { $0.totalTime == totalTime }) {
                Text("Rank: #\(rank + 1)")
                    .font(.title2)
            }
            
            Button("Back to Menu") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - App
@main
struct WorldNavigationApp: App {
    var body: some Scene {
        WindowGroup {
            MenuView()
        }
    }
}

// MARK: - Extensions
extension MKMapRect {
    init(_ region: MKCoordinateRegion) {
        let topLeft = CLLocationCoordinate2D(
            latitude: region.center.latitude + region.span.latitudeDelta / 2,
            longitude: region.center.longitude - region.span.longitudeDelta / 2
        )
        let bottomRight = CLLocationCoordinate2D(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude + region.span.longitudeDelta / 2
        )
        
        let topLeftPoint = MKMapPoint(topLeft)
        let bottomRightPoint = MKMapPoint(bottomRight)
        
        self = MKMapRect(
            x: topLeftPoint.x,
            y: topLeftPoint.y,
            width: bottomRightPoint.x - topLeftPoint.x,
            height: bottomRightPoint.y - topLeftPoint.y
        )
    }
}