defmodule GangWeb.GameLive do
  use GangWeb, :live_view

  on_mount {GangWeb.ParamHandlers, :extract_query_params}

  alias Gang.Game.Card
  alias Gang.Games

  @impl true
  def mount(%{"id" => game_id, "player_name" => player_name}, _session, socket) do
    if connected?(socket) do
      Games.subscribe(game_id)
      if player_name, do: {:ok, _} = Games.join_game(game_id, player_name)
    end

    case Games.get_game(game_id) do
      {:ok, game} ->
        player = if player_name, do: Enum.find(game.players, &(&1.name == player_name)), else: nil

        socket =
          socket
          |> assign(game_id: game_id)
          |> assign(player_name: player_name)
          |> assign(game: game)
          |> assign(player: player)
          |> assign(selected_rank_chip: nil)

        {:ok, socket}

      {:error, _} ->
        {:ok, push_navigate(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_event("start_game", _params, socket) do
    Games.start_game(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("claim_chip", %{"rank" => rank, "color" => color}, socket) do
    {rank, _} = Integer.parse(rank)
    color = String.to_existing_atom(color)

    Games.claim_rank_chip(
      socket.assigns.game_id,
      socket.assigns.player_name,
      rank,
      color
    )

    {:noreply, assign(socket, selected_rank_chip: nil)}
  end

  @impl true
  def handle_event("claim_chip", _params, socket) do
    %{rank: rank, color: color} = socket.assigns.selected_rank_chip

    Games.claim_rank_chip(
      socket.assigns.game_id,
      socket.assigns.player_name,
      rank,
      color
    )

    {:noreply, assign(socket, selected_rank_chip: nil)}
  end

  @impl true
  def handle_event(
        "claim_from_player",
        %{"rank" => rank, "color" => color, "player" => from_player},
        socket
      ) do
    {rank, _} = Integer.parse(rank)
    color = String.to_existing_atom(color)

    Games.claim_rank_chip_from_player(
      socket.assigns.game_id,
      socket.assigns.player_name,
      from_player,
      rank,
      color
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("return_chip", _params, socket) do
    Games.return_rank_chip(
      socket.assigns.game_id,
      socket.assigns.player_name
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    Games.advance_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_rank_chip", %{"rank" => rank, "color" => color}, socket) do
    {rank, _} = Integer.parse(rank)
    color = String.to_existing_atom(color)

    {:noreply, assign(socket, selected_rank_chip: %{rank: rank, color: color})}
  end

  def handle_event("back_to_lobby", _params, socket) do
    Games.leave_game(socket.assigns.game_id, socket.assigns.player_name)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    # Update the player object when the game state changes
    player_name = socket.assigns.player_name
    player = if player_name, do: Enum.find(game.players, &(&1.name == player_name)), else: nil

    {:noreply, socket |> assign(game: game) |> assign(player: player)}
  end

  def rank_chip_button(assigns) do
    ~H"""
    <button
      phx-click="claim_chip"
      phx-value-rank={@rank}
      phx-value-color={@color}
      disabled={@disabled}
      class={[
        "flex items-center justify-center w-16 h-16 rounded-full text-lg font-bold shadow-md border-2",
        color_classes(@color),
        if(@claimed_by == @player_name, do: "ring-4 ring-blue-400"),
        if(@disabled, do: "opacity-50 cursor-not-allowed", else: "hover:brightness-110")
      ]}
    >
      {@rank}
    </button>
    """
  end

  defp color_classes(:white), do: "bg-white text-gray-900 border-gray-300"
  defp color_classes(:yellow), do: "bg-yellow-300 text-yellow-800 border-yellow-500"
  defp color_classes(:orange), do: "bg-orange-400 text-orange-900 border-orange-600"
  defp color_classes(:red), do: "bg-red-500 text-white border-red-700"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Game #{@game_id}</h1>
        <button phx-click="back_to_lobby">Back to Lobby</button>
      </div>

      <%= if !@player do %>
        <div class="bg-yellow-100 border-l-4 border-yellow-500 text-yellow-700 p-4 mb-8" role="alert">
          <p>You are observing this game</p>
        </div>
      <% end %>
      
    <!-- Game Status -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-8">
        <div class="flex justify-between items-center">
          <div>
            <h2 class="text-xl font-semibold mb-2">Game Status</h2>
            <div class="flex items-center space-x-2">
              <span class="font-medium">Round:</span>
              <span class="px-2 py-1 bg-gray-100 rounded-md">
                <%= case @game.round do %>
                  <% 1 -> %>
                    Starting Hands
                  <% 2 -> %>
                    The Flop
                  <% 3 -> %>
                    The Turn
                  <% 4 -> %>
                    The River
                  <% 5 -> %>
                    Game Over
                <% end %>
              </span>
            </div>
            <div class="flex items-center space-x-2 mt-2">
              <span class="font-medium">Vaults:</span>
              <div class="flex space-x-1">
                <%= for i <- 1..3 do %>
                  <div class={[
                    "w-6 h-6 rounded-full flex items-center justify-center",
                    (i <= @game.vaults && "bg-green-500 text-white") || "bg-gray-200"
                  ]}>
                    <span class="text-xs">{i}</span>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="flex items-center space-x-2 mt-2">
              <span class="font-medium">Alarms:</span>
              <div class="flex space-x-1">
                <%= for i <- 1..3 do %>
                  <div class={[
                    "w-6 h-6 rounded-full flex items-center justify-center",
                    (i <= @game.alarms && "bg-red-500 text-white") || "bg-gray-200"
                  ]}>
                    <span class="text-xs">{i}</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div>
            <%= if @game.status == :waiting && @player && length(@game.players) >= 3 do %>
              <.button phx-click="start_game">Start Game</.button>
            <% end %>

            <%= if @game.status == :playing && @player do %>
              <%= if @game.current_phase == :rank_chip_selection && @game.all_rank_chips_claimed? do %>
                <%= if @game.round < 4 do %>
                  <.button phx-click="continue" class="bg-blue-600 hover:bg-blue-700">
                    Next Round
                  </.button>
                <% else %>
                  <.button phx-click="continue" class="bg-purple-600 hover:bg-purple-700">
                    End Round
                  </.button>
                <% end %>
              <% end %>
            <% end %>
          </div>
        </div>
      </div>
      
    <!-- Players List -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <%= for player <- @game.players do %>
          <div class={[
            "bg-white rounded-lg shadow-md p-4",
            player.name == @player_name && "border-2 border-indigo-500"
          ]}>
            <div class="flex justify-between items-center mb-2">
              <h3 class="text-lg font-medium">{player.name}</h3>
              <span class={[
                "px-2 py-1 text-xs rounded-full",
                (player.connected && "bg-green-100 text-green-800") || "bg-red-100 text-red-800"
              ]}>
                {if player.connected, do: "Online", else: "Offline"}
              </span>
            </div>

            <%= if @game.status == :playing do %>
              <!-- Player's Rank Chips -->
              <div class="mb-2">
                <span class="text-sm text-gray-500">Rank Chips:</span>
                <div class="flex flex-wrap gap-1 mt-1">
                  <%= for color <- [:white, :yellow, :orange, :red] do %>
                    <%= if player_chip = Enum.find(player.rank_chips, &(&1.color == color)) do %>
                      <div
                        phx-click="claim_chip"
                        phx-value-rank={player_chip.rank}
                        phx-value-color={color}
                        class={[
                          "w-8 h-8 rounded-full flex items-center justify-center font-bold border",
                          case color do
                            :white -> "bg-white border-gray-400 text-gray-800"
                            :yellow -> "bg-yellow-200 border-yellow-400 text-yellow-800"
                            :orange -> "bg-orange-200 border-orange-400 text-orange-800"
                            :red -> "bg-red-200 border-red-400 text-red-800"
                          end
                        ]}
                      >
                        {player_chip.rank}
                      </div>
                    <% else %>
                      <div class="w-8 h-8 rounded-full flex items-center justify-center border border-dashed border-gray-300">
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
              
    <!-- Player's Cards (only shown to the current player or in game over) -->
              <%= if @game.round == 5 || player.name == @player_name do %>
                <div class="mt-3">
                  <span class="text-sm text-gray-500">Cards:</span>
                  <div class="flex space-x-2 mt-1">
                    <%= for card <- player.cards do %>
                      <.card card={card} />
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
      
    <!-- Main Game Area -->
      <%= if @game.status == :playing do %>
        <div class="bg-white rounded-lg shadow-md p-6 mb-8">
          <h2 class="text-xl font-semibold mb-4">Community Cards</h2>

          <%= if @game.round == 1 && Enum.all?(@game.community_cards, &is_nil/1) do %>
            <%= if @game.vaults > 0 || @game.alarms > 0 do %>
              <div class={[
                "mb-4 p-3 rounded-md",
                if(@game.vaults > @game.alarms,
                  do: "bg-green-100 text-green-800",
                  else: "bg-red-100 text-red-800"
                )
              ]}>
                <p class="font-semibold">
                  <%= if @game.vaults > @game.alarms do %>
                    Vault secured! Players have opened {@game.vaults} vault{if @game.vaults > 1,
                      do: "s"}.
                  <% else %>
                    Alarm triggered! Players have triggered {@game.alarms} alarm{if @game.alarms > 1,
                      do: "s"}.
                  <% end %>
                </p>
                <p class="text-sm mt-1">
                  Starting a new hand. Select your rank chips for this round.
                </p>
              </div>
            <% end %>
          <% end %>

          <div class="flex flex-wrap gap-2">
            <%= for {card, idx} <- Enum.with_index(@game.community_cards) do %>
              <%= if card do %>
                <.card card={card} />
              <% else %>
                <div class="w-16 h-24 bg-gray-200 rounded-md flex items-center justify-center shadow-sm">
                  {idx + 1}
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Current Round Rank Chips -->
        <%= if @game.current_phase == :rank_chip_selection do %>
          <div class="bg-white rounded-lg shadow-md p-6 mb-8">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-semibold">Available Rank Chips</h2>
              <div class="space-x-2">
                <%= if @player && @selected_rank_chip do %>
                  <.button phx-click="claim_chip" class="bg-green-600 hover:bg-green-700">
                    Claim Rank Chip {@selected_rank_chip.rank}
                  </.button>
                <% end %>

                <%= if @player && Enum.any?(@player.rank_chips, &(&1.color == @game.current_round_color)) do %>
                  <.button phx-click="return_chip" class="bg-red-600 hover:bg-red-700">
                    Return My Chip
                  </.button>
                <% end %>
              </div>
            </div>

            <div class="flex flex-wrap gap-3">
              <% current_color = @game.current_round_color

              chips_in_play =
                @game.players
                |> Enum.flat_map(& &1.rank_chips)
                |> Enum.filter(&(&1.color == current_color))

              claimed_ranks = Enum.map(chips_in_play, & &1.rank)

              player_with_chip = fn rank ->
                chip = Enum.find(chips_in_play, &(&1.rank == rank))

                if chip do
                  owner =
                    Enum.find(@game.players, fn p ->
                      Enum.any?(p.rank_chips, fn c -> c.rank == rank && c.color == current_color end)
                    end)

                  if owner, do: owner.name, else: nil
                else
                  nil
                end
              end

              max_players = min(6, length(@game.players)) %>

              <%= for rank <- 1..max_players do %>
                <% claimed = rank in claimed_ranks
                claimed_by = player_with_chip.(rank)
                is_mine = claimed_by == @player_name
                can_claim_from_other = claimed && !is_mine && @player %>
                <div class="relative">
                  <button
                    phx-click="claim_chip"
                    phx-value-rank={rank}
                    phx-value-color={current_color}
                    phx-value-player={claimed_by}
                    disabled={(claimed && !can_claim_from_other) || !@player}
                    class={[
                      "w-12 h-12 rounded-full flex items-center justify-center font-bold text-xl border",
                      @selected_rank_chip && @selected_rank_chip.rank == rank &&
                        "ring-2 ring-indigo-500 ring-offset-2",
                      case current_color do
                        :white -> "bg-white border-gray-400 text-gray-800"
                        :yellow -> "bg-yellow-200 border-yellow-400 text-yellow-800"
                        :orange -> "bg-orange-200 border-orange-400 text-orange-800"
                        :red -> "bg-red-200 border-red-400 text-red-800"
                      end,
                      claimed && !can_claim_from_other && "opacity-50 cursor-not-allowed",
                      !@player && "opacity-50 cursor-not-allowed",
                      can_claim_from_other && "hover:brightness-110 border-blue-500 border-2"
                    ]}
                    title={if can_claim_from_other, do: "Claim from #{claimed_by}", else: nil}
                  >
                    {rank}
                  </button>
                  <%= if claimed_by && claimed_by != @player_name do %>
                    <div
                      class="absolute -top-2 -right-2 bg-indigo-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center"
                      title={"Claimed by #{claimed_by}"}
                    >
                      {String.first(claimed_by)}
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <!-- Waiting for players -->
        <div class="bg-white rounded-lg shadow-md p-6 text-center">
          <h2 class="text-xl font-semibold mb-4">Waiting for Players</h2>
          <p class="mb-4">
            Share this game code with your friends: <span class="font-bold">{@game_id}</span>
          </p>
          <p class="text-sm text-gray-500 mb-2">Players joined: {length(@game.players)}/6</p>
          <p class="text-sm text-gray-500">
            <%= if length(@game.players) < 3 do %>
              Need at least {3 - length(@game.players)} more player(s) to start.
            <% else %>
              Ready to start the game!
            <% end %>
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # Card component
  attr :card, Card, required: true

  def card(assigns) do
    ~H"""
    <div class={[
      "w-16 h-24 rounded-md flex flex-col items-center justify-center font-bold shadow border border-gray-200",
      case @card.suit do
        :hearts -> "bg-white text-red-600"
        :diamonds -> "bg-white text-red-600"
        :clubs -> "bg-white text-black"
        :spades -> "bg-white text-black"
      end
    ]}>
      <div class="text-lg">
        {case @card.rank do
          14 -> "A"
          13 -> "K"
          12 -> "Q"
          11 -> "J"
          n -> "#{n}"
        end}
      </div>
      <div class="text-xl">
        {case @card.suit do
          :hearts -> "♥"
          :diamonds -> "♦"
          :clubs -> "♣"
          :spades -> "♠"
        end}
      </div>
    </div>
    """
  end
end
