defmodule Gang.Game.EvaluatorTest do
  use ExUnit.Case

  alias Gang.Game.Card
  alias Gang.Game.Evaluator
  alias Gang.Game.Player
  alias Gang.Game.RankChip
  alias Gang.Game.State

  # Test Helper Functions
  defp build_state(players_config, community_cards, opts \\ []) do
    %State{
      current_round: Keyword.get(opts, :round, :river),
      vaults: Keyword.get(opts, :vaults, 0),
      alarms: Keyword.get(opts, :alarms, 0),
      players: Enum.map(players_config, &build_player/1),
      community_cards: parse_cards(community_cards)
    }
  end

  defp build_player({name, cards, rank}) do
    %Player{
      name: name,
      cards: parse_cards(cards),
      rank_chips: [%RankChip{rank: rank, color: :red}]
    }
  end

  defp parse_cards(cards) when is_list(cards) do
    Enum.map(cards, &parse_card/1)
  end

  defp parse_card({rank, suit}) do
    %Card{rank: parse_rank(rank), suit: suit}
  end

  defp parse_rank(rank) when is_integer(rank), do: rank
  defp parse_rank(:A), do: 14
  defp parse_rank(:K), do: 13
  defp parse_rank(:Q), do: 12
  defp parse_rank(:J), do: 11

  describe "evaluate_round/1" do
    test "returns :vault when player hands match rank chip order" do
      state =
        build_state(
          [
            {"player1", [{2, :hearts}, {3, :diamonds}], 1},
            {"player2", [{10, :spades}, {10, :hearts}], 2}
          ],
          [{5, :diamonds}, {6, :clubs}, {7, :spades}, {8, :hearts}, {9, :diamonds}]
        )

      # Player1 has a lower hand (high card 9) while Player2 has a pair of 10s
      # Since Player1 has rank 1 and Player2 has rank 2, the ordering is correct

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :vault
      assert is_map(result.player_hands)
      assert map_size(result.player_hands) == 2
    end

    test "returns :alarm when player hands do not match rank chip order" do
      state =
        build_state(
          [
            {"player1", [{10, :spades}, {10, :hearts}], 1},
            {"player2", [{2, :hearts}, {3, :diamonds}], 2}
          ],
          [{5, :diamonds}, {6, :clubs}, {7, :spades}, {8, :hearts}, {9, :diamonds}]
        )

      # Player1 has a higher hand (pair of 10s) while Player2 has high card 9
      # Since Player1 has rank 1 but has a stronger hand than Player2 with rank 2,
      # the ordering is incorrect

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :alarm
      assert is_map(result.player_hands)
      assert map_size(result.player_hands) == 2
    end

    test "correctly evaluates different hand strengths" do
      state =
        build_state(
          [
            {"player1", [{2, :hearts}, {3, :hearts}], 1},
            {"player2", [{7, :spades}, {8, :spades}], 2},
            {"player3", [{10, :diamonds}, {10, :clubs}], 3}
          ],
          [{4, :hearts}, {5, :hearts}, {6, :hearts}, {9, :spades}, {2, :diamonds}]
        )

      # Player1 has a flush (hearts), Player2 has a straight (4-8), Player3 has a pair of 10s
      # Flush > Straight > Pair, but the rank chips are 1, 2, 3 respectively
      # So the ordering is incorrect

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :alarm
      assert is_map(result.player_hands)
      assert map_size(result.player_hands) == 3

      # Verify each player's hand is properly evaluated
      player1_hand = result.player_hands["player1"]
      player2_hand = result.player_hands["player2"]
      player3_hand = result.player_hands["player3"]

      # Player 1 has a straight flush
      assert elem(player1_hand, 0) == :straight_flush
      # Player 2 has a straight
      assert elem(player2_hand, 0) == :straight
      # Player 3 has a pair
      assert elem(player3_hand, 0) == :pair
    end

    test "correctly handles tie situations based on rank chips" do
      state =
        build_state(
          [
            {"player1", [{10, :hearts}, {10, :diamonds}], 1},
            {"player2", [{10, :spades}, {10, :clubs}], 2}
          ],
          [{2, :hearts}, {3, :diamonds}, {5, :spades}, {7, :clubs}, {9, :hearts}]
        )

      # Both players have a pair of 10s with identical kickers (9, 7, 5)
      # Since their hands are tied but Player1 has rank 1 and Player2 has rank 2,
      # the ordering is considered correct (lower rank = weaker or equal hand)

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :vault
      assert is_map(result.player_hands)
      assert map_size(result.player_hands) == 2

      # Verify both players have the same hand type
      player1_hand = result.player_hands["player1"]
      player2_hand = result.player_hands["player2"]

      assert elem(player1_hand, 0) == :pair
      assert elem(player2_hand, 0) == :pair
    end

    test "correct rank kickers in tie scenarios" do
      state =
        build_state(
          [
            {"player1", [{14, :hearts}, {10, :diamonds}], 2},
            {"player2", [{12, :spades}, {10, :clubs}], 1}
          ],
          [{2, :hearts}, {3, :diamonds}, {5, :spades}, {7, :clubs}, {10, :hearts}]
        )

      # Both players have Two Pair (10)
      # Player 1 has Ace high
      # Player Two has Queen high

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :vault

      # Verify both players have the same hand type
      player1_hand = result.player_hands["player1"]
      player2_hand = result.player_hands["player2"]

      assert elem(player1_hand, 0) == :pair
      assert elem(player2_hand, 0) == :pair
    end

    test "handles cases of a 'true tie' where community cards are the best hand" do
      # test variations of rank chip distributions
      # regardles of what order the chips are in, it should be a vault
      # because its a true tie (since comnmunity hand is best hand)
      chip_variations = [
        [1, 2, 3],
        [3, 2, 1],
        [1, 3, 2]
      ]

      for [p1, p2, p3] <- chip_variations do
        state =
          build_state(
            [
              {"player1", [{2, :hearts}, {3, :hearts}], p1},
              {"player2", [{7, :spades}, {8, :spades}], p2},
              {"player3", [{10, :diamonds}, {10, :clubs}], p3}
            ],
            # community cards is a royal flush
            [{:A, :hearts}, {:K, :hearts}, {:Q, :hearts}, {:J, :hearts}, {10, :hearts}]
          )

        result = Evaluator.evaluate_round(state)

        assert result.round_result == :vault
      end
    end
  end

  describe "game_over?/1" do
    test "returns true when 3 vaults are reached" do
      state = %State{vaults: 3, alarms: 0}
      assert Evaluator.game_over?(state) == true
    end

    test "returns true when 3 alarms are reached" do
      state = %State{vaults: 0, alarms: 3}
      assert Evaluator.game_over?(state) == true
    end

    test "returns false when neither 3 vaults nor 3 alarms are reached" do
      state = %State{vaults: 2, alarms: 2}
      assert Evaluator.game_over?(state) == false
    end
  end

  describe "game_result/1" do
    test "returns :win when 3 vaults are reached" do
      state = %State{vaults: 3, alarms: 0}
      assert Evaluator.game_result(state) == :win
    end

    test "returns :lose when 3 alarms are reached" do
      state = %State{vaults: 0, alarms: 3}
      assert Evaluator.game_result(state) == :lose
    end

    test "returns :in_progress when the game is not over" do
      state = %State{vaults: 2, alarms: 2}
      assert Evaluator.game_result(state) == :in_progress
    end
  end
end
