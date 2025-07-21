defmodule GangWeb.LobbyLive do
  @moduledoc false
  use GangWeb, :live_view

  alias Gang.Game.Player
  alias Gang.Games
  alias GangWeb.UserInfo

  @impl true
  def mount(params, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gang.PubSub, "games")
    end

    # Extract user info from connect params, session, or URL params (in that order)
    {player_name, player_id} = UserInfo.extract_user_info(params, session, socket)

    # Create player if we have valid info, otherwise create empty player
    player = UserInfo.create_player(player_name, player_id) || Player.new("", nil)

    socket =
      socket
      |> assign(
        games: list_games(),
        game_code: "",
        player_name: player_name || "",
        player_id: player_id,
        show_error: false,
        error_message: "",
        player: player
      )
      |> UserInfo.store_in_socket(player_name, player_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("join_game", %{"game_code" => game_code}, socket) do
    {:ok, _pid} = Games.join_game(game_code, socket.assigns.player)

    {:noreply, push_navigate(socket, to: ~p"/games/#{game_code}")}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    case Games.create_game() do
      {:ok, game_code} ->
        Games.broadcast_game_created(game_code)

        {:noreply, push_navigate(socket, to: ~p"/games/#{game_code}")}

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
    final_player_id =
      case socket.assigns.player.id do
        nil -> Ecto.UUID.generate()
        "" -> Ecto.UUID.generate()
        id -> id
      end

    {:noreply, UserInfo.update_user_info(socket, player_name, final_player_id)}
  end

  def handle_event("restore_player_info", %{"player_name" => player_name, "player_id" => player_id}, socket) do
    updated_player = Player.new(player_name, player_id)

    {:noreply, assign(socket, player: updated_player)}
  end

  @impl true
  def handle_info({:game_created, _game_code}, socket) do
    {:noreply, assign(socket, games: Games.list_games())}
  end

  @impl true
  def handle_info({:game_updated, _game}, socket) do
    games = list_games()
    {:noreply, assign(socket, games: games)}
  end

  @impl true
  def handle_info({:game_removed, game_id}, socket) do
    updated_games = Enum.reject(socket.assigns.games, &(&1.code == game_id))
    {:noreply, assign(socket, games: updated_games)}
  end

  defp list_games do
    Games.list_games()
  end
end
