defmodule Gang.Game do
  @moduledoc """
  Represents an active game session. This is the GenServer that manages the game state.

  Primarily acts as the orchestration layer

  Generally the responsibility of updating the state is pushed to `Gang.Game.State` module
  The Game generally handles the GenServer API management
  as well as broadcasting updates to via PubSub
  """

  use GenServer, restart: :temporary

  alias Gang.Game.Player
  alias Gang.Game.State
  alias Gang.PubSub

  require Logger

  # How long to wait for a player to reconnect after they leave the game
  @permanently_remove_player_timeout 90_000

  # Client API

  def start_link(code) when is_binary(code) do
    GenServer.start_link(__MODULE__, code, name: via_tuple(code))
  end

  def start_link({code, owner_id}) do
    GenServer.start_link(__MODULE__, {code, owner_id}, name: via_tuple(code))
  end

  @doc """
  Adds a player to the game.
  """
  def add_player(code, %Player{} = player) when is_binary(code) do
    GenServer.call(via_tuple(code), {:join, player})
  end

  @doc """
  Removes a player from the game.
  """
  def remove_player(code, player_id) when is_binary(code) and is_binary(player_id) do
    GenServer.call(via_tuple(code), {:leave, player_id})
  end

  @doc """
  Updates a player's connection status.
  """
  def update_connection(code, player_id, connected) when is_binary(code) and is_binary(player_id) do
    GenServer.call(via_tuple(code), {:update_connection, player_id, connected})
  end

  def join(game_pid, %Player{} = player) do
    GenServer.call(game_pid, {:join, player})
  end

  def leave(game_pid, player_id) do
    GenServer.call(game_pid, {:leave, player_id})
  end

  def start_game(code) when is_binary(code) do
    GenServer.call(via_tuple(code), :start_game)
  end

  def start_game(game_pid) do
    GenServer.call(game_pid, :start_game)
  end

  def get_state(code) when is_binary(code) do
    GenServer.call(via_tuple(code), :get_state)
  end

  def get_state(game_pid) do
    GenServer.call(game_pid, :get_state)
  end

  @doc """
  Claims a rank chip.
  """
  def claim_chip(code, player_id, rank, color) when is_binary(code) and is_binary(player_id) do
    GenServer.call(via_tuple(code), {:claim_rank_chip, player_id, rank, color})
  end

  def claim_rank_chip(game_pid, player_id, rank, color) do
    GenServer.call(game_pid, {:claim_rank_chip, player_id, rank, color})
  end

  @doc """
  Returns a rank chip.
  """
  def return_chip(code, player_id, rank, color) when is_binary(code) and is_binary(player_id) do
    GenServer.call(via_tuple(code), {:return_rank_chip, player_id, rank, color})
  end

  def return_rank_chip(game_pid, player_id, rank, color) do
    GenServer.call(game_pid, {:return_rank_chip, player_id, rank, color})
  end

  @doc """
  Advances to the next poker round or evaluates the hand.

  This function manages game flow progression:
  - Moves from one poker round to the next (preflop → flop → turn → river)
  - Transitions from river to evaluation
  - Evaluates hands during evaluation
  - Starts a new hand after evaluation
  """
  def advance_round(code) when is_binary(code) do
    GenServer.call(via_tuple(code), :advance_round)
  end

  def advance_round(game_pid) do
    GenServer.call(game_pid, :advance_round)
  end

  @doc """
  Resets the game to initial state while keeping all players.
  Only works when game status is :completed.
  """
  def reset_game(code) when is_binary(code) do
    GenServer.call(via_tuple(code), :reset_game)
  end

  def reset_game(game_pid) do
    GenServer.call(game_pid, :reset_game)
  end

  # Server callbacks

  @impl true
  def init(code) when is_binary(code) do
    {:ok, State.new(code)}
  end

  def init({code, owner_id}) do
    {:ok, State.new(code, owner_id)}
  end

  @impl true
  def handle_call({:join, %Player{} = player}, _from, state) do
    # Check if player is already in the game by ID first, then by name if no ID
    existing_player =
      if player.id do
        Enum.find(state.players, &(&1.id == player.id))
      else
        Enum.find(state.players, &(&1.name == player.name))
      end

    if existing_player do
      # Just update connection status to true
      updated_state = State.update_player_connection(state, existing_player.id, true)
      broadcast_update(updated_state)
      {:reply, {:ok, updated_state}, updated_state}
    else
      # Add new player
      updated_state = State.add_player(state, player)
      broadcast_update(updated_state)
      {:reply, {:ok, updated_state}, updated_state}
    end
  end

  @impl true
  def handle_call({:leave, player_id}, _from, state) do
    updated_state = State.update_player_connection(state, player_id, false)
    broadcast_update(updated_state)

    # wait a while to see if they come back, otherwise assume they're gone
    Process.send_after(
      self(),
      {:permanently_remove_player, player_id},
      @permanently_remove_player_timeout
    )

    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call({:update_connection, player_id, connected}, _from, state) do
    updated_state = State.update_player_connection(state, player_id, connected)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call(:start_game, _from, state) do
    if length(state.players) >= 3 && state.status == :waiting do
      updated_state = State.start_game(state)
      broadcast_update(updated_state)
      {:reply, {:ok, updated_state}, updated_state}
    else
      {:reply, {:error, "Not enough players or game already in progress"}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:claim_rank_chip, player_id, rank, color}, _from, state) do
    updated_state = State.claim_chip(state, player_id, rank, color)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call({:return_rank_chip, player_id, rank, color}, _from, state) do
    updated_state = State.return_chip(state, player_id, rank, color)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call(:advance_round, _from, state) do
    updated_state = State.advance_round(state)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call(:reset_game, _from, state) do
    updated_state = State.reset_game(state)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_info({:permanently_remove_player, player_id}, state) do
    # Check if the player is still connected - if so, don't remove them
    case Enum.find(state.players, &(&1.id == player_id)) do
      nil ->
        # Player not found, nothing to remove
        {:noreply, state}

      %{connected: true} ->
        Logger.info("Player #{player_id} has reconnected, not removing")
        # Player has reconnected, don't remove them
        {:noreply, state}

      %{connected: false} ->
        # Player is still disconnected, proceed with removal
        updated_state = State.remove_player(state, player_id)
        broadcast_update(updated_state)
        {:noreply, updated_state}
    end
  end

  defp broadcast_update(state) do
    Phoenix.PubSub.broadcast(PubSub, "game:#{state.code}", {:game_updated, state})
    Phoenix.PubSub.broadcast(PubSub, "games", {:game_updated, state})
  end

  # Helper to get process via the registry
  defp via_tuple(code) do
    {:via, Registry, {Gang.GameRegistry, code}}
  end
end
