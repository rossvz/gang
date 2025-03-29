defmodule GangWeb.LobbyLive do
  use GangWeb, :live_view

  alias Gang.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gang.PubSub, "games")
    end

    player_name = Map.get(socket.assigns, :player_name, "")
    player_id = Map.get(socket.assigns, :player_id)

    # If player has a name but no ID, generate one
    player_id = if !player_id, do: Ecto.UUID.generate(), else: player_id

    socket =
      socket
      |> assign(
        games: list_games(),
        game_code: "",
        player_name: player_name,
        player_id: player_id,
        show_error: false,
        error_message: ""
      )
      |> push_event("set_player_name", %{player_name: player_name, player_id: player_id})

    {:ok, socket}
  end

  @impl true
  def handle_event("join_game", %{"game_code" => game_code}, socket) do
    player_name = socket.assigns.player_name
    player_id = socket.assigns.player_id

    if !player_id || !player_name do
      {:noreply,
       socket
       |> put_flash(:error, "Please set your name first")
       |> assign(show_error: true, error_message: "Please set your name first")}
    else
      {:ok, _pid} = Games.join_game(game_code, player_name, player_id)

      {:noreply,
       push_navigate(socket,
         to: ~p"/games/#{game_code}?player_name=#{player_name}&player_id=#{player_id}"
       )}
    end
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    player_name = socket.assigns.player_name
    player_id = socket.assigns.player_id

    if !player_id || !player_name do
      {:noreply,
       socket
       |> put_flash(:error, "Please set your name first")
       |> assign(show_error: true, error_message: "Please set your name first")}
    else
      case Games.create_game() do
        {:ok, game_code} ->
          Games.broadcast_game_created(game_code)

          {:noreply,
           push_navigate(socket,
             to: ~p"/games/#{game_code}?player_name=#{player_name}&player_id=#{player_id}"
           )}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error creating game: #{reason}")
           |> assign(show_error: true, error_message: "Error creating game: #{reason}")}
      end
    end
  end

  @impl true
  def handle_event("validate_join", params, socket) do
    game_code = Map.get(params, "game_code", "")

    {:noreply, assign(socket, game_code: game_code)}
  end

  @impl true
  def handle_event("set_player_name", %{"player_name" => player_name}, socket) do
    # Generate a new player ID if one doesn't exist
    player_id = socket.assigns.player_id || Ecto.UUID.generate()

    {:noreply,
     socket
     |> assign(player_name: player_name)
     |> assign(player_id: player_id)
     |> push_event("set_player_name", %{player_name: player_name, player_id: player_id})}
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
