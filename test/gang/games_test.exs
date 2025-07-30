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
