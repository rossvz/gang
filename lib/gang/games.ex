defmodule Gang.Games do
  @moduledoc """
  The Games context, providing a higher-level API for interacting with games.
  """

  alias Gang.Game
  alias Gang.Game.Supervisor, as: GameSupervisor
  alias Phoenix.PubSub

  @doc """
  Creates a new game and returns its join code.
  """
  def create_game do
    GameSupervisor.create_game()
  end

  @doc """
  Lists all active games.
  """
  def list_games do
    GameSupervisor.list_games()
    |> Enum.map(fn {game_id, _pid} ->
      {:ok, game} = get_game(game_id)
      game
    end)
    |> Enum.sort_by(& &1.last_active, {:desc, DateTime})
  end

  @doc """
  Gets the current state of a game.
  """
  def get_game(code) do
    if GameSupervisor.game_exists?(code) do
      Game.get_state(code)
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Gets the number of players in a game.
  Excludes disconnected players!
  If someone disconnects or goes to lobby there's a 30s grace period where they can rejoin
  and not lose state.
  """
  def get_player_count(code) do
    with {:ok, state} <- get_game(code) do
      active_count = Enum.count(state.players, & &1.connected)

      {:ok, active_count}
    end
  end

  @doc """
  Gets the status of a game.
  """
  def get_game_status(code) do
    with {:ok, state} <- get_game(code) do
      {:ok, state.status}
    end
  end

  @doc """
  Joins a game with the given code.
  Returns {:ok, game_pid} on success.
  Returns {:error, reason} if the game doesn't exist.
  """
  def join_game(code, player) do
    if GameSupervisor.game_exists?(code) do
      with {:ok, state} <- get_game(code) do
        existing_player = Enum.find(state.players, &(&1.id == player.id))

        if existing_player do
          # Update connection status
          Game.update_connection(code, existing_player.id, true)
          {:ok, existing_player}
        else
          Game.add_player(code, player)
          broadcast_update(code)

          {:ok, GameSupervisor.get_game_pid(code)}
        end
      end
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Leaves a game, removing the player.
  """
  def leave_game(code, player_id) do
    if GameSupervisor.game_exists?(code) do
      result = Game.remove_player(code, player_id)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Updates a player's connection status.
  """
  def update_connection(code, player_id, connected) do
    if GameSupervisor.game_exists?(code) do
      result = Game.update_connection(code, player_id, connected)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Starts a game, transitioning from waiting to the first round.
  """
  def start_game(code) do
    if GameSupervisor.game_exists?(code) do
      result = Game.start_game(code)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Claims a rank chip for a player.
  """
  def claim_rank_chip(code, player_id, rank, color) do
    if GameSupervisor.game_exists?(code) do
      result = Game.claim_chip(code, player_id, rank, color)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Claims a rank chip from another player.
  """
  def claim_rank_chip_from_player(code, player_id, from_player_id, rank, color) do
    if GameSupervisor.game_exists?(code) do
      # First remove the chip from the original player
      Game.return_chip(code, from_player_id, rank, color)
      # Then claim it for the new player
      result = Game.claim_chip(code, player_id, rank, color)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Alias for claim_rank_chip.
  """
  def claim_chip(code, player_id, rank, color) do
    claim_rank_chip(code, player_id, rank, color)
  end

  @doc """
  Returns a player's rank chip to the unclaimed pool.
  """
  def return_rank_chip(code, player_id) do
    if GameSupervisor.game_exists?(code) do
      case get_game(code) do
        {:ok, state} ->
          player = Enum.find(state.players, &(&1.id == player_id))
          chip = Enum.find(player.rank_chips, &(&1.color == state.current_round_color))
          result = Game.return_chip(code, player_id, chip.rank, chip.color)
          broadcast_update(code)
          result

        nil ->
          {:error, :chip_not_found}

        error ->
          error
      end
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Alias for return_rank_chip that accepts specific rank and color.
  """
  def return_chip(code, player_id, rank, color) do
    if GameSupervisor.game_exists?(code) do
      result = Game.return_chip(code, player_id, rank, color)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  @doc """
  Advances the game to the next round.
  """
  def advance_round(code) do
    if GameSupervisor.game_exists?(code) do
      result = Game.advance_round(code)
      broadcast_update(code)
      result
    else
      {:error, :game_not_found}
    end
  end

  # Broadcasts an update of the game state.
  # No @doc for private functions
  defp broadcast_update(code) do
    with {:ok, state} <- get_game(code) do
      PubSub.broadcast(Gang.PubSub, "game:#{code}", {:game_updated, state})
      PubSub.broadcast(Gang.PubSub, "games", {:game_updated, code})
      :ok
    end
  end

  @doc """
  Subscribes the current process to game updates.
  """
  def subscribe(code) do
    PubSub.subscribe(Gang.PubSub, "game:#{code}")
  end

  @doc """
  Subscribe to all games updates (for listings)
  """
  def subscribe_to_games do
    PubSub.subscribe(Gang.PubSub, "games")
  end

  @doc """
  Unsubscribes the current process from game updates.
  """
  def unsubscribe(code) do
    PubSub.unsubscribe(Gang.PubSub, "game:#{code}")
  end

  @doc """
  Checks if a game exists with the given code.
  """
  def game_exists?(code) do
    GameSupervisor.game_exists?(code)
  end

  @doc """
  Gets a player's hand from the game state.
  """
  def get_player_hand(state, player_id) do
    state.players
    |> Enum.find(&(&1.id == player_id))
    |> case do
      nil -> []
      player -> player.cards
    end
  end

  @doc """
  Gets the list of rank chips claimed by or available to a player for the current round.
  """
  def get_round_chips(state, round) do
    Map.get(state.unclaimed_rank_chips, round, [])
  end

  @doc """
  Broadcasts that a new game has been created.
  """
  def broadcast_game_created(game_code) do
    PubSub.broadcast(Gang.PubSub, "games", {:game_created, game_code})
  end
end
