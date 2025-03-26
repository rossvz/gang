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

  defp color_classes(:white), do: "bg-ctp-text text-ctp-base border-ctp-overlay0"
  defp color_classes(:yellow), do: "bg-ctp-yellow text-ctp-base border-ctp-peach"
  defp color_classes(:orange), do: "bg-ctp-peach text-ctp-base border-ctp-red"
  defp color_classes(:red), do: "bg-ctp-red text-ctp-base border-ctp-maroon"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-8 bg-ctp-base text-ctp-text min-h-screen">
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
      
    <!-- Game Status Bar -->
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
      
    <!-- Game Table Area -->
      <%= if @game.status == :playing do %>
        <div class="relative min-h-[600px] md:min-h-[700px] lg:min-h-[800px] mb-8">
          <!-- Central Table -->
          <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
            <div class="relative w-[240px] h-[240px] md:w-[320px] md:h-[320px] lg:w-[400px] lg:h-[400px]">
              <!-- Inner play area -->
              <div class="absolute inset-4 bg-ctp-mantle/80 backdrop-blur rounded-full border border-ctp-surface0/20">
                <!-- Center Table Content -->
                <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[180px] md:w-[240px] lg:w-[300px]">
                  <!-- Community Cards -->
                  <div class="text-center">
                    <div class="flex flex-shrink-0 justify-center gap-1 md:gap-2 mb-4">
                      <%= for {card, idx} <- Enum.with_index(@game.community_cards) do %>
                        <.card
                          card={card || %Card{rank: idx + 1, suit: :spades}}
                          revealed={!is_nil(card)}
                          size={if @game.round == 5, do: "normal", else: "small"}
                        />
                      <% end %>
                    </div>

                    <%= if @game.current_phase == :rank_chip_selection do %>
                      <!-- Available Rank Chips -->
                      <div class="flex justify-center gap-1 md:gap-2 mt-4">
                        <% current_color = @game.current_round_color

                        chips_in_play =
                          @game.players
                          |> Enum.flat_map(& &1.rank_chips)
                          |> Enum.filter(&(&1.color == current_color))

                        claimed_ranks = Enum.map(chips_in_play, & &1.rank)
                        max_players = min(6, length(@game.players)) %>

                        <%= for rank <- 1..max_players do %>
                          <% claimed = rank in claimed_ranks

                          claimed_by =
                            Enum.find(@game.players, fn p ->
                              Enum.any?(p.rank_chips, fn c ->
                                c.rank == rank && c.color == current_color
                              end)
                            end)

                          is_mine = claimed_by && claimed_by.name == @player_name
                          can_claim_from_other = claimed && !is_mine && @player %>

                          <div class="relative">
                            <button
                              phx-click={if !claimed, do: "claim_chip"}
                              phx-value-rank={rank}
                              phx-value-color={current_color}
                              disabled={claimed || !@player}
                              class={[
                                "w-6 h-6 md:w-8 md:h-8 lg:w-10 lg:h-10 rounded-full flex items-center justify-center font-bold text-sm md:text-base lg:text-lg border-2 transition-all duration-300",
                                "hover:scale-110 transform",
                                @selected_rank_chip && @selected_rank_chip.rank == rank &&
                                  "ring-2 ring-ctp-lavender ring-offset-2 ring-offset-ctp-base",
                                case current_color do
                                  :white -> "bg-ctp-text border-ctp-overlay0 text-ctp-base"
                                  :yellow -> "bg-ctp-yellow border-ctp-peach text-ctp-base"
                                  :orange -> "bg-ctp-peach border-ctp-red text-ctp-base"
                                  :red -> "bg-ctp-red border-ctp-maroon text-ctp-base"
                                end,
                                claimed && "opacity-0",
                                !@player && "opacity-50 cursor-not-allowed",
                                can_claim_from_other &&
                                  "hover:brightness-110 border-ctp-blue border-2"
                              ]}
                            >
                              {rank}
                            </button>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Players arranged in a circle -->
          <% # Get unique players to prevent duplicates
          unique_players = Enum.uniq_by(@game.players, & &1.name)
          player_count = length(unique_players)

          # Find current player index in the unique players list
          current_player_index =
            if @player_name,
              do: Enum.find_index(unique_players, &(&1.name == @player_name)),
              else: 0

          # Rotate players so current player is at the bottom
          rotated_players =
            if current_player_index do
              # Split the list at current player and rotate
              {before_current, [current | after_current]} =
                Enum.split(unique_players, current_player_index)

              [current | after_current] ++ before_current
            else
              unique_players
            end %>

          <%= for {player, index} <- Enum.with_index(rotated_players) do %>
            <% base_angle = 90
            angle_step = 360 / player_count
            # Add angle_step to rotate clockwise from South
            angle = base_angle + angle_step * index

            # Adjust radius based on screen size and player count
            base_radius =
              cond do
                player_count <= 3 -> 300
                player_count <= 4 -> 350
                true -> 400
              end

            # Add padding to prevent cutoff
            container_padding = 0

            # Calculate position with adjusted radius and padding
            radius = base_radius + container_padding
            x = 50 + radius * :math.cos(angle * :math.pi() / 180) / 10
            y = 50 + radius * :math.sin(angle * :math.pi() / 180) / 10 %>

            <div
              class={[
                "absolute w-40 md:w-48 lg:w-64 -translate-x-1/2 -translate-y-1/2",
                "bg-ctp-surface0/90 backdrop-blur rounded-lg shadow-lg p-2 md:p-3 lg:p-4",
                "transition-all duration-300 hover:shadow-xl hover:bg-ctp-surface0",
                "border border-ctp-surface0/50",
                player.name == @player_name && "ring-2 ring-ctp-lavender"
              ]}
              style={"left: #{x}%; top: #{y}%"}
            >
              <div class="flex justify-between items-center mb-1 md:mb-2">
                <h3 class="text-sm md:text-base lg:text-lg font-medium text-ctp-text truncate flex-1">
                  {player.name}
                </h3>
                <span class={[
                  "px-1.5 py-0.5 text-xs rounded-full ml-1 md:ml-2",
                  (player.connected && "bg-ctp-green/20 text-ctp-green") ||
                    "bg-ctp-red/20 text-ctp-red"
                ]}>
                  {if player.connected, do: "Online", else: "Offline"}
                </span>
              </div>

              <%= if @game.status == :playing do %>
                <!-- Player's Rank Chips -->
                <div class="mb-1 md:mb-2">
                  <div class="flex flex-wrap gap-0.5 md:gap-1">
                    <%= for color <- [:white, :yellow, :orange, :red] do %>
                      <%= if player_chip = Enum.find(player.rank_chips, &(&1.color == color)) do %>
                        <div
                          phx-click="claim_chip"
                          phx-value-rank={player_chip.rank}
                          phx-value-color={player_chip.color}
                          class={[
                            "w-5 h-5 md:w-6 md:h-6 lg:w-8 lg:h-8 rounded-full flex items-center justify-center font-bold text-xs md:text-sm lg:text-base border transition-colors cursor-pointer",
                            case color do
                              :white -> "bg-ctp-text border-ctp-overlay0 text-ctp-base"
                              :yellow -> "bg-ctp-yellow border-ctp-peach text-ctp-base"
                              :orange -> "bg-ctp-peach border-ctp-red text-ctp-base"
                              :red -> "bg-ctp-red border-ctp-maroon text-ctp-base"
                            end
                          ]}
                        >
                          {player_chip.rank}
                        </div>
                      <% else %>
                        <div class="w-5 h-5 md:w-6 md:h-6 lg:w-8 lg:h-8 rounded-full flex items-center justify-center border border-dashed border-ctp-overlay0">
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                </div>
                
    <!-- Player's Cards -->
                <%= if @game.round == 5 || player.name == @player_name do %>
                  <div class="flex justify-center gap-0.5 md:gap-1 lg:gap-2">
                    <%= for card <- player.cards do %>
                      <.card card={card} size={if index == 0, do: "normal", else: "small"} />
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>
        </div>
        
    <!-- Action Buttons -->
        <%= if @game.current_phase == :rank_chip_selection && @player do %>
          <div class="fixed bottom-4 md:bottom-6 lg:bottom-8 left-1/2 -translate-x-1/2 flex gap-2 z-10">
            <%= if @selected_rank_chip do %>
              <button
                class="px-2 py-1 md:px-3 md:py-1.5 lg:px-4 lg:py-2 text-xs md:text-sm lg:text-base rounded-lg bg-ctp-green hover:bg-ctp-teal text-ctp-base font-medium transition-colors"
                phx-click="claim_chip"
              >
                Claim Rank Chip {@selected_rank_chip.rank}
              </button>
            <% end %>

            <%= if Enum.any?(@player.rank_chips, &(&1.color == @game.current_round_color)) do %>
              <button
                class="px-2 py-1 md:px-3 md:py-1.5 lg:px-4 lg:py-2 text-xs md:text-sm lg:text-base rounded-lg bg-ctp-red hover:bg-ctp-maroon text-ctp-base font-medium transition-colors"
                phx-click="return_chip"
              >
                Return My Chip
              </button>
            <% end %>
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
  attr :revealed, :boolean, default: true
  # Can be "small", "normal", or "large"
  attr :size, :string, default: "normal"

  def card(assigns) do
    ~H"""
    <div class={
      [
        "group rounded-xl flex flex-col flex-shrink-0 items-center justify-between font-bold relative cursor-default",
        "transform transition-all duration-300 hover:scale-105 hover:-translate-y-1",
        "shadow-lg hover:shadow-xl border-2",
        # Size classes
        case @size do
          "small" -> "w-14 h-20 p-2 text-sm"
          "normal" -> "w-[4.5rem] h-[6.5rem] p-2"
          "large" -> "w-20 h-28 p-3"
        end,
        # Color classes
        if @revealed do
          case @card.suit do
            :hearts ->
              "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-red border-ctp-red/20"

            :diamonds ->
              "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-red border-ctp-red/20"

            :clubs ->
              "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-text border-ctp-text/20"

            :spades ->
              "bg-gradient-to-br from-ctp-base to-ctp-mantle text-ctp-text border-ctp-text/20"
          end
        else
          "bg-gradient-to-br from-ctp-surface0 to-ctp-mantle border-ctp-overlay0/20"
        end
      ]
    }>
      <%= if @revealed do %>
        <!-- Top rank -->
        <div class={[
          "self-start font-extrabold tracking-tight",
          case @size do
            "small" -> "text-base"
            "normal" -> "text-lg"
            "large" -> "text-xl"
          end
        ]}>
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
          "transform transition-all duration-300 group-hover:scale-110",
          "absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2",
          case @size do
            "small" -> "text-2xl"
            "normal" -> "text-3xl"
            "large" -> "text-4xl"
          end,
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
        <div class={[
          "self-end font-extrabold tracking-tight rotate-180",
          case @size do
            "small" -> "text-base"
            "normal" -> "text-lg"
            "large" -> "text-xl"
          end
        ]}>
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
      <% else %>
        <!-- Card back design -->
        <div class="absolute inset-2 rounded-lg bg-ctp-surface0 overflow-hidden">
          <!-- Animated pattern -->
          <div class="absolute inset-0 bg-ctp-overlay0/10">
            <div class="absolute inset-0 grid grid-cols-3 gap-1 p-1">
              <%= for _i <- 1..9 do %>
                <div class="aspect-square rounded-sm bg-ctp-overlay0/10 animate-pulse"></div>
              <% end %>
            </div>
          </div>
          <!-- Center diamond -->
          <div class="absolute inset-0 flex items-center justify-center">
            <div class={[
              "rotate-45 bg-ctp-overlay0/20 animate-pulse",
              case @size do
                "small" -> "w-6 h-6"
                "normal" -> "w-7 h-7"
                "large" -> "w-8 h-8"
              end
            ]}>
            </div>
          </div>
          <!-- Corner accents -->
          <div class="absolute top-1 left-1 w-1.5 h-1.5 rounded-full bg-ctp-overlay0/20 animate-pulse">
          </div>
          <div class="absolute top-1 right-1 w-1.5 h-1.5 rounded-full bg-ctp-overlay0/20 animate-pulse">
          </div>
          <div class="absolute bottom-1 left-1 w-1.5 h-1.5 rounded-full bg-ctp-overlay0/20 animate-pulse">
          </div>
          <div class="absolute bottom-1 right-1 w-1.5 h-1.5 rounded-full bg-ctp-overlay0/20 animate-pulse">
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
