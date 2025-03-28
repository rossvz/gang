defmodule Gang.Game.State do
  @moduledoc """
  Represents the state of a game, including players, cards, and round information.
  """

  alias Gang.Game.{Card, Deck, Player, RankChip}

  @type status :: :waiting | :playing | :completed
  @type phase :: :rank_chip_selection | :dealing | :evaluation
  @type round_color :: :white | :yellow | :orange | :red

  @type t :: %__MODULE__{
          code: String.t(),
          players: list(Player.t()),
          status: status(),
          round: integer(),
          current_phase: phase(),
          current_round_color: round_color(),
          vaults: integer(),
          alarms: integer(),
          community_cards: list(Card.t() | nil),
          all_rank_chips_claimed?: boolean(),
          deck: list(Card.t()),
          game_start: DateTime.t() | nil,
          last_active: DateTime.t()
        }

  defstruct [
    :code,
    players: [],
    status: :waiting,
    round: 1,
    current_phase: :rank_chip_selection,
    current_round_color: :white,
    vaults: 0,
    alarms: 0,
    community_cards: [nil, nil, nil, nil, nil],
    all_rank_chips_claimed?: false,
    deck: [],
    game_start: nil,
    last_active: DateTime.utc_now()
  ]

  @doc """
  Creates a new game state with a unique code and empty players.
  """
  def new(code) do
    %__MODULE__{
      code: code,
      last_active: DateTime.utc_now()
    }
  end

  @doc """
  Adds a player to the game.
  Only allowed during the waiting phase.
  """
  def add_player(state, player) do
    if state.status in [:waiting] do
      %__MODULE__{
        state
        | players: state.players ++ [player],
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Removes a player from the game.
  """
  def remove_player(state, player_name) do
    updated_players = Enum.reject(state.players, &(&1.name == player_name))

    %__MODULE__{
      state
      | players: updated_players,
        last_active: DateTime.utc_now()
    }
  end

  @doc """
  Starts the game, transitioning from waiting to the preflop round.
  """
  def start_game(state) do
    if state.status == :waiting && length(state.players) >= 3 do
      # Shuffle a new deck and deal cards to each player
      deck = Deck.new() |> Deck.shuffle()
      {players_with_cards, remaining_deck} = deal_player_cards(state.players, deck)

      %__MODULE__{
        state
        | status: :playing,
          round: 1,
          current_phase: :rank_chip_selection,
          current_round_color: :white,
          players: players_with_cards,
          deck: remaining_deck,
          game_start: DateTime.utc_now(),
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Advances the game to the next round.
  """
  def advance_round(state) do
    if state.status != :playing || state.round >= 5 do
      state
    else
      # Update round number and color
      new_round = state.round + 1
      new_color = get_round_color(new_round)

      # Deal community cards based on the round
      {updated_community_cards, remaining_deck} =
        deal_community_cards(state.community_cards, state.deck, new_round)

      %__MODULE__{
        state
        | round: new_round,
          current_round_color: new_color,
          all_rank_chips_claimed?: false,
          community_cards: updated_community_cards,
          deck: remaining_deck,
          last_active: DateTime.utc_now()
      }
    end
  end

  @doc """
  Claims a rank chip for a player.
  """
  def claim_chip(state, player_name, rank, color_atom) do
    player = Enum.find(state.players, &(&1.name == player_name))

    if player && state.status == :playing && state.current_phase == :rank_chip_selection do
      # Check if any player in current round already has this chip
      existing_holder =
        Enum.find(state.players, fn p ->
          Enum.any?(p.rank_chips, &(&1.rank == rank && &1.color == color_atom))
        end)

      # if existing holder is the same as current player, return to unclaimed game chips
      # TODO

      # Remove chip from existing holder if needed
      updated_players =
        if existing_holder do
          Enum.map(state.players, fn p ->
            if p.name == existing_holder.name do
              # Remove the chip from this player
              updated_chips =
                Enum.reject(p.rank_chips, &(&1.rank == rank && &1.color == color_atom))

              %{p | rank_chips: updated_chips}
            else
              p
            end
          end)
        else
          state.players
        end

      # Remove any existing chip of the same color from the claiming player
      updated_players =
        Enum.map(updated_players, fn p ->
          if p.name == player_name do
            # Remove any existing chip of the same color
            updated_chips = Enum.reject(p.rank_chips, &(&1.color == color_atom))
            # Add the new chip
            new_chip = %RankChip{rank: rank, color: color_atom}
            %{p | rank_chips: [new_chip | updated_chips]}
          else
            p
          end
        end)

      # Check if all players have a chip of the current color
      all_claimed =
        Enum.all?(updated_players, fn p ->
          Enum.any?(p.rank_chips, &(&1.color == color_atom))
        end)

      %__MODULE__{
        state
        | players: updated_players,
          all_rank_chips_claimed?: all_claimed,
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Returns a player's chip to the unclaimed pool.
  """
  def return_chip(state, player_name, rank, color_atom) do
    if state.status == :playing && state.current_phase == :rank_chip_selection do
      # Update the players to remove the chip
      updated_players =
        Enum.map(state.players, fn player ->
          if player.name == player_name do
            updated_chips =
              Enum.reject(player.rank_chips, &(&1.rank == rank && &1.color == color_atom))

            %{player | rank_chips: updated_chips}
          else
            player
          end
        end)

      # Update all_claimed flag
      all_claimed =
        Enum.all?(updated_players, fn p ->
          Enum.any?(p.rank_chips, &(&1.color == state.current_round_color))
        end)

      %__MODULE__{
        state
        | players: updated_players,
          all_rank_chips_claimed?: all_claimed,
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Updates a player's connection status.
  """
  def update_player_connection(state, player_name, connected) do
    updated_players =
      Enum.map(state.players, fn player ->
        if player.name == player_name do
          if connected do
            %{player | connected: true}
          else
            %{player | connected: false}
          end
        else
          player
        end
      end)

    %__MODULE__{state | players: updated_players, last_active: DateTime.utc_now()}
  end

  # Helper functions

  defp deal_player_cards(players, deck) do
    Enum.map_reduce(players, deck, fn player, current_deck ->
      {cards, remaining_deck} = Deck.deal(current_deck, 2)
      {%{player | cards: cards}, remaining_deck}
    end)
  end

  defp deal_community_cards(community_cards, deck, round) do
    case round do
      # Flop - 3 cards
      2 ->
        {cards, remaining_deck} = Deck.deal(deck, 3)

        {List.replace_at(community_cards, 0, Enum.at(cards, 0))
         |> List.replace_at(1, Enum.at(cards, 1))
         |> List.replace_at(2, Enum.at(cards, 2)), remaining_deck}

      # Turn - 1 card
      3 ->
        {[card], remaining_deck} = Deck.deal(deck, 1)
        {List.replace_at(community_cards, 3, card), remaining_deck}

      # River - 1 card
      4 ->
        {[card], remaining_deck} = Deck.deal(deck, 1)
        {List.replace_at(community_cards, 4, card), remaining_deck}

      _ ->
        {community_cards, deck}
    end
  end

  defp get_round_color(round) do
    case round do
      1 -> :white
      2 -> :yellow
      3 -> :orange
      4 -> :red
      _ -> :white
    end
  end
end
