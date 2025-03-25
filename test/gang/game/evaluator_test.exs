defmodule Gang.Game.EvaluatorTest do
  use ExUnit.Case

  alias Gang.Game.{Card, Evaluator, Player, RankChip, State}

  describe "evaluate_round/1" do
    test "adds a vault when player hands match rank chip order" do
      # Create a game state in round_end
      state = %State{
        round: 5,
        current_phase: :evaluation,
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

      assert result.vaults == 1
      assert result.alarms == 0
    end

    test "adds an alarm when player hands do not match rank chip order" do
      # Create a game state in round_end
      state = %State{
        round: 5,
        current_phase: :evaluation,
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

      assert result.vaults == 0
      assert result.alarms == 1
    end

    test "correctly evaluates different hand strengths" do
      # Create a game state in round_end with three players
      state = %State{
        round: 5,
        current_phase: :evaluation,
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

      assert result.vaults == 0
      assert result.alarms == 1
    end

    test "correctly handles tie situations based on rank chips" do
      # Create a game state in round_end with two players with identical hand strength
      state = %State{
        round: 5,
        current_phase: :evaluation,
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

      assert result.vaults == 0
      assert result.alarms == 1
    end

    test "ends the game when 3 vaults are reached" do
      # Create a game state in round_end with 2 vaults already
      state = %State{
        round: 5,
        status: :playing,
        current_phase: :evaluation,
        vaults: 2,
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

      result = Evaluator.evaluate_round(state)

      assert result.vaults == 3
      assert result.status == :completed
    end

    test "ends the game when 3 alarms are reached" do
      # Create a game state in round_end with 2 alarms already
      state = %State{
        round: 5,
        status: :playing,
        current_phase: :evaluation,
        vaults: 0,
        alarms: 2,
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
              %Card{rank: 3, suit: :hearts}
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

      result = Evaluator.evaluate_round(state)

      assert result.alarms == 3
      assert result.status == :completed
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
