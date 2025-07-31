defmodule Gang.GamesTest do
  use ExUnit.Case, async: true

  alias Gang.Game.Player
  alias Gang.Games

  test "return_rank_chip/2 returns error when player has no chip" do
    {:ok, code} = Games.create_game()

    player = Player.new("alice")
    {:ok, _} = Games.join_game(code, player)

    assert {:error, :chip_not_found} = Games.return_rank_chip(code, player.id)
  end

  describe "join_game/2" do
    test "adds new player to game" do
      {:ok, code} = Games.create_game()
      player = Player.new("Alice", "test-id")

      {:ok, _} = Games.join_game(code, player)
      {:ok, state} = Games.get_game(code)

      assert length(state.players) == 1
      game_player = hd(state.players)
      assert game_player.name == "Alice"
      assert game_player.id == "test-id"
    end

    test "updates existing player info when rejoining with same ID" do
      {:ok, code} = Games.create_game()
      original_player = Player.new("Alice", "test-id")

      # Join game initially
      {:ok, _} = Games.join_game(code, original_player)
      {:ok, initial_state} = Games.get_game(code)
      initial_player = hd(initial_state.players)
      assert initial_player.name == "Alice"
      assert String.contains?(initial_player.avatar, "seed=Alice")

      # Rejoin with updated name (simulating name change in lobby)
      updated_player = Player.new("Bob", "test-id")  # Same ID, different name
      {:ok, _} = Games.join_game(code, updated_player)
      {:ok, updated_state} = Games.get_game(code)

      # Should still have only one player but with updated info
      assert length(updated_state.players) == 1
      game_player = hd(updated_state.players)
      assert game_player.name == "Bob"
      assert game_player.id == "test-id"
      assert String.contains?(game_player.avatar, "seed=Bob")
      refute String.contains?(game_player.avatar, "seed=Alice")
    end

    test "marks existing player as connected when rejoining" do
      {:ok, code} = Games.create_game()
      player = Player.new("Alice", "test-id")

      # Join initially
      {:ok, _} = Games.join_game(code, player)
      
      # Simulate disconnection
      Games.update_connection(code, player.id, false)
      {:ok, state} = Games.get_game(code)
      game_player = hd(state.players)
      assert game_player.connected == false

      # Rejoin should mark as connected
      {:ok, _} = Games.join_game(code, player)
      {:ok, updated_state} = Games.get_game(code)
      updated_player = hd(updated_state.players)
      assert updated_player.connected == true
    end

    test "returns updated player data when rejoining" do
      {:ok, code} = Games.create_game()
      original_player = Player.new("Alice", "test-id")

      # Join initially
      {:ok, _} = Games.join_game(code, original_player)

      # Rejoin with updated info
      updated_player = Player.new("Charlie", "test-id")
      {:ok, returned_player} = Games.join_game(code, updated_player)

      # Should return the updated player data, not the original
      assert returned_player.name == "Charlie"
      assert returned_player.id == "test-id"
      assert String.contains?(returned_player.avatar, "seed=Charlie")
    end

    test "handles multiple players with info updates" do
      {:ok, code} = Games.create_game()
      player1 = Player.new("Alice", "id-1")
      player2 = Player.new("Bob", "id-2")

      # Both join initially
      {:ok, _} = Games.join_game(code, player1)
      {:ok, _} = Games.join_game(code, player2)
      {:ok, state} = Games.get_game(code)
      assert length(state.players) == 2

      # Player1 rejoins with updated info
      updated_player1 = Player.new("UpdatedAlice", "id-1")
      {:ok, _} = Games.join_game(code, updated_player1)
      {:ok, updated_state} = Games.get_game(code)

      # Should still have 2 players
      assert length(updated_state.players) == 2
      
      # Player1 should be updated, Player2 unchanged
      updated_p1 = Enum.find(updated_state.players, &(&1.id == "id-1"))
      unchanged_p2 = Enum.find(updated_state.players, &(&1.id == "id-2"))
      
      assert updated_p1.name == "UpdatedAlice"
      assert unchanged_p2.name == "Bob"
    end
  end

  describe "close_game/2" do
    test "allows owner to close a game" do
      owner = Player.new("owner", "owner-id")
      {:ok, code} = Games.create_game(owner.id)

      # Verify game exists
      assert {:ok, _state} = Games.get_game(code)

      # Owner should be able to close the game
      assert :ok = Games.close_game(code, owner.id)

      # Allow process termination to complete
      Process.sleep(5)

      # Game should no longer exist
      assert false == Games.game_exists?(code)
    end

    test "prevents non-owner from closing a game" do
      owner = Player.new("owner", "owner-id")
      other_player = Player.new("other", "other-id")
      {:ok, code} = Games.create_game(owner.id)

      # Other player should not be able to close the game
      assert {:error, :not_owner} = Games.close_game(code, other_player.id)

      # Game should still exist
      assert {:ok, _state} = Games.get_game(code)
    end

    test "returns error when trying to close non-existent game" do
      player = Player.new("player", "player-id")

      assert {:error, :game_not_found} = Games.close_game("FAKE", player.id)
    end

    test "handles case where owner_id is nil" do
      {:ok, code} = Games.create_game(nil)
      player = Player.new("player", "player-id")

      # Should not be able to close game with nil owner
      assert {:error, :not_owner} = Games.close_game(code, player.id)
    end
  end

  describe "create_game/1" do
    test "creates game without owner when no owner_id provided" do
      {:ok, code} = Games.create_game()
      {:ok, state} = Games.get_game(code)

      assert state.owner_id == nil
    end

    test "creates game with owner when owner_id provided" do
      owner_id = "test-owner-id"
      {:ok, code} = Games.create_game(owner_id)
      {:ok, state} = Games.get_game(code)

      assert state.owner_id == owner_id
    end
  end
end
