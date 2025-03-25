defmodule GangWeb.LobbyLive do
  use GangWeb, :live_view

  alias Gang.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Gang.PubSub, "games")
    end

    socket =
      socket
      |> assign(
        games: [],
        game_code: "",
        player_name: "",
        show_error: false,
        error_message: ""
      )

    {:ok, assign(socket, games: Games.list_games())}
  end

  @impl true
  def handle_event("join_game", %{"game_code" => game_code, "player_name" => player_name}, socket) do
    {:ok, _pid} = Games.join_game(game_code, player_name)

    {:noreply, push_navigate(socket, to: ~p"/games/#{game_code}?player_name=#{player_name}")}
  end

  @impl true
  def handle_event(
        "create_game",
        %{"player_name" => player_name},
        socket
      ) do
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
    player_name = Map.get(params, "player_name", "")

    {:noreply, assign(socket, game_code: game_code, player_name: player_name)}
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
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-8 text-center">The Gang - Card Game</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <!-- Create Game Form -->
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold mb-4">Create New Game</h2>
          <.form for={%{}} phx-submit="create_game">
            <div class="mb-4">
              <.input
                type="text"
                name="player_name"
                placeholder="Your Name"
                value={@player_name}
                required
              />
            </div>
            <.button class="w-full">Create Game</.button>
          </.form>
        </div>
        
    <!-- Join Game Form -->
        <div class="bg-white rounded-lg shadow p-6">
          <h2 class="text-xl font-semibold mb-4">Join Existing Game</h2>
          <.form for={%{}} phx-submit="join_game" phx-change="validate_join">
            <div class="mb-4">
              <.input
                type="text"
                name="game_code"
                placeholder="Game Code"
                value={@game_code}
                required
              />
            </div>
            <div class="mb-4">
              <.input
                type="text"
                name="player_name"
                placeholder="Your Name"
                value={@player_name}
                required
              />
            </div>
            <.button class="w-full">Join Game</.button>
          </.form>
        </div>
      </div>
      
    <!-- Active Games List -->
      <div class="mt-8">
        <h2 class="text-xl font-semibold mb-4">Active Games</h2>
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <table class="min-w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Game ID
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Players
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Action
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= if Enum.empty?(@games) do %>
                <tr>
                  <td colspan="4" class="px-6 py-4 text-center text-gray-500">
                    No active games. Create one to get started!
                  </td>
                </tr>
              <% else %>
                <%= for {game_id, _pid} <- @games do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-gray-900">
                      {game_id}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-gray-500">
                      <%= case Games.get_player_count(game_id) do %>
                        <% {:ok, count} -> %>
                          {count} / 6
                        <% _ -> %>
                          0 / 6
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <%= case Games.get_game_status(game_id) do %>
                        <% {:ok, :waiting} -> %>
                          <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-yellow-100 text-yellow-800">
                            Waiting
                          </span>
                        <% {:ok, :playing} -> %>
                          <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                            In Progress
                          </span>
                        <% {:ok, :completed} -> %>
                          <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800">
                            Completed
                          </span>
                        <% _ -> %>
                          <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                            Unknown
                          </span>
                      <% end %>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <%= if @player_name != "" do %>
                        <.link
                          navigate={~p"/games/#{game_id}?player_name=#{@player_name}"}
                          class="text-indigo-600 hover:text-indigo-900"
                        >
                          Join
                        </.link>
                      <% else %>
                        <span class="text-gray-400">Enter Name</span>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
