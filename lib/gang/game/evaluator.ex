defmodule Gang.Game.Evaluator do
  @moduledoc """
  Evaluates the results of a round and determines if players get a vault or an alarm.
  """

  alias Gang.Game.{HandEvaluator, State}

  @doc """
  Evaluates the current round and updates the state with a vault or alarm.
  This is used in the final phase of each round.
  """
  def evaluate_round(state) do
    # Get the players and their ranks from the rank chips
    players_with_red_chips =
      Enum.filter(state.players, fn player ->
        Enum.any?(player.rank_chips, &(&1.color == :red))
      end)

    # Get ordered player names by their red rank chips (1 is lowest, 4 is highest)
    ordered_players =
      players_with_red_chips
      |> Enum.map(fn player ->
        red_chip = Enum.find(player.rank_chips, &(&1.color == :red))
        {player.name, red_chip.rank}
      end)
      |> Enum.sort_by(fn {_name, rank} -> rank end)
      |> Enum.map(fn {name, _rank} -> name end)

    # Evaluate each player's hand
    player_hands =
      Enum.reduce(players_with_red_chips, %{}, fn player, acc ->
        filtered_community_cards = Enum.filter(state.community_cards, &(&1 != nil))
        hand_value = HandEvaluator.evaluate(player.cards, filtered_community_cards)
        Map.put(acc, player.name, hand_value)
      end)

    # Check if the ordering is correct (weakest to strongest)
    is_correct_order = evaluate_order(ordered_players, player_hands)

    # Update the state with a vault or alarm and store evaluated hands
    updated_state =
      if is_correct_order do
        %State{
          state
          | vaults: state.vaults + 1,
            evaluated_hands: player_hands,
            current_phase: :evaluation
        }
      else
        %State{
          state
          | alarms: state.alarms + 1,
            evaluated_hands: player_hands,
            current_phase: :evaluation
        }
      end

    # Check if the game is over
    if game_over?(updated_state) do
      # Game is over
      %State{updated_state | status: :completed}
    else
      # Continue to the next round
      updated_state
    end
  end

  # Checks if player hands are correctly ordered based on their rank chips.
  # Player with rank 1 should have the weakest hand, and so on.
  defp evaluate_order(ordered_player_ids, player_hands) do
    # If we have fewer than 2 players, the order is trivially correct
    if length(ordered_player_ids) < 2 do
      true
    else
      # Check each adjacent pair of players
      ordered_player_ids
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [player1_id, player2_id] ->
        hand1 = Map.get(player_hands, player1_id)
        hand2 = Map.get(player_hands, player2_id)

        # The first player should have a weaker hand than the second
        HandEvaluator.compare_hands(hand1, hand2) == :lt
      end)
    end
  end

  @doc """
  Determines if the game is over (3 vaults or 3 alarms).
  """
  def game_over?(state) do
    state.vaults >= 3 || state.alarms >= 3
  end

  @doc """
  Returns whether the players have won (3 vaults) or lost (3 alarms).
  """
  def game_result(state) do
    cond do
      state.vaults >= 3 -> :win
      state.alarms >= 3 -> :lose
      true -> :in_progress
    end
  end
end
