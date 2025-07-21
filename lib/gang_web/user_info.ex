defmodule GangWeb.UserInfo do
  @moduledoc """
  Handles user info extraction and persistence across LiveView sessions.

  This module provides a unified way to extract player name and ID from various sources
  with the following priority order:
  1. Connect params (sent from client localStorage on every connection)
  2. Session data (server-side persistence)
  3. URL parameters (backward compatibility)
  """

  import Phoenix.Component
  import Phoenix.LiveView

  alias Gang.Game.Player

  @doc """
  Extracts user info from available sources with priority order:
  connect_params > session > url_params

  Returns {player_name, player_id} tuple where values may be nil.
  """
  def extract_user_info(params, session, socket) do
    connect_params = get_connect_params(socket) || %{}

    player_name =
      connect_params["player_name"] ||
        session["player_name"] ||
        params["player_name"]

    player_id =
      connect_params["player_id"] ||
        session["player_id"] ||
        params["player_id"]

    # Clean up empty strings to nil for consistency
    player_name = if player_name == "", do: nil, else: player_name
    player_id = if player_id == "", do: nil, else: player_id

    {player_name, player_id}
  end

  @doc """
  Creates a Player struct from extracted user info.
  Returns nil if no valid player info is available.
  """
  def create_player(player_name, player_id) when is_binary(player_name) and player_name != "" do
    Player.new(player_name, player_id)
  end

  def create_player(_, _), do: nil

  @doc """
  Stores user info in the socket for session persistence.
  This doesn't immediately persist to session - that happens on the next request.
  """
  def store_in_socket(socket, player_name, player_id) do
    socket
    |> put_private(:player_name, player_name)
    |> put_private(:player_id, player_id)
  end

  @doc """
  Checks if we have valid user info (both name and id present).
  """
  def has_valid_user_info?(player_name, player_id) do
    is_binary(player_name) and player_name != "" and
      is_binary(player_id) and player_id != ""
  end

  @doc """
  Updates user info in the socket and triggers client-side storage.
  Used when user sets their name for the first time or updates it.
  """
  def update_user_info(socket, player_name, player_id) do
    socket
    |> assign(player_name: player_name)
    |> assign(player_id: player_id)
    |> assign(player: Player.new(player_name, player_id))
    |> store_in_socket(player_name, player_id)
    |> push_event("save_player_info", %{player_name: player_name, player_id: player_id})
  end
end
