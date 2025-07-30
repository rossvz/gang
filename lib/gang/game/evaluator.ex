defmodule Gang.Game.Evaluator do
  @moduledoc """
  Evaluates the results of a round and determines if players get a vault or an alarm.

  This module is responsible for:
  1. Evaluating poker hands of players
  2. Comparing their hand strengths to rank chip predictions
  3. Awarding vaults (success) or alarms (failure) based on hand ranking correctness
  4. Determining if the game is complete (3 vaults or 3 alarms)
  """

  alias Gang.Game.HandEvaluator

  @doc """
  Evaluates the current round and updates the state with a vault or alarm.

  This function:
  1. Identifies players with red rank chips
  2. Evaluates each player's poker hand
  3. Checks if hands are ordered correctly according to rank chip values
  4. Awards vault (success) or alarm (failure) based on evaluation
  5. Determines if the game is complete (3 vaults or 3 alarms reached)

  Returns updated state with:
  - Incremented vault or alarm count
  - Evaluated hands stored for UI display
  - Game status set to :completed if game is over
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

    # Sort players by actual hand strength (weakest to strongest) to get expected order
    expected_order =
      player_hands
      |> Enum.sort_by(fn {_name, hand} -> hand end, fn hand1, hand2 ->
        HandEvaluator.compare_hands(hand1, hand2) != :gt
      end)
      |> Enum.with_index(1)
      |> Map.new(fn {{name, _hand}, rank} -> {name, rank} end)

    # Check if the ordering is correct (weakest to strongest)
    is_correct_order = evaluate_order(ordered_players, player_hands)
    round_result = if is_correct_order, do: :vault, else: :alarm

    %{
      round_result: round_result,
      player_hands: player_hands,
      expected_rankings: expected_order
    }
  end

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
        # or they should have the same hand (still considered valid win)
        HandEvaluator.compare_hands(hand1, hand2) in [:lt, :eq]
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
