defmodule Gang.Janitor do
  @moduledoc """
  A GenServer that cleans up inactive games after a certain period of time.
  """

  use GenServer

  alias Gang.Game.Supervisor
  alias Gang.Games
  alias Phoenix.PubSub

  require Logger

  @inactive_threshold_minutes to_timeout(hour: 1)

  @cleanup_interval to_timeout(minute: 1)
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl GenServer
  def init(init_arg) do
    cleanup_inactive_games()
    :timer.apply_interval(@cleanup_interval, __MODULE__, :cleanup_inactive_games, [])

    {:ok, init_arg}
  end

  @doc """
  Periodically cleans up inactive games.
  Checks games against the `@inactive_threshold_minutes`.
  """
  def cleanup_inactive_games do
    Logger.info("Starting inactive game cleanup...")
    threshold_datetime = DateTime.add(DateTime.utc_now(), -@inactive_threshold_minutes, :second)
    games_to_check = Games.list_games()

    Enum.each(games_to_check, fn game ->
      if game.last_active && DateTime.before?(game.last_active, threshold_datetime) do
        Logger.info("Cleaning up inactive game: #{game.code}, last active: #{game.last_active}")
        :ok = Supervisor.terminate_game(game.code)
        PubSub.broadcast(Gang.PubSub, "games", {:game_removed, game.code})
      end
    end)
  end
end
