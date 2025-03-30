defmodule GangWeb.ParamHandlers do
  @moduledoc false
  import Phoenix.Component

  def on_mount(:extract_query_params, params, _session, socket) do
    # Extract player_name and player_id from query parameters
    player_name = params["player_name"]
    player_id = params["player_id"]

    {:cont,
     socket
     |> assign(:player_name, player_name)
     |> assign(:player_id, player_id)}
  end
end
