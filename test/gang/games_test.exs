defmodule Gang.GamesTest do
  use ExUnit.Case, async: true

  alias Gang.Games
  alias Gang.Game.Player

  test "return_rank_chip/2 returns error when player has no chip" do
    {:ok, code} = Games.create_game()

    player = Player.new("alice")
    {:ok, _} = Games.join_game(code, player)

    assert {:error, :chip_not_found} = Games.return_rank_chip(code, player.id)
  end
end
