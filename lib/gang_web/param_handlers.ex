defmodule GangWeb.ParamHandlers do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:extract_query_params, params, _session, socket) do
    # Extract player_name from query parameters
    player_name = params["player_name"]

    {:cont, assign(socket, :player_name, player_name)}
  end
end
