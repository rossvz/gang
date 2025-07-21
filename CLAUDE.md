# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Gang is a cooperative multiplayer poker-based card game built with Phoenix LiveView. Players work together to correctly rank their poker hands across 4 rounds (preflop, flop, turn, river). The game uses shareable 4-character codes for joining games.

## Tech Stack

- **Framework**: Phoenix LiveView 1.7.18
- **Language**: Elixir 1.14+
- **Database**: PostgreSQL (currently disabled - all state in memory via GenServer)
- **Frontend**: Tailwind CSS with Catppuccin Mocha theme, Phoenix LiveView
- **Deployment**: Fly.io

## Key Commands

```bash
# Development
mix phx.server              # Start dev server on http://localhost:4000
mix test                    # Run all tests
mix test path/to/test.exs   # Run specific test file
mix format                  # Format all Elixir code

# Setup & Dependencies
mix setup                   # Install deps, create DB, build assets
mix deps.get               # Install dependencies
mix deps.update --all      # Update all dependencies

# Assets
mix assets.build           # Build CSS/JS for development
mix assets.deploy          # Build CSS/JS for production

# Database (when re-enabled)
mix ecto.create            # Create database
mix ecto.migrate           # Run migrations
mix ecto.reset             # Drop, create, and migrate database

# Code Quality
mix compile --warnings-as-errors  # Compile with warnings as errors
mix credo                        # Run static analysis (if installed)
```

## Architecture

### Game Logic (`lib/gang/game/`)
- `game.ex` - Main game GenServer that manages game state and player actions
- `state.ex` - Game state struct and state transition logic
- `evaluator.ex` & `hand_evaluator.ex` - Poker hand evaluation logic
- `supervisor.ex` - Supervises individual game processes

### Web Layer (`lib/gang_web/`)
- **LiveViews**:
  - `lobby_live.ex` - Home page for creating/joining games
  - `game_live.ex` - Main game interface with real-time updates
- **Components**:
  - `card_components.ex` - Reusable card UI components
  - `core_components.ex` - Shared Phoenix components

### State Management
- All game state managed by GenServer processes (no database persistence yet)
- Phoenix PubSub broadcasts game updates to connected clients
- Game processes supervised and auto-restart on crashes

## Development Guidelines

### Adding New Game Features
1. Update game logic in `lib/gang/game/state.ex`
2. Add handler in `lib/gang/game/game.ex`
3. Update LiveView event handlers in `lib/gang_web/live/game_live.ex`
4. Add tests in `test/gang/game/` for game logic

### Working with LiveView
- Event handlers defined in `handle_event/3` callbacks
- Use `assign/3` for updating socket state
- Broadcast updates via `GangWeb.Endpoint.broadcast/3`

### Testing
- Run specific test: `mix test test/gang/game/evaluator_test.exs:42`
- Tests use `async: true` for parallel execution
- Mock game states using structs defined in test files

### Current Branch Notes
The `shareable-links` branch has uncommitted changes to styling files. Be aware of these when making UI changes.