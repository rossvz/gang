defmodule GangWeb.LobbyLiveTest do
  use GangWeb.ConnCase

  import Phoenix.LiveViewTest

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
end
