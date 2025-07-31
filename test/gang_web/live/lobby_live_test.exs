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

    assert html =~ "Luke Skywalker"
  end

  describe "edit mode functionality" do
    test "shows edit button when name is set", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?player_name=Alice")
      
      html = render(view)
      assert html =~ "Alice"
      assert html =~ "Edit name"
      refute html =~ "Enter Your Name"
    end

    test "clicking edit button switches to edit mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?player_name=Alice")
      
      html = render_click(view, "edit_name")
      
      assert html =~ "Enter Your Name"
      assert html =~ "Save"
      assert html =~ "Cancel"
    end

    test "cancel edit returns to display mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?player_name=Alice")
      
      # Enter edit mode
      render_click(view, "edit_name")
      
      # Cancel edit
      html = render_click(view, "cancel_edit")
      
      assert html =~ "Alice"
      assert html =~ "Edit name"
      refute html =~ "Enter Your Name"
    end

    test "update_preview changes avatar in real-time", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?player_name=Alice")
      
      # Enter edit mode
      initial_html = render_click(view, "edit_name")
      assert initial_html =~ "seed=Alice"
      
      # Update preview should change the avatar seed
      updated_html = render_change(view, "update_preview", %{player_name: "Bob"})
      
      assert updated_html =~ "seed=Bob"
      
      # The main avatar in edit mode should now use Bob's seed
      # (there might still be Alice's seed in the games table, so we check for the edit mode avatar specifically)
      assert updated_html =~ "Your avatar"
    end

    test "save exits edit mode and updates name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?player_name=Alice")
      
      # Enter edit mode and submit new name
      render_click(view, "edit_name")
      html = 
        view
        |> form("#player-name-form", %{player_name: "Bob"})
        |> render_submit()
      
      # Should be back in display mode with new name
      assert html =~ "Bob"
      assert html =~ "Edit name"
      refute html =~ "Enter Your Name"
    end
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
      # No owner
      {:ok, code} = Games.create_game(nil)

      {:ok, _view, html} = live(conn, ~p"/?player_name=#{player.name}&player_id=#{player.id}")

      # Should not show close button since no one owns the game
      refute html =~ "phx-value-game_code=\"#{code}\""
    end
  end
end
