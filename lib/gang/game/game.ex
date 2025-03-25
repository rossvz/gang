defmodule Gang.Game.Game do
  @moduledoc """
  Represents an active game session. This is the GenServer that manages the game state.
  """

  use GenServer, restart: :temporary

  alias Gang.PubSub
  alias Gang.Game.{Evaluator, Player, State, Deck}

  # Client API

  def start_link(code) do
    GenServer.start_link(__MODULE__, code, name: via_tuple(code))
  end

  @doc """
  Adds a player to the game.
  """
  def add_player(code, player_name) when is_binary(code) and is_binary(player_name) do
    GenServer.call(via_tuple(code), {:join, player_name})
  end

  @doc """
  Removes a player from the game.
  """
  def remove_player(code, player_name) when is_binary(code) and is_binary(player_name) do
    GenServer.call(via_tuple(code), {:leave, player_name})
  end

  @doc """
  Updates a player's connection status.
  """
  def update_connection(code, player_name, connected)
      when is_binary(code) and is_binary(player_name) do
    GenServer.call(via_tuple(code), {:update_connection, player_name, connected})
  end

  def join(game_pid, player_name) do
    GenServer.call(game_pid, {:join, player_name})
  end

  def leave(game_pid, player_name) do
    GenServer.call(game_pid, {:leave, player_name})
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
  def claim_chip(code, player_name, rank, color)
      when is_binary(code) and is_binary(player_name) do
    GenServer.call(via_tuple(code), {:claim_rank_chip, player_name, rank, color})
  end

  def claim_rank_chip(game_pid, player_name, rank, color) do
    GenServer.call(game_pid, {:claim_rank_chip, player_name, rank, color})
  end

  @doc """
  Returns a rank chip.
  """
  def return_chip(code, player_name, rank, color)
      when is_binary(code) and is_binary(player_name) do
    GenServer.call(via_tuple(code), {:return_rank_chip, player_name, rank, color})
  end

  def return_rank_chip(game_pid, player_name, rank, color) do
    GenServer.call(game_pid, {:return_rank_chip, player_name, rank, color})
  end

  def advance_round(code) when is_binary(code) do
    GenServer.call(via_tuple(code), :advance_round)
  end

  def advance_round(game_pid) do
    GenServer.call(game_pid, :advance_round)
  end

  # Server callbacks

  @impl true
  def init(code) do
    {:ok, State.new(code)}
  end

  @impl true
  def handle_call({:join, player_name}, _from, state) do
    # Check if player is already in the game
    if Enum.any?(state.players, &(&1.name == player_name)) do
      # Just update connection status to true
      updated_state = State.update_player_connection(state, player_name, true)
      broadcast_update(updated_state)
      {:reply, {:ok, updated_state}, updated_state}
    else
      # Add new player
      player = Player.new(player_name)
      updated_state = State.add_player(state, player)
      broadcast_update(updated_state)
      {:reply, {:ok, updated_state}, updated_state}
    end
  end

  @impl true
  def handle_call({:leave, player_name}, _from, state) do
    updated_state = State.update_player_connection(state, player_name, false)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call({:update_connection, player_name, connected}, _from, state) do
    updated_state = State.update_player_connection(state, player_name, connected)
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
  def handle_call({:claim_rank_chip, player_name, rank, color}, _from, state) do
    updated_state = State.claim_chip(state, player_name, rank, color)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call({:return_rank_chip, player_name, rank, color}, _from, state) do
    updated_state = State.return_chip(state, player_name, rank, color)
    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  @impl true
  def handle_call(:advance_round, _from, state) do
    updated_state =
      if state.all_rank_chips_claimed? do
        if state.round == 4 do
          # Final round evaluation
          evaluated_state = Evaluator.evaluate_round(state)

          # If game is not over, start a new hand (deal new cards, reset to round 1, etc)
          if evaluated_state.status != :completed do
            # Shuffle a new deck and deal cards to each player
            deck = Deck.new() |> Deck.shuffle()

            {players_with_cards, remaining_deck} =
              deal_player_cards(evaluated_state.players, deck)

            %{
              evaluated_state
              | round: 1,
                current_phase: :rank_chip_selection,
                current_round_color: :white,
                players: players_with_cards,
                deck: remaining_deck,
                community_cards: [nil, nil, nil, nil, nil],
                all_rank_chips_claimed?: false
            }
          else
            evaluated_state
          end
        else
          # Advance to next round
          State.advance_round(state)
        end
      else
        state
      end

    broadcast_update(updated_state)
    {:reply, {:ok, updated_state}, updated_state}
  end

  # Helper function to deal cards to players (moved from State module)
  defp deal_player_cards(players, deck) do
    Enum.map_reduce(players, deck, fn player, current_deck ->
      # Clear ALL rank chips when starting a new hand, not just the red ones
      # This resets chips after a vault or alarm is triggered
      updated_rank_chips = []

      # Deal new cards
      {cards, remaining_deck} = Deck.deal(current_deck, 2)

      # Return player with new cards and no rank chips
      {%{player | cards: cards, rank_chips: updated_rank_chips}, remaining_deck}
    end)
  end

  defp broadcast_update(state) do
    Phoenix.PubSub.broadcast(PubSub, "game:#{state.code}", {:game_updated, state})
  end

  # Helper to get process via the registry
  defp via_tuple(code) do
    {:via, Registry, {Gang.GameRegistry, code}}
  end
end
