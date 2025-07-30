defmodule GangWeb.LobbyLiveTest do
  use GangWeb.ConnCase

  import Phoenix.LiveViewTest
  alias Gang.Game.Player
  alias Gang.Games

  test "shows lobby with title", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "The Gang"
    assert html =~ "Enter Your Name"
  end

  test "prompt for player name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    html =
      view
      |> form("#player-name-form", %{player_name: "Luke Skywalker"})
      |> render_submit()

    assert html =~ "Your Player Name: Luke Skywalker"
  end

  describe "close game functionality" do
    test "shows close button only for game owner", %{conn: conn} do
      owner = Player.new("Owner", "owner-id")
      other_player = Player.new("Other", "other-id")
      
      # Create a game with owner
      {:ok, code} = Games.create_game(owner.id)

      # Connect as owner
      {:ok, _owner_view, owner_html} = live(conn, ~p"/?player_name=#{owner.name}&player_id=#{owner.id}")
      
      # Owner should see close button
      assert owner_html =~ "Close"
      assert owner_html =~ "phx-click=\"close_game\""
      assert owner_html =~ "phx-value-game_code=\"#{code}\""

      # Connect as different player
      {:ok, _other_view, other_html} = live(conn, ~p"/?player_name=#{other_player.name}&player_id=#{other_player.id}")
      
      # Other player should not see close button for games they don't own
      refute other_html =~ "phx-value-game_code=\"#{code}\""
    end

    test "owner can successfully close their game", %{conn: conn} do
      owner = Player.new("Owner", "owner-id")
      {:ok, code} = Games.create_game(owner.id)

      {:ok, view, _html} = live(conn, ~p"/?player_name=#{owner.name}&player_id=#{owner.id}")

      # Close the game
      html = render_click(view, "close_game", %{"game_code" => code})

      # Should show success message
      assert html =~ "Game #{code} has been closed"
      
      # Allow process termination to complete
      Process.sleep(5)
      
      # Game should no longer exist
      assert false == Games.game_exists?(code)
    end

    test "non-owner cannot close game", %{conn: conn} do
      owner = Player.new("Owner", "owner-id")
      other_player = Player.new("Other", "other-id")
      {:ok, code} = Games.create_game(owner.id)

      {:ok, view, _html} = live(conn, ~p"/?player_name=#{other_player.name}&player_id=#{other_player.id}")

      # Try to close the game as non-owner
      html = render_click(view, "close_game", %{"game_code" => code})

      # Should show error message
      assert html =~ "Only the game owner can close this game"
      
      # Game should still exist
      assert {:ok, _state} = Games.get_game(code)
    end

    test "handles closing non-existent game gracefully", %{conn: conn} do
      player = Player.new("Player", "player-id")
      
      {:ok, view, _html} = live(conn, ~p"/?player_name=#{player.name}&player_id=#{player.id}")

      # Try to close non-existent game
      html = render_click(view, "close_game", %{"game_code" => "FAKE"})

      # Should show error message
      assert html =~ "Game not found"
    end

    test "close button is not shown for games without owner", %{conn: conn} do
      player = Player.new("Player", "player-id")
      {:ok, code} = Games.create_game(nil)  # No owner

      {:ok, _view, html} = live(conn, ~p"/?player_name=#{player.name}&player_id=#{player.id}")

      # Should not show close button since no one owns the game
      refute html =~ "phx-value-game_code=\"#{code}\""
    end
  end
end
