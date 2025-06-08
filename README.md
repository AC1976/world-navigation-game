# World Navigation Game

A SwiftUI game for iPad and macOS where players navigate an airplane to cities around the world.

## Features

- **Cross-Platform**: Built for iPad and macOS using SwiftUI
- **SQLite Database**: Cities stored with name, country, continent, and GPS coordinates
- **Progressive Difficulty**: Start with primary cities, unlock secondary cities at higher levels
- **Time-Based Scoring**: Complete 20 cities as fast as possible
- **Player Rankings**: Persistent leaderboard tracking best average times
- **Clean UI**: Modern, attractive interface with smooth animations

## How to Play

1. Enter your name on the main menu
2. Use the arrow controls to navigate your airplane
3. Reach the highlighted city on the map
4. Complete 20 cities to finish the game
5. Try to beat your best time!

## Game Mechanics

- **Movement**: Use arrow buttons to move the plane 5 degrees in any direction
- **Detection**: Get within 200km of the target city to register arrival
- **Levels**: First 5 levels show only primary cities, then all cities become available
- **Scoring**: Based on total time to complete all 20 cities

## Technical Details

- **Language**: Swift 5
- **Framework**: SwiftUI
- **Database**: SQLite3
- **Maps**: MapKit
- **Storage**: UserDefaults for player rankings
- **Platform**: iOS 15.0+ (iPad), macOS 12.0+

## Project Structure

```
WorldNavigationGame/
├── WorldNavigationApp.swift    # Main app file with all game logic
├── Info.plist                  # App configuration
└── Assets.xcassets/           # App icons and images
```

## Database Schema

```sql
CREATE TABLE cities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    city TEXT NOT NULL,
    country TEXT NOT NULL,
    continent TEXT NOT NULL,
    gps_location TEXT NOT NULL,  -- GeoJSON Point format
    is_primary INTEGER DEFAULT 0
);
```

## Installation

1. Clone this repository
2. Open in Xcode 14 or later
3. Select your target device (iPad or Mac)
4. Build and run

## Requirements

- Xcode 14.0+
- iOS 15.0+ (for iPad)
- macOS 12.0+ (for Mac)

## License

MIT License - feel free to use this code for learning or personal projects.

## Future Enhancements

- Multiplayer support
- More cities and regions
- Different game modes (time attack, accuracy challenge)
- Achievement system
- Cloud sync for rankings
- Custom difficulty settings