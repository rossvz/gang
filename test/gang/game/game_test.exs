defmodule Gang.GameTest do
  use ExUnit.Case, async: true

  alias Gang.Game
  alias Gang.Game.{Card, Player, RankChip, State}

  # Mock the broadcast function to prevent test interference
  defp broadcast_update(_), do: :ok

  # Helper function to create a test process with a known state
  defp create_test_game(state) do
    {:ok, game_pid} = start_supervised({Game, "TEST"})
    :sys.replace_state(game_pid, fn _ -> state end)
    game_pid
  end

  describe "advance_round/1" do
    test "evaluates hands at round 4" do
      # Create a game state at round 4 with basic player setup
      state = %State{
        code: "TEST",
        status: :playing,
        round: 4,
        current_phase: :rank_chip_selection,
        vaults: 0,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            id: "p1",
            cards: [
              %Card{rank: 2, suit: :hearts},
              %Card{rank: 3, suit: :diamonds}
            ],
            rank_chips: [
              %RankChip{rank: 1, color: :red}
            ]
          },
          %Player{
            name: "player2",
            id: "p2",
            cards: [
              %Card{rank: 10, suit: :spades},
              %Card{rank: 10, suit: :hearts}
            ],
            rank_chips: [
              %RankChip{rank: 2, color: :red}
            ]
          }
        ],
        community_cards: [
          %Card{rank: 5, suit: :diamonds},
          %Card{rank: 6, suit: :clubs},
          %Card{rank: 7, suit: :spades},
          %Card{rank: 8, suit: :hearts},
          %Card{rank: 9, suit: :diamonds}
        ],
        all_rank_chips_claimed?: true
      }

      game_pid = create_test_game(state)
      {:ok, updated_state} = Game.advance_round(game_pid)

      # Check that the game transitioned to evaluation phase
      assert updated_state.current_phase == :evaluation
      # Check that evaluated_hands field is populated
      assert updated_state.evaluated_hands != nil
      assert map_size(updated_state.evaluated_hands) == 2
      # Round should remain 4 during evaluation phase
      assert updated_state.round == 4
    end

    test "advances from evaluation phase to next round" do
      # Create a game state in evaluation phase
      state = %State{
        code: "TEST",
        status: :playing,
        round: 4,
        current_phase: :evaluation,
        vaults: 1,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            id: "p1",
            cards: [
              %Card{rank: 2, suit: :hearts},
              %Card{rank: 3, suit: :diamonds}
            ],
            rank_chips: []
          },
          %Player{
            name: "player2",
            id: "p2",
            cards: [
              %Card{rank: 10, suit: :spades},
              %Card{rank: 10, suit: :hearts}
            ],
            rank_chips: []
          }
        ],
        community_cards: [
          %Card{rank: 5, suit: :diamonds},
          %Card{rank: 6, suit: :clubs},
          %Card{rank: 7, suit: :spades},
          %Card{rank: 8, suit: :hearts},
          %Card{rank: 9, suit: :diamonds}
        ],
        evaluated_hands: %{
          "player1" => {:high_card, [9, 8, 7, 6, 3]},
          "player2" => {:pair, [10, 10, 9, 8, 7]}
        }
      }

      game_pid = create_test_game(state)
      {:ok, updated_state} = Game.advance_round(game_pid)

      # Check that we advanced to round 5 and back to rank_chip_selection phase
      assert updated_state.round == 5
      assert updated_state.current_phase == :rank_chip_selection
      # Evaluated hands should be reset
      assert updated_state.evaluated_hands == nil
    end

    test "resets to round 1 from round 5" do
      # Create a game state at round 5
      state = %State{
        code: "TEST",
        status: :playing,
        round: 5,
        current_phase: :rank_chip_selection,
        vaults: 1,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            id: "p1",
            cards: [
              %Card{rank: 2, suit: :hearts},
              %Card{rank: 3, suit: :diamonds}
            ],
            rank_chips: []
          },
          %Player{
            name: "player2",
            id: "p2",
            cards: [
              %Card{rank: 10, suit: :spades},
              %Card{rank: 10, suit: :hearts}
            ],
            rank_chips: []
          }
        ],
        community_cards: [
          %Card{rank: 5, suit: :diamonds},
          %Card{rank: 6, suit: :clubs},
          %Card{rank: 7, suit: :spades},
          %Card{rank: 8, suit: :hearts},
          %Card{rank: 9, suit: :diamonds}
        ]
      }

      game_pid = create_test_game(state)
      {:ok, updated_state} = Game.advance_round(game_pid)

      # Check that we reset to round 1
      assert updated_state.round == 1
      assert updated_state.current_phase == :rank_chip_selection
      assert updated_state.current_round_color == :white
      # Community cards should be reset
      assert Enum.all?(updated_state.community_cards, &is_nil/1)
      # Players should have new cards
      assert length(hd(updated_state.players).cards) == 2
      # Players should have no rank chips
      assert Enum.all?(updated_state.players, fn p -> p.rank_chips == [] end)
    end

    test "normal round advancement: round 1 to 2 with community cards" do
      # Create a game state at round 1
      state = %State{
        code: "TEST",
        status: :playing,
        round: 1,
        current_phase: :rank_chip_selection,
        vaults: 0,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            id: "p1",
            cards: [
              %Card{rank: 2, suit: :hearts},
              %Card{rank: 3, suit: :diamonds}
            ],
            rank_chips: [%RankChip{rank: 1, color: :white}]
          },
          %Player{
            name: "player2",
            id: "p2",
            cards: [
              %Card{rank: 10, suit: :spades},
              %Card{rank: 10, suit: :hearts}
            ],
            rank_chips: [%RankChip{rank: 2, color: :white}]
          }
        ],
        community_cards: [nil, nil, nil, nil, nil],
        all_rank_chips_claimed?: true,
        deck: Enum.map(1..10, fn n -> %Gang.Game.Card{rank: n, suit: :clubs} end)
      }

      game_pid = create_test_game(state)
      {:ok, updated_state} = Game.advance_round(game_pid)

      # Check that we advanced to round 2
      assert updated_state.round == 2
      assert updated_state.current_phase == :rank_chip_selection
      assert updated_state.current_round_color == :yellow

      # Should have dealt 3 community cards for flop
      assert length(Enum.filter(updated_state.community_cards, &(&1 != nil))) == 3
      # Rank chips from previous round should be preserved
      assert length(hd(updated_state.players).rank_chips) == 1
    end

    test "never advances beyond round 5" do
      # Create a game state at hypothetical round 6 (should never happen but testing anyway)
      state = %State{
        code: "TEST",
        status: :playing,
        # Invalid round number
        round: 6,
        current_phase: :rank_chip_selection,
        players: [
          %Player{name: "player1", id: "p1", cards: []},
          %Player{name: "player2", id: "p2", cards: []}
        ]
      }

      game_pid = create_test_game(state)
      {:ok, updated_state} = Game.advance_round(game_pid)

      # Round should not advance further, should stay at 6 (or reset to 1)
      assert updated_state.round == 6 || updated_state.round == 1
      # Should not cause any crashes
      assert updated_state.status == :playing
    end
  end
end
