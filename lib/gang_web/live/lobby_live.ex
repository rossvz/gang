defmodule GangWeb.LobbyLive do
  @moduledoc false
  use GangWeb, :live_view

  alias Gang.Game.Player
  alias Gang.Games

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gang.PubSub, "games")
    end

    player_name = Map.get(params, "player_name", "")
    player_id = Map.get(params, "player_id", Ecto.UUID.generate())

    player = Player.new(player_name, player_id)

    socket =
      socket
      |> assign(
        games: list_games(),
        game_code: "",
        player_name: player_name,
        player_id: player_id,
        show_error: false,
        error_message: "",
        player: player
      )
      |> push_event("set_player_name", %{player_name: player_name, player_id: player_id})

    {:ok, socket}
  end

  @impl true
  def handle_event("join_game", %{"game_code" => game_code}, socket) do
    player = socket.assigns.player
    {:ok, _pid} = Games.join_game(game_code, player)

    {:noreply,
     push_navigate(socket,
       to: ~p"/games/#{game_code}?player_name=#{player.name}&player_id=#{player.id}"
     )}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    player = socket.assigns.player

    case Games.create_game() do
      {:ok, game_code} ->
        Games.broadcast_game_created(game_code)

        {:noreply,
         push_navigate(socket,
           to: ~p"/games/#{game_code}?player_name=#{player.name}&player_id=#{player.id}"
         )}

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
  def handle_event("set_player_name", %{"player_name" => player_name, "player_id" => player_id_from_client}, socket) do
    final_player_id =
      case player_id_from_client do
        nil -> Ecto.UUID.generate()
        "" -> Ecto.UUID.generate()
        id -> id
      end

    updated_player = Player.new(player_name, final_player_id)

    {:noreply,
     socket
     |> assign(player: updated_player)
     |> push_event("set_player_name", %{player_name: player_name, player_id: final_player_id})}
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
    games = list_games()
    {:noreply, assign(socket, games: games)}
  end

  defp list_games do
    Games.list_games()
  end
end
