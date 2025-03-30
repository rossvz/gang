defmodule Gang.Game.EvaluatorTest do
  use ExUnit.Case

  alias Gang.Game.Card
  alias Gang.Game.Evaluator
  alias Gang.Game.Player
  alias Gang.Game.RankChip
  alias Gang.Game.State

  describe "evaluate_round/1" do
    test "returns :vault when player hands match rank chip order" do
      # Create a game state in round_end
      state = %State{
        current_round: :river,
        vaults: 0,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
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
        ]
      }

      # Player1 has a lower hand (high card 9) while Player2 has a pair of 10s
      # Since Player1 has rank 1 and Player2 has rank 2, the ordering is correct

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :vault
      assert is_map(result.player_hands)
      assert map_size(result.player_hands) == 2
    end

    test "returns :alarm when player hands do not match rank chip order" do
      # Create a game state in round_end
      state = %State{
        current_round: :river,
        vaults: 0,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            cards: [
              %Card{rank: 10, suit: :spades},
              %Card{rank: 10, suit: :hearts}
            ],
            rank_chips: [
              %RankChip{rank: 1, color: :red}
            ]
          },
          %Player{
            name: "player2",
            cards: [
              %Card{rank: 2, suit: :hearts},
              %Card{rank: 3, suit: :diamonds}
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
        ]
      }

      # Player1 has a higher hand (pair of 10s) while Player2 has high card 9
      # Since Player1 has rank 1 but has a stronger hand than Player2 with rank 2,
      # the ordering is incorrect

      result = Evaluator.evaluate_round(state)

      assert result.round_result == :alarm
      assert is_map(result.player_hands)
      assert map_size(result.player_hands) == 2
    end

    test "correctly evaluates different hand strengths" do
      # Create a game state in round_end with three players
      state = %State{
        current_round: :river,
        vaults: 0,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            cards: [
              %Card{rank: 2, suit: :hearts},
              %Card{rank: 3, suit: :hearts}
            ],
            rank_chips: [
              %RankChip{rank: 1, color: :red}
            ]
          },
          %Player{
            name: "player2",
            cards: [
              %Card{rank: 7, suit: :spades},
              %Card{rank: 8, suit: :spades}
            ],
            rank_chips: [
              %RankChip{rank: 2, color: :red}
            ]
          },
          %Player{
            name: "player3",
            cards: [
              %Card{rank: 10, suit: :diamonds},
              %Card{rank: 10, suit: :clubs}
            ],
            rank_chips: [
              %RankChip{rank: 3, color: :red}
            ]
          }
        ],
        community_cards: [
          %Card{rank: 4, suit: :hearts},
          %Card{rank: 5, suit: :hearts},
          %Card{rank: 6, suit: :hearts},
          %Card{rank: 9, suit: :spades},
          %Card{rank: 2, suit: :diamonds}
        ]
      }

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
      # Create a game state in round_end with two players with identical hand strength
      state = %State{
        current_round: :river,
        vaults: 0,
        alarms: 0,
        players: [
          %Player{
            name: "player1",
            cards: [
              %Card{rank: 10, suit: :hearts},
              %Card{rank: 10, suit: :diamonds}
            ],
            rank_chips: [
              %RankChip{rank: 1, color: :red}
            ]
          },
          %Player{
            name: "player2",
            cards: [
              %Card{rank: 10, suit: :spades},
              %Card{rank: 10, suit: :clubs}
            ],
            rank_chips: [
              %RankChip{rank: 2, color: :red}
            ]
          }
        ],
        community_cards: [
          %Card{rank: 2, suit: :hearts},
          %Card{rank: 3, suit: :diamonds},
          %Card{rank: 5, suit: :spades},
          %Card{rank: 7, suit: :clubs},
          %Card{rank: 9, suit: :hearts}
        ]
      }

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
        state = %State{
          current_round: :river,
          vaults: 0,
          alarms: 0,
          players: [
            %Player{
              name: "player1",
              cards: [
                %Card{rank: 2, suit: :hearts},
                %Card{rank: 3, suit: :hearts}
              ],
              rank_chips: [
                %RankChip{rank: p1, color: :red}
              ]
            },
            %Player{
              name: "player2",
              cards: [
                %Card{rank: 7, suit: :spades},
                %Card{rank: 8, suit: :spades}
              ],
              rank_chips: [
                %RankChip{rank: p2, color: :red}
              ]
            },
            %Player{
              name: "player3",
              cards: [
                %Card{rank: 10, suit: :diamonds},
                %Card{rank: 10, suit: :clubs}
              ],
              rank_chips: [
                %RankChip{rank: p3, color: :red}
              ]
            }
          ],

          # communinty cards is a royal flush
          community_cards: [
            %Card{rank: 14, suit: :hearts},
            %Card{rank: 13, suit: :hearts},
            %Card{rank: 12, suit: :hearts},
            %Card{rank: 11, suit: :hearts},
            %Card{rank: 10, suit: :hearts}
          ]
        }

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
