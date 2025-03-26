defmodule GangWeb.LobbyLive do
  use GangWeb, :live_view

  alias Gang.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gang.PubSub, "games")
    end

    player_name = Map.get(socket.assigns, :player_name, "")

    socket =
      socket
      |> assign(
        games: [],
        game_code: "",
        player_name: player_name,
        show_error: false,
        error_message: ""
      )

    {:ok, assign(socket, games: Games.list_games())}
  end

  @impl true
  def handle_event("join_game", %{"game_code" => game_code}, socket) do
    player_name = socket.assigns.player_name
    {:ok, _pid} = Games.join_game(game_code, player_name)

    {:noreply, push_navigate(socket, to: ~p"/games/#{game_code}?player_name=#{player_name}")}
  end

  @impl true
  def handle_event(
        "create_game",
        _params,
        socket
      ) do
    player_name = socket.assigns.player_name

    case Games.create_game() do
      {:ok, game_code} ->
        Games.broadcast_game_created(game_code)

        {:noreply, push_navigate(socket, to: ~p"/games/#{game_code}?player_name=#{player_name}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating game: #{reason}")
         |> assign(show_error: true, error_message: "Error creating game: #{reason}")}
    end
  end

  @impl true
  def handle_event("validate_join", params, socket) do
    game_code = Map.get(params, "game_code", "")

    {:noreply, assign(socket, game_code: game_code)}
  end

  @impl true
  def handle_event("set_player_name", %{"player_name" => player_name}, socket) do
    {:noreply,
     socket
     |> assign(player_name: player_name)
     |> push_event("set_player_name", %{player_name: player_name})}
  end

  @impl true
  def handle_info({:game_created, _game_code}, socket) do
    {:noreply, assign(socket, games: Games.list_games())}
  end

  @impl true
  def handle_info({:game_closed, _game_code}, socket) do
    {:noreply, assign(socket, games: Games.list_games())}
  end

  @impl true
  def handle_info({:game_updated, _game}, socket) do
    {:noreply, assign(socket, games: Games.list_games())}
  end
end
