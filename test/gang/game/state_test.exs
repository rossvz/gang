defmodule Gang.Game.StateTest do
  use ExUnit.Case

  alias Gang.Game.Card
  alias Gang.Game.Player
  alias Gang.Game.RankChip
  alias Gang.Game.State

  describe "new/1" do
    test "creates a new state with a game code" do
      state = State.new("TEST")

      assert state.code == "TEST"
      assert state.owner_id == nil
      assert state.players == []
      assert state.status == :waiting
      assert state.current_round == :preflop
      assert state.vaults == 0
      assert state.alarms == 0
      assert state.community_cards == [nil, nil, nil, nil, nil]
      assert state.all_rank_chips_claimed? == false
    end
  end

  describe "new/2" do
    test "creates a new state with a game code and owner_id" do
      owner_id = "test-owner-123"
      state = State.new("TEST", owner_id)

      assert state.code == "TEST"
      assert state.owner_id == owner_id
      assert state.players == []
      assert state.status == :waiting
    end

    test "creates a new state with nil owner_id when explicitly passed" do
      state = State.new("TEST", nil)

      assert state.code == "TEST"
      assert state.owner_id == nil
      assert state.players == []
      assert state.status == :waiting
    end
  end

  describe "add_player/2" do
    test "adds a player to the game" do
      state = State.new("TEST")
      player = Player.new("Alice")

      updated_state = State.add_player(state, player)

      assert length(updated_state.players) == 1
      assert hd(updated_state.players).name == "Alice"
    end

    test "adds multiple players to the game" do
      state = State.new("TEST")
      player1 = Player.new("Alice")
      player2 = Player.new("Bob")

      state = State.add_player(state, player1)
      state = State.add_player(state, player2)

      assert length(state.players) == 2
      assert Enum.at(state.players, 0).name == "Alice"
      assert Enum.at(state.players, 1).name == "Bob"
    end

    test "doesn't add players if the game is already in progress" do
      state = %State{status: :playing}
      player = Player.new("Alice")

      updated_state = State.add_player(state, player)

      assert updated_state.players == []
    end
  end

  describe "remove_player/2" do
    test "removes a player from the game" do
      state = State.new("TEST")
      player1 = Player.new("Alice")

      state = State.add_player(state, player1)
      updated_state = State.remove_player(state, player1.id)

      assert updated_state.players == []
    end

    test "removes the correct player when multiple players exist" do
      state = State.new("TEST")
      player1 = Player.new("Alice")
      player2 = Player.new("Bob")
      player3 = Player.new("Charlie")

      state =
        state
        |> State.add_player(player1)
        |> State.add_player(player2)
        |> State.add_player(player3)

      updated_state = State.remove_player(state, player2.id)

      assert length(updated_state.players) == 2
      assert Enum.map(updated_state.players, & &1.name) == ["Alice", "Charlie"]
    end
  end

  describe "update_player_connection/3" do
    test "updates a player's connection status to connected" do
      state = State.new("TEST")
      player = Player.new("Alice")
      state = State.add_player(state, player)

      updated_state = State.update_player_connection(state, player.id, true)
      updated_player = Enum.find(updated_state.players, &(&1.name == "Alice"))

      assert updated_player.connected == true
    end

    test "updates a player's connection status to disconnected" do
      state = State.new("TEST")
      player = Player.new("Alice")
      state = State.add_player(state, %{player | connected: true})

      assert length(state.players) == 1

      updated_state = State.update_player_connection(state, player.id, false)
      updated_player = Enum.find(updated_state.players, &(&1.name == "Alice"))

      assert updated_player.connected == false
    end
  end

  describe "update_player_info/2" do
    test "updates a player's name and avatar" do
      state = State.new("TEST")
      player = Player.new("Alice", "test-id")
      state = State.add_player(state, player)

      # Create updated player with new name
      updated_player_data = Player.new("Bob", "test-id")
      updated_state = State.update_player_info(state, updated_player_data)

      updated_player = Enum.find(updated_state.players, &(&1.id == "test-id"))

      assert updated_player.name == "Bob"
      assert updated_player.id == "test-id"
      assert String.contains?(updated_player.avatar, "seed=Bob")
      refute String.contains?(updated_player.avatar, "seed=Alice")
    end

    test "only updates the matching player by ID" do
      state = State.new("TEST")
      player1 = Player.new("Alice", "id-1")
      player2 = Player.new("Bob", "id-2")

      state =
        state
        |> State.add_player(player1)
        |> State.add_player(player2)

      # Update only player1's info
      updated_player_data = Player.new("Charlie", "id-1")
      updated_state = State.update_player_info(state, updated_player_data)

      updated_player1 = Enum.find(updated_state.players, &(&1.id == "id-1"))
      unchanged_player2 = Enum.find(updated_state.players, &(&1.id == "id-2"))

      assert updated_player1.name == "Charlie"
      assert String.contains?(updated_player1.avatar, "seed=Charlie")

      # Player 2 should remain unchanged
      assert unchanged_player2.name == "Bob"
      assert String.contains?(unchanged_player2.avatar, "seed=Bob")
    end

    test "updates last_active timestamp" do
      state = State.new("TEST")
      player = Player.new("Alice", "test-id")
      state = State.add_player(state, player)
      original_last_active = state.last_active

      # Ensure time difference
      Process.sleep(1)

      updated_player_data = Player.new("Bob", "test-id")
      updated_state = State.update_player_info(state, updated_player_data)

      assert DateTime.after?(updated_state.last_active, original_last_active)
    end

    test "handles non-existent player ID gracefully" do
      state = State.new("TEST")
      player = Player.new("Alice", "existing-id")
      state = State.add_player(state, player)

      # Try to update a player that doesn't exist
      non_existent_player = Player.new("Bob", "non-existent-id")
      updated_state = State.update_player_info(state, non_existent_player)

      # State should remain unchanged except for last_active
      assert length(updated_state.players) == 1
      existing_player = hd(updated_state.players)
      assert existing_player.name == "Alice"
      assert existing_player.id == "existing-id"
    end
  end

  describe "start_game/1" do
    test "transitions from waiting to playing state" do
      state = State.new("TEST")
      player1 = Player.new("Alice")
      player2 = Player.new("Bob")
      player3 = Player.new("Charlie")

      state =
        state
        |> State.add_player(player1)
        |> State.add_player(player2)
        |> State.add_player(player3)

      updated_state = State.start_game(state)

      assert updated_state.status == :playing
      assert updated_state.current_round == :preflop
      assert updated_state.current_phase == :rank_chip_selection
      assert updated_state.current_round_color == :white
      assert updated_state.game_created != nil

      # Each player should have 2 cards
      for player <- updated_state.players do
        assert length(player.cards) == 2
      end
    end

    test "does nothing if the game is already in progress" do
      state = %State{status: :playing, current_round: :flop}
      updated_state = State.start_game(state)

      assert updated_state.status == :playing
      assert updated_state.current_round == :flop
    end

    test "does nothing if there are fewer than 3 players" do
      state = State.new("TEST")
      player1 = Player.new("Alice")
      player2 = Player.new("Bob")
      state = state |> State.add_player(player1) |> State.add_player(player2)

      updated_state = State.start_game(state)

      assert updated_state.status == :waiting
    end
  end

  describe "claim_chip/4" do
    test "allows a player to claim a rank chip" do
      player = Player.new("Alice")

      state = %State{
        status: :playing,
        current_phase: :rank_chip_selection,
        current_round_color: :white,
        players: [player]
      }

      updated_state = State.claim_chip(state, player.id, 1, :white)
      alice = Enum.find(updated_state.players, &(&1.name == "Alice"))

      assert length(alice.rank_chips) == 1
      assert hd(alice.rank_chips).rank == 1
      assert hd(alice.rank_chips).color == :white
    end

    test "allows a player to take a chip from another player" do
      alice = Player.new("Alice")
      bob = Player.new("Bob")

      state = %State{
        status: :playing,
        current_phase: :rank_chip_selection,
        current_round_color: :white,
        players: [alice, bob]
      }

      updated_state = State.claim_chip(state, bob.id, 1, :white)
      alice = Enum.find(updated_state.players, &(&1.name == "Alice"))
      bob = Enum.find(updated_state.players, &(&1.name == "Bob"))

      assert alice.rank_chips == []
      assert length(bob.rank_chips) == 1
      assert hd(bob.rank_chips).rank == 1
      assert hd(bob.rank_chips).color == :white
    end

    test "replaces existing chip of the same color" do
      alice = Player.new("Alice")

      # alice already has a Yellow "2"
      state = %State{
        status: :playing,
        current_phase: :rank_chip_selection,
        current_round_color: :yellow,
        players: [
          %{
            alice
            | rank_chips: [
                %RankChip{rank: 1, color: :white},
                %RankChip{rank: 2, color: :yellow}
              ]
          }
        ]
      }

      updated_state = State.claim_chip(state, alice.id, 3, :yellow)
      alice = Enum.find(updated_state.players, &(&1.name == "Alice"))

      assert length(alice.rank_chips) == 2
      assert Enum.find(alice.rank_chips, &(&1.color == :white)).rank == 1
      assert Enum.find(alice.rank_chips, &(&1.color == :yellow)).rank == 3
    end

    test "updates all_rank_chips_claimed? when all players have chips" do
      alice = Player.new("Alice")
      bob = Player.new("Bob")
      charlie = Player.new("Charlie")

      state = %State{
        status: :playing,
        current_phase: :rank_chip_selection,
        current_round_color: :white,
        all_rank_chips_claimed?: false,
        players: [alice, bob, charlie]
      }

      # each player takes a chip
      state =
        state
        |> State.claim_chip(alice.id, 1, :white)
        |> State.claim_chip(bob.id, 2, :white)
        |> State.claim_chip(charlie.id, 3, :white)

      assert state.all_rank_chips_claimed? == true
    end
  end

  describe "return_chip/4" do
    test "allows a player to return a rank chip" do
      alice = Player.new("Alice")

      state = %State{
        status: :playing,
        current_phase: :rank_chip_selection,
        current_round_color: :white,
        players: [alice]
      }

      updated_state =
        state
        |> State.claim_chip(alice.id, 1, :white)
        |> State.return_chip(alice.id, 1, :white)

      alice = Enum.find(updated_state.players, &(&1.name == "Alice"))

      assert alice.rank_chips == []
    end
  end

  describe "advance_round/1" do
    test "advances to the next round" do
      state = %State{
        status: :playing,
        current_round: :preflop,
        current_round_color: :white,
        deck: Enum.map(1..10, fn n -> %Card{rank: n, suit: :hearts} end)
      }

      updated_state = State.advance_round(state)

      assert updated_state.current_round == :flop
      assert updated_state.current_round_color == :yellow
      assert updated_state.all_rank_chips_claimed? == false

      # Should have dealt 3 community cards for flop
      assert length(Enum.filter(updated_state.community_cards, &(&1 != nil))) == 3
    end

    test "deals one card for the turn (round 3)" do
      state = %State{
        status: :playing,
        current_round: :flop,
        deck: Enum.map(1..10, fn n -> %Card{rank: n, suit: :hearts} end),
        community_cards: [
          %Card{rank: 11, suit: :hearts},
          %Card{rank: 12, suit: :hearts},
          %Card{rank: 13, suit: :hearts},
          nil,
          nil
        ]
      }

      updated_state = State.advance_round(state)

      assert updated_state.current_round == :turn
      assert updated_state.current_round_color == :orange

      # Should have dealt 1 more card for turn
      assert length(Enum.filter(updated_state.community_cards, &(&1 != nil))) == 4
    end

    test "deals one card for the river (round 4)" do
      state = %State{
        status: :playing,
        current_round: :turn,
        deck: Enum.map(1..10, fn n -> %Card{rank: n, suit: :hearts} end),
        community_cards: [
          %Card{rank: 11, suit: :hearts},
          %Card{rank: 12, suit: :hearts},
          %Card{rank: 13, suit: :hearts},
          %Card{rank: 1, suit: :hearts},
          nil
        ]
      }

      updated_state = State.advance_round(state)

      assert updated_state.current_round == :river
      assert updated_state.current_round_color == :red

      # Should have dealt all 5 community cards
      assert length(Enum.filter(updated_state.community_cards, &(&1 != nil))) == 5
    end

    test "does nothing if not in playing state" do
      state = %State{status: :waiting, current_round: :preflop}

      updated_state = State.advance_round(state)

      assert updated_state.current_round == :preflop
    end
  end

  describe "start_new_hand/1" do
    test "resets to preflop when starting new hand after evaluation" do
      # Create state at evaluation phase with some players
      alice = Player.new("Alice")
      bob = Player.new("Bob")

      state = %State{
        status: :playing,
        current_round: :evaluation,
        current_phase: :rank_chip_selection,
        players: [alice, bob]
      }

      # Call start_new_hand which is what Game module calls after evaluation
      updated_state = State.start_new_hand(state)

      # Should reset to preflop
      assert updated_state.current_round == :preflop
      assert updated_state.current_round_color == :white
      assert updated_state.current_phase == :rank_chip_selection

      # Players should have cards
      assert Enum.all?(updated_state.players, fn p -> length(p.cards) == 2 end)

      # Community cards should be reset
      assert updated_state.community_cards == [nil, nil, nil, nil, nil]
    end
  end

  describe "reset_game/1" do
    test "resets completed game while keeping players" do
      # Create a completed game state with players, cards, and score
      alice = %Player{
        id: "alice-id",
        name: "Alice",
        cards: [%Card{rank: 2, suit: :hearts}, %Card{rank: 3, suit: :clubs}],
        rank_chips: [%RankChip{rank: 1, color: :red}]
      }

      bob = %Player{
        id: "bob-id",
        name: "Bob",
        cards: [%Card{rank: 10, suit: :hearts}, %Card{rank: :jack, suit: :clubs}],
        rank_chips: [%RankChip{rank: 2, color: :red}]
      }

      completed_state = %State{
        code: "TEST",
        status: :completed,
        players: [alice, bob],
        current_round: :evaluation,
        current_phase: :dealing,
        current_round_color: :red,
        vaults: 3,
        alarms: 1,
        last_round_result: :vault,
        community_cards: [
          %Card{rank: 4, suit: :hearts},
          %Card{rank: 5, suit: :hearts},
          %Card{rank: 6, suit: :hearts},
          %Card{rank: 7, suit: :hearts},
          %Card{rank: 8, suit: :hearts}
        ],
        all_rank_chips_claimed?: true,
        evaluated_hands: %{"Alice" => {:pair, [2]}, "Bob" => {:high_card, [:jack]}}
      }

      # Reset the game
      reset_state = State.reset_game(completed_state)

      # Should reset game state to initial values
      assert reset_state.status == :waiting
      assert reset_state.current_round == :preflop
      assert reset_state.current_phase == :rank_chip_selection
      assert reset_state.current_round_color == :white
      assert reset_state.vaults == 0
      assert reset_state.alarms == 0
      assert reset_state.last_round_result == nil
      assert reset_state.community_cards == [nil, nil, nil, nil, nil]
      assert reset_state.all_rank_chips_claimed? == false
      assert reset_state.deck == []
      assert reset_state.evaluated_hands == nil

      # Should keep the same players but clear their cards and chips
      assert length(reset_state.players) == 2
      assert Enum.at(reset_state.players, 0).name == "Alice"
      assert Enum.at(reset_state.players, 0).id == "alice-id"
      assert Enum.at(reset_state.players, 0).cards == []
      assert Enum.at(reset_state.players, 0).rank_chips == []

      assert Enum.at(reset_state.players, 1).name == "Bob"
      assert Enum.at(reset_state.players, 1).id == "bob-id"
      assert Enum.at(reset_state.players, 1).cards == []
      assert Enum.at(reset_state.players, 1).rank_chips == []

      # Should preserve the game code
      assert reset_state.code == "TEST"
    end

    test "doesn't reset if game is not completed" do
      # Create a playing game state
      playing_state = %State{
        code: "TEST",
        status: :playing,
        vaults: 2,
        alarms: 1
      }

      # Try to reset
      result_state = State.reset_game(playing_state)

      # Should be unchanged
      assert result_state == playing_state
      assert result_state.status == :playing
      assert result_state.vaults == 2
      assert result_state.alarms == 1
    end
  end
end
