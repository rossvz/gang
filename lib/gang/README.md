# Gang Core Implementation

This directory contains the core game logic and state management for the Gang card game.

## Implemented Modules

### Data Models

- `Gang.Game.Card` - Represents a playing card with a rank and suit
- `Gang.Game.Deck` - Handles deck creation, shuffling, and dealing
- `Gang.Game.RankChip` - Represents the rank chips players claim during rounds
- `Gang.Game.Player` - Models a player with their cards and connection state
- `Gang.Game.State` - The core game state structure and state transition functions
- `Gang.Game.HandEvaluator` - Evaluates poker hands to determine their strength
- `Gang.Game.Evaluator` - Handles game round evaluation (vaults and alarms)

### Server and Management

- `Gang.Game` - GenServer implementation for managing game state and processing player actions
- `Gang.Game.Supervisor` - Supervisor for game processes
- `Gang.Games` - Context module providing a higher-level API for interacting with games

## Test Coverage

All major modules have tests covering their core functionality:

- Card operations (string representation, comparison)
- Deck operations (creation, shuffling, dealing)
- State transitions (player management, round advancement)
- Game evaluation (scoring with vaults and alarms)

## Next Steps

1. **LiveView Integration**
   - Create LiveView pages for game creation, joining, and gameplay
   - Implement PubSub for real-time updates between players

2. **UI Components**
   - Design and implement Card component
   - Design and implement RankChip component
   - Create game board layout

3. **Features**
   - Player identification and persistence (using localStorage)
   - Game sharing mechanism
   - Round transition animations

4. **Persistence**
   - Add database schemas and migrations for persisting games
   - Implement serialization/deserialization of game state
   - Add periodic saving of game state

5. **Deployment**
   - Setup production configuration
   - Deploy to a hosting provider 