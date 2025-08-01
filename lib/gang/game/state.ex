defmodule Gang.Game.State do
  @moduledoc """
  Represents the state of a game, including players, cards, and round information.

  ## Game Flow

  The game progresses through poker rounds and action phases:

  ### Poker Rounds
  - `:preflop` - Players have 2 hole cards, no community cards
  - `:flop` - 3 community cards are revealed
  - `:turn` - 4th community card is revealed
  - `:river` - 5th community card is revealed
  - `:evaluation` - Hands are evaluated against rank chips

  ### Chip Colors by Round
  - `:preflop` → `:white` chips
  - `:flop` → `:yellow` chips
  - `:turn` → `:orange` chips
  - `:river` → `:red` chips

  ### Game Flow
  1. Game starts at `:preflop` round with `:rank_chip_selection` phase
  2. After chip selection, we advance to the next round (`:flop`, `:turn`, etc.)
  3. After `:river` and chip selection, we move to `:evaluation`
  4. After `:evaluation`:
     - Game ends if 3 vaults or 3 alarms are reached
     - Otherwise reset to `:preflop` with new cards
  """

  alias Gang.Game.Card
  alias Gang.Game.ChatMessage
  alias Gang.Game.Deck
  alias Gang.Game.Evaluator
  alias Gang.Game.Player
  alias Gang.Game.RankChip

  @type status :: :waiting | :playing | :completed
  @type phase :: :rank_chip_selection | :dealing
  @type round :: :preflop | :flop | :turn | :river | :evaluation
  @type round_color :: :white | :yellow | :orange | :red
  @type round_result :: :vault | :alarm | nil

  @type t :: %__MODULE__{
          code: String.t(),
          owner_id: String.t() | nil,
          players: list(Player.t()),
          status: status(),
          current_round: round(),
          current_phase: phase(),
          current_round_color: round_color(),
          vaults: integer(),
          alarms: integer(),
          community_cards: list(Card.t() | nil),
          all_rank_chips_claimed?: boolean(),
          deck: list(Card.t()),
          game_created: DateTime.t() | nil,
          last_active: DateTime.t(),
          evaluated_hands: map() | nil,
          expected_rankings: map() | nil,
          last_round_result: round_result() | nil,
          chat_messages: list(ChatMessage.t())
        }

  defstruct [
    :code,
    :owner_id,
    players: [],
    status: :waiting,
    current_round: :preflop,
    current_phase: :rank_chip_selection,
    current_round_color: :white,
    vaults: 0,
    alarms: 0,
    last_round_result: nil,
    community_cards: [nil, nil, nil, nil, nil],
    all_rank_chips_claimed?: false,
    deck: [],
    game_created: DateTime.utc_now(),
    last_active: DateTime.utc_now(),
    evaluated_hands: nil,
    expected_rankings: nil,
    chat_messages: []
  ]

  @doc """
  Creates a new game state with a unique code and empty players.
  """
  def new(code, owner_id \\ nil) do
    %__MODULE__{
      code: code,
      owner_id: owner_id,
      last_active: DateTime.utc_now(),
      game_created: DateTime.utc_now()
    }
  end

  @doc """
  Adds a player to the game.
  Only allowed during the waiting phase.
  """
  def add_player(state, player) do
    if state.status in [:waiting] do
      %{
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
  def remove_player(state, player_id) do
    updated_players = Enum.reject(state.players, &(&1.id == player_id))

    %{
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
      deck = Deck.shuffle(Deck.new())
      {players_with_cards, remaining_deck} = deal_player_cards(state.players, deck)

      %{
        state
        | status: :playing,
          current_round: :preflop,
          current_phase: :rank_chip_selection,
          current_round_color: :white,
          players: players_with_cards,
          deck: remaining_deck,
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Advances the game to the next round.

  This function handles the progression between poker rounds:

  - From `:preflop` → `:flop`: Deals 3 community cards
  - From `:flop` → `:turn`: Deals the 4th community card
  - From `:turn` → `:river`: Deals the 5th community card
  - From `:river` → `:evaluation`: Handled by Game module, not here
  - From `:evaluation` → `:preflop`: Handled by Game module, not here
  """
  def advance_round(state) do
    cond do
      state.status != :playing ->
        state

      state.current_round == :river ->
        %{round_result: round_result, player_hands: player_hands, expected_rankings: expected_rankings} =
          Evaluator.evaluate_round(state)

        state =
          state
          |> set_alarm_or_vault(round_result)
          |> set_status()

        %{state | evaluated_hands: player_hands, expected_rankings: expected_rankings, current_round: :evaluation}

      state.current_round == :evaluation ->
        start_new_hand(state)

      # Normal round advancement for earlier rounds
      true ->
        {next_round, next_color, updated_community_cards, remaining_deck} =
          case state.current_round do
            :preflop ->
              # Deal flop (3 cards)
              {cards, deck_after_deal} = Deck.deal(state.deck, 3)

              updated_cards =
                state.community_cards
                |> List.replace_at(0, Enum.at(cards, 0))
                |> List.replace_at(1, Enum.at(cards, 1))
                |> List.replace_at(2, Enum.at(cards, 2))

              {:flop, :yellow, updated_cards, deck_after_deal}

            :flop ->
              # Deal turn (1 card)
              {[card], deck_after_deal} = Deck.deal(state.deck, 1)
              updated_cards = List.replace_at(state.community_cards, 3, card)
              {:turn, :orange, updated_cards, deck_after_deal}

            :turn ->
              # Deal river (1 card)
              {[card], deck_after_deal} = Deck.deal(state.deck, 1)
              updated_cards = List.replace_at(state.community_cards, 4, card)
              {:river, :red, updated_cards, deck_after_deal}
          end

        %{
          state
          | current_round: next_round,
            current_round_color: next_color,
            all_rank_chips_claimed?: false,
            community_cards: updated_community_cards,
            deck: remaining_deck,
            current_phase: :rank_chip_selection,
            evaluated_hands: nil,
            expected_rankings: nil,
            last_active: DateTime.utc_now()
        }
    end
  end

  defp set_alarm_or_vault(state, result) do
    if result == :vault do
      %{state | vaults: state.vaults + 1, last_round_result: :vault}
    else
      %{state | alarms: state.alarms + 1, last_round_result: :alarm}
    end
  end

  defp set_status(state) do
    status = if Evaluator.game_over?(state), do: :completed, else: :playing
    %{state | status: status}
  end

  @doc """
  Starts a new hand after evaluation.
  Resets to preflop with new cards for all players.
  """
  def start_new_hand(state) do
    if state.current_round == :evaluation do
      # Deal new cards to players
      deck = Deck.shuffle(Deck.new())
      {players_with_cards, remaining_deck} = deal_player_cards(state.players, deck)

      %{
        state
        | current_round: :preflop,
          current_phase: :rank_chip_selection,
          current_round_color: :white,
          players: players_with_cards,
          deck: remaining_deck,
          community_cards: [nil, nil, nil, nil, nil],
          all_rank_chips_claimed?: false,
          evaluated_hands: nil,
          expected_rankings: nil,
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Claims a rank chip for a player.
  """
  def claim_chip(state, player_id, rank, color_atom) do
    player = Enum.find(state.players, &(&1.id == player_id))

    if player && state.status == :playing && state.current_phase == :rank_chip_selection do
      # Check if any player in current round already has this chip
      existing_holder =
        Enum.find(state.players, fn p ->
          Enum.any?(p.rank_chips, &(&1.rank == rank && &1.color == color_atom))
        end)

      # Remove chip from existing holder if needed
      updated_players =
        if existing_holder do
          Enum.map(state.players, fn p ->
            if p.id == existing_holder.id do
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
          if p.id == player_id do
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

      %{
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
  Resets the game to the initial state while keeping all players.
  Used for starting a new game with the same players after completion.
  """
  def reset_game(state) do
    if state.status == :completed do
      # Clear player cards and rank chips but keep the players
      reset_players =
        Enum.map(state.players, fn player ->
          %{player | cards: [], rank_chips: []}
        end)

      %{
        state
        | status: :waiting,
          current_round: :preflop,
          current_phase: :rank_chip_selection,
          current_round_color: :white,
          vaults: 0,
          alarms: 0,
          last_round_result: nil,
          community_cards: [nil, nil, nil, nil, nil],
          all_rank_chips_claimed?: false,
          deck: [],
          players: reset_players,
          evaluated_hands: nil,
          expected_rankings: nil,
          last_active: DateTime.utc_now()
      }
    else
      state
    end
  end

  @doc """
  Returns a player's chip to the unclaimed pool.
  """
  def return_chip(state, player_id, rank, color_atom) do
    if state.status == :playing && state.current_phase == :rank_chip_selection do
      # Update the players to remove the chip
      updated_players =
        Enum.map(state.players, fn player ->
          if player.id == player_id do
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

      %{
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
  def update_player_connection(state, player_id, connected) do
    updated_players =
      Enum.map(state.players, fn player ->
        if player.id == player_id do
          if connected do
            %{player | connected: true}
          else
            %{player | connected: false}
          end
        else
          player
        end
      end)

    %{state | players: updated_players, last_active: DateTime.utc_now()}
  end

  @doc """
  Updates a player's information (name and avatar) when they rejoin.
  """
  def update_player_info(state, new_player) do
    updated_players =
      Enum.map(state.players, fn player ->
        if player.id == new_player.id do
          %{player | name: new_player.name, avatar: new_player.avatar}
        else
          player
        end
      end)

    %{state | players: updated_players, last_active: DateTime.utc_now()}
  end

  @doc """
  Deals cards to all players from the given deck.
  Returns a tuple of {updated_players, remaining_deck}.
  """
  def deal_player_cards(players, deck) do
    Enum.map_reduce(players, deck, fn player, current_deck ->
      {cards, remaining_deck} = Deck.deal(current_deck, 2)
      {%{player | cards: cards, rank_chips: []}, remaining_deck}
    end)
  end

  # Maximum number of chat messages to keep in memory
  @max_chat_messages 50

  @doc """
  Adds a chat message to the game state.
  Keeps only the last #{@max_chat_messages} messages to prevent memory growth.
  """
  def add_chat_message(state, player_id, message) do
    # Find the player to get their info
    player = Enum.find(state.players, &(&1.id == player_id))

    if player do
      chat_message = ChatMessage.new(player_id, player.name, player.avatar, message)

      # Add new message to the end and enforce memory limit
      # Keep messages in chronological order (oldest first)
      updated_messages = Enum.take(state.chat_messages ++ [chat_message], -@max_chat_messages)

      %{state | chat_messages: updated_messages, last_active: DateTime.utc_now()}
    else
      state
    end
  end

  @doc """
  Maps a round to its corresponding chip color.
  """
  def get_round_color(round) do
    case round do
      :preflop -> :white
      :flop -> :yellow
      :turn -> :orange
      :river -> :red
      _ -> :white
    end
  end
end
