defmodule GangWeb.GameLiveTemplateTest do
  use GangWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Gang.Game.Player
  alias Gang.Games

  describe "new game with same players functionality" do
    test "shows new game button after completing game with 3 vaults", %{conn: conn} do
      # Create a game and add 3+ players
      {:ok, game_code} = Games.create_game()
      
      player1 = Player.new("Alice", "alice-id")
      player2 = Player.new("Bob", "bob-id")
      player3 = Player.new("Charlie", "charlie-id")
      
      Games.join_game(game_code, player1)
      Games.join_game(game_code, player2)
      Games.join_game(game_code, player3)
      Games.start_game(game_code)
      
      # Connect to LiveView
      {:ok, view, _html} = live(conn, ~p"/games/#{game_code}?player_name=Alice&player_id=alice-id")
      
      # Directly set the game state to completed with 3 vaults
      game_pid = Gang.Game.Supervisor.get_game_pid(game_code)
      :sys.replace_state(game_pid, fn state ->
        %{state | 
          status: :completed,
          current_round: :evaluation,
          vaults: 3,
          alarms: 0,
          last_round_result: :vault,
          evaluated_hands: %{"Alice" => {:pair, []}, "Bob" => {:flush, []}, "Charlie" => {:high_card, []}}
        }
      end)
      
      # Send the game_updated message directly to the LiveView process
      {:ok, updated_game} = Games.get_game(game_code)
      send(view.pid, {:game_updated, updated_game})
      
      # Re-render the view to see the changes
      html = render(view)
      
      # Should show victory message and new game button
      assert html =~ "Victory! You've secured the vault!"
      assert html =~ "New Game with Same Players"
    end

    test "shows new game button after game over with 3 alarms", %{conn: conn} do
      # Create a game and add 3+ players  
      {:ok, game_code} = Games.create_game()
      
      player1 = Player.new("Alice", "alice-id")
      player2 = Player.new("Bob", "bob-id")
      player3 = Player.new("Charlie", "charlie-id")
      
      Games.join_game(game_code, player1)
      Games.join_game(game_code, player2)
      Games.join_game(game_code, player3)
      Games.start_game(game_code)
      
      # Connect to LiveView
      {:ok, view, _html} = live(conn, ~p"/games/#{game_code}?player_name=Alice&player_id=alice-id")
      
      # Directly set the game state to completed with 3 alarms
      game_pid = Gang.Game.Supervisor.get_game_pid(game_code)
      :sys.replace_state(game_pid, fn state ->
        %{state | 
          status: :completed,
          current_round: :evaluation,
          vaults: 0,
          alarms: 3,
          last_round_result: :alarm,
          evaluated_hands: %{"Alice" => {:pair, []}, "Bob" => {:flush, []}, "Charlie" => {:high_card, []}}
        }
      end)
      
      # Send the game_updated message directly to the LiveView process
      {:ok, updated_game} = Games.get_game(game_code)
      send(view.pid, {:game_updated, updated_game})
      
      # Re-render the view to see the changes
      html = render(view)
      
      # Should show game over message and new game button
      assert html =~ "Game Over! Too many alarms triggered!"
      assert html =~ "New Game with Same Players"
    end
  end
end