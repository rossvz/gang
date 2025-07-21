# AGENTS.md - Gang Project Guidelines

## Build/Test Commands
- `mix test` - Run all tests
- `mix test path/to/test.exs:42` - Run specific test at line 42
- `mix format` - Format all Elixir code (uses Styler plugin)
- `mix phx.server` - Start dev server (auto-runs, don't start manually)
- `mix assets.build` - Build CSS/JS for development
- `mix compile --warnings-as-errors` - Compile with strict warnings

## Code Style Guidelines
- Use newest Phoenix LiveView syntax: prefer `{foo}` over `<%= foo %>` in .heex files
- Follow .formatter.exs config: uses Styler plugin, Phoenix.LiveView.HTMLFormatter
- Imports: Group by standard library, deps, then local modules (alias Gang.Game.Player)
- Types: Use @type for clarity in LiveViews and complex modules
- Naming: snake_case for functions/variables, PascalCase for modules
- Error handling: Use {:ok, result} | {:error, reason} tuples consistently
- GenServer pattern: Client API functions at top, callbacks below
- Tests: Use async: true, descriptive test names, helper functions for setup
- Documentation: @moduledoc for modules, @doc for public functions
- Constants: Use module attributes (@permanently_remove_player_timeout 90_000)

## Project Notes
- Phoenix LiveView 1.7.18 with Elixir 1.14+
- All game state in GenServer processes (no DB persistence)
- Use PubSub for real-time updates between clients