defmodule GangWeb.GameLiveTest do
  use GangWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Gang.Game.Player
  alias Gang.Games

  describe "game completion and reset functionality" do
    test "does not show button when game is still in progress", %{conn: conn} do
      # Create a game
      {:ok, game_code} = Games.create_game()

      # Add players
      player1 = Player.new("Alice", "alice-id")
      player2 = Player.new("Bob", "bob-id")
      player3 = Player.new("Charlie", "charlie-id")

      Games.join_game(game_code, player1)
      Games.join_game(game_code, player2)
      Games.join_game(game_code, player3)

      # Start the game (should be in playing state)
      Games.start_game(game_code)

      # Connect to the game
      {:ok, _view, html} = live(conn, ~p"/games/#{game_code}?player_name=Alice&player_id=alice-id")

      # Should NOT show the new game button
      refute html =~ "New Game with Same Players"
    end

    test "shows waiting room when game status is waiting", %{conn: conn} do
      # Create a game
      {:ok, game_code} = Games.create_game()

      # Add players but don't start the game
      player1 = Player.new("Alice", "alice-id")
      player2 = Player.new("Bob", "bob-id")
      player3 = Player.new("Charlie", "charlie-id")

      Games.join_game(game_code, player1)
      Games.join_game(game_code, player2)
      Games.join_game(game_code, player3)

      # Connect to the game
      {:ok, _view, html} = live(conn, ~p"/games/#{game_code}?player_name=Alice&player_id=alice-id")

      # Should show waiting room
      assert html =~ "Waiting for Players"
      assert html =~ "Ready to start the game!"
    end
  end
end
