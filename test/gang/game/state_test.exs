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
      assert state.players == []
      assert state.status == :waiting
      assert state.current_round == :preflop
      assert state.vaults == 0
      assert state.alarms == 0
      assert state.community_cards == [nil, nil, nil, nil, nil]
      assert state.all_rank_chips_claimed? == false
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
      assert updated_state.game_start != nil

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
end
