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

  defp color_classes(:white), do: "bg-ctp-surface0 text-ctp-text border-ctp-overlay0"
  defp color_classes(:yellow), do: "bg-ctp-yellow text-ctp-base border-ctp-peach"
  defp color_classes(:orange), do: "bg-ctp-peach text-ctp-base border-ctp-red"
  defp color_classes(:red), do: "bg-ctp-red text-ctp-base border-ctp-maroon"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto px-4 py-8 bg-ctp-base text-ctp-text min-h-screen">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-ctp-text">Game #{@game_id}</h1>
        <button
          class="px-4 py-2 rounded-lg bg-ctp-surface0 hover:bg-ctp-surface1 text-ctp-text transition-colors"
          phx-click="back_to_lobby"
        >
          Back to Lobby
        </button>
      </div>

      <%= if !@player do %>
        <div
          class="bg-ctp-yellow/20 border-l-4 border-ctp-yellow text-ctp-yellow p-4 mb-8 rounded-r-lg"
          role="alert"
        >
          <p>You are observing this game</p>
        </div>
      <% end %>
      
    <!-- Game Status -->
      <div class="bg-ctp-mantle rounded-lg shadow-lg shadow-ctp-crust/10 p-6 mb-8">
        <div class="flex justify-between items-center">
          <div>
            <h2 class="text-xl font-semibold mb-2 text-ctp-text">Game Status</h2>
            <div class="flex items-center space-x-2">
              <span class="font-medium text-ctp-subtext0">Round:</span>
              <span class="px-2 py-1 bg-ctp-surface0 text-ctp-text rounded-md">
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
              <span class="font-medium text-ctp-subtext0">Vaults:</span>
              <div class="flex space-x-1">
                <%= for i <- 1..3 do %>
                  <div class={[
                    "w-6 h-6 rounded-full flex items-center justify-center",
                    (i <= @game.vaults && "bg-ctp-green text-ctp-base") ||
                      "bg-ctp-surface0 text-ctp-subtext0"
                  ]}>
                    <span class="text-xs">{i}</span>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="flex items-center space-x-2 mt-2">
              <span class="font-medium text-ctp-subtext0">Alarms:</span>
              <div class="flex space-x-1">
                <%= for i <- 1..3 do %>
                  <div class={[
                    "w-6 h-6 rounded-full flex items-center justify-center",
                    (i <= @game.alarms && "bg-ctp-red text-ctp-base") ||
                      "bg-ctp-surface0 text-ctp-subtext0"
                  ]}>
                    <span class="text-xs">{i}</span>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <div>
            <%= if @game.status == :waiting && @player && length(@game.players) >= 3 do %>
              <button
                class="px-4 py-2 rounded-lg bg-ctp-blue hover:bg-ctp-sapphire text-ctp-base font-medium transition-colors"
                phx-click="start_game"
              >
                Start Game
              </button>
            <% end %>

            <%= if @game.status == :playing && @player do %>
              <%= if @game.current_phase == :rank_chip_selection && @game.all_rank_chips_claimed? do %>
                <%= if @game.round < 4 do %>
                  <button
                    class="px-4 py-2 rounded-lg bg-ctp-blue hover:bg-ctp-sapphire text-ctp-base font-medium transition-colors"
                    phx-click="continue"
                  >
                    Next Round
                  </button>
                <% else %>
                  <button
                    class="px-4 py-2 rounded-lg bg-ctp-mauve hover:bg-ctp-pink text-ctp-base font-medium transition-colors"
                    phx-click="continue"
                  >
                    End Round
                  </button>
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
            "bg-ctp-mantle rounded-lg shadow-lg shadow-ctp-crust/10 p-4",
            player.name == @player_name && "ring-2 ring-ctp-lavender"
          ]}>
            <div class="flex justify-between items-center mb-2">
              <h3 class="text-lg font-medium text-ctp-text">{player.name}</h3>
              <span class={[
                "px-2 py-1 text-xs rounded-full",
                (player.connected && "bg-ctp-green/20 text-ctp-green") || "bg-ctp-red/20 text-ctp-red"
              ]}>
                {if player.connected, do: "Online", else: "Offline"}
              </span>
            </div>

            <%= if @game.status == :playing do %>
              <!-- Player's Rank Chips -->
              <div class="mb-2">
                <span class="text-sm text-ctp-subtext0">Rank Chips:</span>
                <div class="flex flex-wrap gap-1 mt-1">
                  <%= for color <- [:white, :yellow, :orange, :red] do %>
                    <%= if player_chip = Enum.find(player.rank_chips, &(&1.color == color)) do %>
                      <div
                        phx-click="claim_chip"
                        phx-value-rank={player_chip.rank}
                        phx-value-color={color}
                        class={[
                          "w-8 h-8 rounded-full flex items-center justify-center font-bold border transition-colors",
                          case color do
                            :white -> "bg-ctp-surface0 border-ctp-overlay0 text-ctp-text"
                            :yellow -> "bg-ctp-yellow border-ctp-peach text-ctp-base"
                            :orange -> "bg-ctp-peach border-ctp-red text-ctp-base"
                            :red -> "bg-ctp-red border-ctp-maroon text-ctp-base"
                          end
                        ]}
                      >
                        {player_chip.rank}
                      </div>
                    <% else %>
                      <div class="w-8 h-8 rounded-full flex items-center justify-center border border-dashed border-ctp-overlay0">
                      </div>
                    <% end %>
                  <% end %>
                </div>
              </div>
              
    <!-- Player's Cards -->
              <%= if @game.round == 5 || player.name == @player_name do %>
                <div class="mt-3">
                  <span class="text-sm text-ctp-subtext0">Cards:</span>
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
        <div class="bg-ctp-mantle rounded-lg shadow-lg shadow-ctp-crust/10 p-6 mb-8">
          <h2 class="text-xl font-semibold mb-4 text-ctp-text">Community Cards</h2>

          <%= if @game.round == 1 && Enum.all?(@game.community_cards, &is_nil/1) do %>
            <%= if @game.vaults > 0 || @game.alarms > 0 do %>
              <div class={[
                "mb-4 p-3 rounded-md",
                if(@game.vaults > @game.alarms,
                  do: "bg-ctp-green/20 text-ctp-green",
                  else: "bg-ctp-red/20 text-ctp-red"
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
                <p class="text-sm mt-1 opacity-90">
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
                <div class="w-16 h-24 bg-ctp-surface0 rounded-md flex items-center justify-center shadow-sm text-ctp-subtext0">
                  {idx + 1}
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
        
    <!-- Current Round Rank Chips -->
        <%= if @game.current_phase == :rank_chip_selection do %>
          <div class="bg-ctp-mantle rounded-lg shadow-lg shadow-ctp-crust/10 p-6 mb-8">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-xl font-semibold text-ctp-text">Available Rank Chips</h2>
              <div class="space-x-2">
                <%= if @player && @selected_rank_chip do %>
                  <button
                    class="px-4 py-2 rounded-lg bg-ctp-green hover:bg-ctp-teal text-ctp-base font-medium transition-colors"
                    phx-click="claim_chip"
                  >
                    Claim Rank Chip {@selected_rank_chip.rank}
                  </button>
                <% end %>

                <%= if @player && Enum.any?(@player.rank_chips, &(&1.color == @game.current_round_color)) do %>
                  <button
                    class="px-4 py-2 rounded-lg bg-ctp-red hover:bg-ctp-maroon text-ctp-base font-medium transition-colors"
                    phx-click="return_chip"
                  >
                    Return My Chip
                  </button>
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
                      "w-12 h-12 rounded-full flex items-center justify-center font-bold text-xl border transition-colors",
                      @selected_rank_chip && @selected_rank_chip.rank == rank &&
                        "ring-2 ring-ctp-lavender ring-offset-2 ring-offset-ctp-base",
                      case current_color do
                        :white -> "bg-ctp-surface0 border-ctp-overlay0 text-ctp-text"
                        :yellow -> "bg-ctp-yellow border-ctp-peach text-ctp-base"
                        :orange -> "bg-ctp-peach border-ctp-red text-ctp-base"
                        :red -> "bg-ctp-red border-ctp-maroon text-ctp-base"
                      end,
                      claimed && !can_claim_from_other && "opacity-50 cursor-not-allowed",
                      !@player && "opacity-50 cursor-not-allowed",
                      can_claim_from_other && "hover:brightness-110 border-ctp-blue border-2"
                    ]}
                    title={if can_claim_from_other, do: "Claim from #{claimed_by}", else: nil}
                  >
                    {rank}
                  </button>
                  <%= if claimed_by && claimed_by != @player_name do %>
                    <div
                      class="absolute -top-2 -right-2 bg-ctp-lavender text-ctp-base text-xs rounded-full w-5 h-5 flex items-center justify-center"
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
        <div class="bg-ctp-mantle rounded-lg shadow-lg shadow-ctp-crust/10 p-6 text-center">
          <h2 class="text-xl font-semibold mb-4 text-ctp-text">Waiting for Players</h2>
          <p class="mb-4 text-ctp-text">
            Share this game code with your friends:
            <span class="font-bold text-ctp-mauve">{@game_id}</span>
          </p>
          <p class="text-sm text-ctp-subtext0 mb-2">Players joined: {length(@game.players)}/6</p>
          <p class="text-sm text-ctp-subtext1">
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
      "group w-20 h-28 rounded-xl flex flex-col items-center justify-between p-3 font-bold relative cursor-default",
      "transform transition-all duration-300 hover:scale-105 hover:-translate-y-1",
      "shadow-lg hover:shadow-xl border-2",
      case @card.suit do
        :hearts -> "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-red border-ctp-red/20"
        :diamonds -> "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-red border-ctp-red/20"
        :clubs -> "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-text border-ctp-text/20"
        :spades -> "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-text border-ctp-text/20"
      end
    ]}>
      <!-- Top rank -->
      <div class="self-start text-xl font-extrabold tracking-tight">
        {case @card.rank do
          14 -> "A"
          13 -> "K"
          12 -> "Q"
          11 -> "J"
          n -> "#{n}"
        end}
      </div>
      
    <!-- Center suit with glow effect -->
      <div class={[
        "text-4xl transform transition-all duration-300 group-hover:scale-110",
        "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2",
        case @card.suit do
          suit when suit in [:hearts, :diamonds] -> "drop-shadow-[0_0_3px_rgba(237,135,150,0.5)]"
          _ -> "drop-shadow-[0_0_3px_rgba(205,214,244,0.5)]"
        end
      ]}>
        {case @card.suit do
          :hearts -> "♥"
          :diamonds -> "♦"
          :clubs -> "♣"
          :spades -> "♠"
        end}
      </div>
      
    <!-- Bottom rank (inverted) -->
      <div class="self-end text-xl font-extrabold tracking-tight rotate-180">
        {case @card.rank do
          14 -> "A"
          13 -> "K"
          12 -> "Q"
          11 -> "J"
          n -> "#{n}"
        end}
      </div>
      
    <!-- Subtle shine effect -->
      <div class="absolute inset-0 rounded-xl bg-gradient-to-br from-white/5 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300">
      </div>
    </div>
    """
  end
end
