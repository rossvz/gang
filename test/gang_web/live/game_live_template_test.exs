defmodule GangWeb.GameLiveTemplateTest do
  use GangWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Gang.Game.Player
  alias Gang.Games

  describe "new game with same players functionality" do
    test "reset_game button functionality", %{conn: conn} do
      # Create a completed game manually using Games context
      {:ok, game_code} = Games.create_game()

      player1 = Player.new("Alice", "alice-id")
      player2 = Player.new("Bob", "bob-id")
      player3 = Player.new("Charlie", "charlie-id")

      Games.join_game(game_code, player1)
      Games.join_game(game_code, player2)
      Games.join_game(game_code, player3)
      Games.start_game(game_code)

      # Manually complete the game using Games.reset_game - first we need to complete it
      game_pid = Gang.Game.Supervisor.get_game_pid(game_code)

      :sys.replace_state(game_pid, fn state ->
        %{
          state
          | status: :completed,
            current_round: :evaluation,
            vaults: 3,
            last_round_result: :vault,
            evaluated_hands: %{"Alice" => {:pair, []}, "Bob" => {:flush, []}, "Charlie" => {:high_card, []}}
        }
      end)

      # Connect to LiveView - should show completed game
      {:ok, view, html} = live(conn, ~p"/games/#{game_code}?player_name=Alice&player_id=alice-id")

      # Should show the new game button for completed game
      assert html =~ "New Game with Same Players"

      # Click the reset button
      view |> element("button", "New Game with Same Players") |> render_click()

      # Game should be reset but keep same players
      {:ok, reset_game} = Games.get_game(game_code)
      assert reset_game.status == :waiting
      assert reset_game.vaults == 0
      assert reset_game.alarms == 0
      assert length(reset_game.players) == 3
      assert Enum.map(reset_game.players, & &1.name) == ["Alice", "Bob", "Charlie"]
    end
  end
end
