defmodule GangWeb.GameLiveTemplateTest do
  use GangWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Gang.Game.{Card, Player, RankChip, State}

  describe "game completion template rendering" do
    test "shows evaluation screen and button for completed game", %{conn: conn} do
      # Create the exact assigns from your live debugger output
      assigns = %{
        game: %State{
          code: "KCP9",
          status: :completed,  # This is the key - status is :completed
          current_round: :evaluation,  # And round is :evaluation  
          current_phase: :rank_chip_selection,
          current_round_color: :red,
          vaults: 1,
          alarms: 3,  # Game over - 3 alarms
          last_round_result: :alarm,
          community_cards: [
            %Card{rank: 4, suit: :spades},
            %Card{rank: 9, suit: :clubs},
            %Card{rank: 4, suit: :clubs},
            %Card{rank: 5, suit: :hearts},
            %Card{rank: 14, suit: :spades}
          ],
          all_rank_chips_claimed?: true,
          evaluated_hands: %{
            "Bob" => {:three_of_a_kind, []},
            "alpha" => {:pair, []},
            "beta" => {:two_pair, []}
          },
          players: [
            %Player{
              id: "965ed807-2866-430f-bc0e-f6292c9a8fc6",
              name: "Bob",
              connected: true,
              rank_chips: [%RankChip{color: :red, rank: 1}],
              cards: [%Card{rank: 11, suit: :hearts}, %Card{rank: 4, suit: :diamonds}]
            },
            %Player{
              id: "150eaa75-bed5-4fbd-ac4d-2e7b4131067b", 
              name: "alpha",
              connected: true,
              rank_chips: [%RankChip{color: :red, rank: 3}],
              cards: [%Card{rank: 8, suit: :diamonds}, %Card{rank: 6, suit: :clubs}]
            },
            %Player{
              id: "7441afb3-35e7-43f1-9613-03981c29b1b0",
              name: "beta", 
              connected: true,
              rank_chips: [%RankChip{color: :red, rank: 2}],
              cards: [%Card{rank: 9, suit: :spades}, %Card{rank: 10, suit: :clubs}]
            }
          ],
          deck: [],
          game_created: DateTime.utc_now(),
          last_active: DateTime.utc_now()
        },
        player: %Player{
          id: "150eaa75-bed5-4fbd-ac4d-2e7b4131067b",
          name: "alpha",
          connected: true,
          rank_chips: [%RankChip{color: :red, rank: 3}],
          cards: [%Card{rank: 8, suit: :diamonds}, %Card{rank: 6, suit: :clubs}]
        },
        player_id: "150eaa75-bed5-4fbd-ac4d-2e7b4131067b",
        game_id: "KCP9",
        player_name: "alpha",
        selected_rank_chip: nil,
        show_hand_guide: false,
        needs_player_info: false
      }

      # Test the game_actions component directly with these assigns
      html = render_component(&GangWeb.GameLive.game_actions/1, assigns)
      
      # Debug: print the rendered HTML to see what we get
      IO.puts("=== RENDERED HTML ===")
      IO.puts(html)
      IO.puts("=== END HTML ===")
      
      # These should be visible with our fix
      assert html =~ "Game Over! Too many alarms triggered!"
      assert html =~ "New Game with Same Players"
    end

    test "game_actions component renders correctly with BEFORE fix assigns", %{conn: conn} do
      # Test what happens with the old logic (status == :playing only)
      assigns = %{
        game: %State{
          status: :playing,  # OLD: This would work
          current_round: :evaluation,
          vaults: 1,
          alarms: 3,
          last_round_result: :alarm,
          current_phase: :rank_chip_selection,
          all_rank_chips_claimed?: true,
          players: [],
          community_cards: [nil, nil, nil, nil, nil],
          evaluated_hands: %{},
          code: "TEST",
          deck: [],
          game_created: DateTime.utc_now(),
          last_active: DateTime.utc_now()
        },
        player: %Player{id: "test", name: "test", connected: true, cards: [], rank_chips: []}
      }

      html = render_component(&GangWeb.GameLive.game_actions/1, assigns)
      
      # With status: :playing, these SHOULD show
      assert html =~ "Game Over! Too many alarms triggered!"
    end

    test "game_actions component fails with completed status BEFORE our fix", %{conn: conn} do
      # This test demonstrates the bug - when status is :completed, nothing shows
      assigns = %{
        game: %State{
          status: :completed,  # NEW: This wouldn't work before our fix
          current_round: :evaluation,
          vaults: 1,
          alarms: 3,
          last_round_result: :alarm,
          current_phase: :rank_chip_selection,
          all_rank_chips_claimed?: true,
          players: [],
          community_cards: [nil, nil, nil, nil, nil],
          evaluated_hands: %{},
          code: "TEST",
          deck: [],
          game_created: DateTime.utc_now(),
          last_active: DateTime.utc_now()
        },
        player: %Player{id: "test", name: "test", connected: true, cards: [], rank_chips: []}
      }

      html = render_component(&GangWeb.GameLive.game_actions/1, assigns)
      
      # With our fix (status in [:playing, :completed]), these SHOULD show
      assert html =~ "Game Over! Too many alarms triggered!"
      assert html =~ "New Game with Same Players"
    end
  end

  describe "template conditions debugging" do
    test "debug individual template conditions", %{conn: _conn} do
      # Let's test each condition individually
      game = %State{
        status: :completed,
        current_round: :evaluation,
        vaults: 1,
        alarms: 3,
        last_round_result: :alarm,
        current_phase: :rank_chip_selection,
        all_rank_chips_claimed?: true,
        players: [],
        community_cards: [nil, nil, nil, nil, nil],
        evaluated_hands: %{},
        code: "TEST",
        deck: [],
        game_created: DateTime.utc_now(),
        last_active: DateTime.utc_now()
      }
      
      player = %Player{id: "test", name: "test", connected: true, cards: [], rank_chips: []}

      # Test each condition
      IO.puts("=== CONDITION DEBUGGING ===")
      IO.puts("game.status: #{inspect(game.status)}")
      IO.puts("game.status in [:playing, :completed]: #{game.status in [:playing, :completed]}")
      IO.puts("player present: #{!is_nil(player)}")
      IO.puts("game.current_round: #{inspect(game.current_round)}")
      IO.puts("game.current_round == :evaluation: #{game.current_round == :evaluation}")
      IO.puts("game.alarms >= 3: #{game.alarms >= 3}")
      IO.puts("game.last_round_result: #{inspect(game.last_round_result)}")
      IO.puts("=== END DEBUGGING ===")

      # All conditions should be true
      assert game.status in [:playing, :completed]
      assert !is_nil(player)
      assert game.current_round == :evaluation
      assert game.alarms >= 3
      assert game.last_round_result == :alarm
    end
  end
end