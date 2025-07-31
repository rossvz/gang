defmodule Gang.Game.PlayerTest do
  use ExUnit.Case, async: true

  alias Gang.Game.Player

  describe "new/2" do
    test "creates a player with name and generates avatar from name" do
      player = Player.new("Alice", "test-id")

      assert player.name == "Alice"
      assert player.id == "test-id"
      assert player.avatar == "https://api.dicebear.com/9.x/fun-emoji/svg?seed=Alice&radius=30&backgroundColor=f5bde6,c6a0f6,ed8796,ee99a0,f5a97f,eed49f,a6da95,8bd5ca,91d7e3,7dc4e4,8aadf4,b7bdf8"
      assert player.connected == true
      assert player.cards == []
      assert player.rank_chips == []
      assert %DateTime{} = player.last_activity
    end

    test "generates UUID when no ID provided" do
      player = Player.new("Bob")

      assert player.name == "Bob"
      assert is_binary(player.id)
      assert String.length(player.id) == 36  # UUID length
      assert player.avatar == "https://api.dicebear.com/9.x/fun-emoji/svg?seed=Bob&radius=30&backgroundColor=f5bde6,c6a0f6,ed8796,ee99a0,f5a97f,eed49f,a6da95,8bd5ca,91d7e3,7dc4e4,8aadf4,b7bdf8"
    end
  end

  describe "update_name/2" do
    test "updates player name and regenerates avatar" do
      player = Player.new("Alice", "test-id")
      updated_player = Player.update_name(player, "Bob")

      assert updated_player.name == "Bob"
      assert updated_player.id == "test-id"  # ID stays the same
      assert updated_player.avatar == "https://api.dicebear.com/9.x/fun-emoji/svg?seed=Bob&radius=30&backgroundColor=f5bde6,c6a0f6,ed8796,ee99a0,f5a97f,eed49f,a6da95,8bd5ca,91d7e3,7dc4e4,8aadf4,b7bdf8"
      
      # Other properties remain unchanged
      assert updated_player.connected == player.connected
      assert updated_player.cards == player.cards
      assert updated_player.rank_chips == player.rank_chips
      assert updated_player.last_activity == player.last_activity
    end

    test "different names generate different avatars" do
      player = Player.new("Alice", "test-id")
      alice_avatar = player.avatar

      updated_player = Player.update_name(player, "Charlie")
      charlie_avatar = updated_player.avatar

      assert alice_avatar != charlie_avatar
      assert String.contains?(alice_avatar, "seed=Alice")
      assert String.contains?(charlie_avatar, "seed=Charlie")
    end
  end

  describe "connect/1" do
    test "marks player as connected and updates activity" do
      player = Player.new("Alice") |> Player.disconnect()
      connected_player = Player.connect(player)

      assert connected_player.connected == true
      assert DateTime.compare(connected_player.last_activity, player.last_activity) == :gt
    end
  end

  describe "disconnect/1" do
    test "marks player as disconnected" do
      player = Player.new("Alice")
      disconnected_player = Player.disconnect(player)

      assert disconnected_player.connected == false
      assert disconnected_player.last_activity == player.last_activity
    end
  end

  describe "touch/1" do
    test "updates last activity timestamp" do
      player = Player.new("Alice")
      Process.sleep(1)  # Ensure time difference
      touched_player = Player.touch(player)

      assert DateTime.compare(touched_player.last_activity, player.last_activity) == :gt
    end
  end
end