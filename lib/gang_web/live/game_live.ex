defmodule GangWeb.GameLive do
  use GangWeb, :live_view

  on_mount {GangWeb.ParamHandlers, :extract_query_params}

  alias Gang.Game.Card
  alias Gang.Games

  # Add types for clarity
  @type player_split :: %{
          current_player: map() | nil,
          other_players: list(map())
        }

  @impl true
  def mount(%{"id" => game_id} = params, _session, socket) do
    # Get player info from either URL params or socket assigns
    player_name = params["player_name"] || socket.assigns.player_name
    player_id = params["player_id"] || socket.assigns.player_id

    # Redirect to lobby if no player ID
    if !player_id do
      {:ok,
       socket
       |> put_flash(:error, "Please set your name in the lobby first")
       |> push_navigate(to: ~p"/")}
    else
      if connected?(socket) do
        Games.subscribe(game_id)
        if player_name, do: {:ok, _} = Games.join_game(game_id, player_name, player_id)
      end

      case Games.get_game(game_id) do
        {:ok, game} ->
          player = if player_id, do: Enum.find(game.players, &(&1.id == player_id)), else: nil

          # Get unique players and split into current and others
          player_split = split_players(game.players, player_id)

          socket =
            socket
            |> assign(game_id: game_id)
            |> assign(player_name: player_name)
            |> assign(player_id: player_id)
            |> assign(game: game)
            |> assign(player: player)
            |> assign(selected_rank_chip: nil)
            |> assign(player_split: player_split)
            |> assign(show_hand_guide: false)

          {:ok, socket}

        {:error, _} ->
          {:ok, push_navigate(socket, to: ~p"/")}
      end
    end
  end

  # Move player splitting logic out of template
  @spec split_players(list(map()), String.t() | nil) :: player_split()
  defp split_players(players, current_player_id) do
    unique_players = Enum.uniq_by(players, & &1.id)

    if current_player_id do
      current_player = Enum.find(unique_players, &(&1.id == current_player_id))
      other_players = unique_players |> List.delete(current_player)
      %{current_player: current_player, other_players: other_players}
    else
      %{current_player: nil, other_players: unique_players}
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
      socket.assigns.player_id,
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
      socket.assigns.player_id,
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
      socket.assigns.player_id,
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
      socket.assigns.player_id
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_rank_chip", %{"rank" => rank, "color" => color}, socket) do
    {rank, _} = Integer.parse(rank)
    color = String.to_existing_atom(color)

    {:noreply, assign(socket, selected_rank_chip: %{rank: rank, color: color})}
  end

  def handle_event("back_to_lobby", _params, socket) do
    Games.leave_game(socket.assigns.game_id, socket.assigns.player_id)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def handle_event("continue", _params, socket) do
    Games.advance_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:advance_after_evaluation, socket) do
    Games.advance_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  def handle_info({:game_updated, game}, socket) do
    # Update the player object and player split when game state changes
    player_id = socket.assigns.player_id
    player = if player_id, do: Enum.find(game.players, &(&1.id == player_id)), else: nil
    player_split = split_players(game.players, player_id)

    {:noreply,
     socket
     |> assign(game: game)
     |> assign(player: player)
     |> assign(player_split: player_split)}
  end

  @impl true
  def handle_event("toggle_hand_guide", _params, socket) do
    {:noreply, assign(socket, show_hand_guide: !socket.assigns.show_hand_guide)}
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
        if(@claimed_by && @claimed_by.id == @player.id, do: "ring-4 ring-blue-400"),
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
    <div class="max-w-7xl mx-auto px-4 py-8 text-ctp-text min-h-screen">
      <.game_header game_id={@game_id} player={@player} show_hand_guide={@show_hand_guide} />
      <.game_status game={@game} player={@player} />

      <%= if @game.status == :playing do %>
        <div class={[
          "relative mb-8",
          "md:min-h-[700px] lg:min-h-[800px]"
        ]}>
          <.mobile_layout
            player_split={@player_split}
            game={@game}
            player={@player}
            player_name={@player_name}
            selected_rank_chip={@selected_rank_chip}
          />

          <.desktop_layout
            game={@game}
            player={@player}
            player_name={@player_name}
            selected_rank_chip={@selected_rank_chip}
          />
        </div>
      <% else %>
        <.waiting_room game={@game} />
      <% end %>
    </div>
    """
  end

  def waiting_room(assigns) do
    ~H"""
    <div class="bg-ctp-mantle/80 backdrop-blur-sm rounded-lg shadow-lg shadow-ctp-crust/10 p-6 text-center">
      <h2 class="text-xl font-semibold mb-4 text-ctp-text">Waiting for Players</h2>
      <p class="mb-4 text-ctp-text">
        Share this game code with your friends:
        <span class="font-bold text-ctp-mauve">{@game.code}</span>
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
    """
  end

  # Components

  def game_header(assigns) do
    ~H"""
    <div class="flex justify-between items-center mb-8">
      <button
        class="px-4 py-2 rounded-lg bg-ctp-mantle/80 backdrop-blur-sm hover:bg-ctp-surface1 text-ctp-text transition-colors"
        phx-click="back_to_lobby"
      >
        Lobby
      </button>
      <h1 class="text-lg font-bold text-ctp-text">{@game_id}</h1>
      <button
        class="px-4 py-2 rounded-lg bg-ctp-mantle/80 backdrop-blur-sm hover:bg-ctp-surface1 text-ctp-text transition-colors"
        phx-click="toggle_hand_guide"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-6 w-6"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
      </button>
    </div>

    <%= if !@player do %>
      <div
        class="bg-ctp-yellow/20 backdrop-blur-sm border-l-4 border-ctp-yellow text-ctp-yellow p-4 mb-8 rounded-r-lg"
        role="alert"
      >
        <p>You are observing this game</p>
      </div>
    <% end %>

    <.hand_ranking_guide :if={@show_hand_guide} />
    """
  end

  def game_status(assigns) do
    ~H"""
    <div class="bg-ctp-mantle/80 backdrop-blur-sm rounded-lg shadow-lg shadow-ctp-crust/10 p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="w-full">
          <.round_indicator round={@game.current_round} />
          <.status_counters vaults={@game.vaults} alarms={@game.alarms} />
        </div>
      </div>
      <div class="flex justify-center items-center">
        <.game_actions game={@game} player={@player} />
      </div>
    </div>
    """
  end

  def round_indicator(assigns) do
    ~H"""
    <div class="flex items-center justify-center">
      <span class="px-2 py-1 bg-ctp-surface0 text-ctp-text rounded-md">
        <%= case @round do %>
          <% :preflop -> %>
            Starting Hands
          <% :flop -> %>
            The Flop
          <% :turn -> %>
            The Turn
          <% :river -> %>
            The River
          <% :evaluation -> %>
            Evaluation
        <% end %>
      </span>
    </div>
    """
  end

  def status_counters(assigns) do
    ~H"""
    <div class="flex flex-row gap-4 mt-2 justify-between">
      <.counter_row label="Vaults" count={@vaults} max={3} color="green" />
      <.counter_row label="Alarms" count={@alarms} max={3} color="red" />
    </div>
    """
  end

  def counter_row(assigns) do
    ~H"""
    <div class="flex items-center space-y-2 flex-col">
      <span class=" text-sm text-ctp-subtext0">{@label}</span>
      <div class="flex space-x-1">
        <%= for i <- 1..@max do %>
          <div class={[
            "w-6 h-6 rounded-full flex items-center justify-center",
            (i <= @count && "bg-ctp-#{@color} text-ctp-base") ||
              "bg-ctp-surface0 text-ctp-subtext0"
          ]}>
            <span class="text-xs">{i}</span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def game_actions(assigns) do
    ~H"""
    <div class="flex items-center flex-col">
      <button
        :if={@game.status == :waiting && @player && length(@game.players) >= 3}
        class="px-4 py-2 rounded-lg bg-ctp-blue hover:bg-ctp-sapphire text-ctp-base font-medium transition-colors"
        phx-click="start_game"
      >
        Start Game
      </button>

      <%= if @game.status == :playing && @player do %>
        <%= if @game.current_phase == :rank_chip_selection && @game.all_rank_chips_claimed? do %>
          <button
            :if={@game.current_round != :river}
            class="px-4 py-2 rounded-lg bg-ctp-blue hover:bg-ctp-sapphire text-ctp-base font-medium transition-colors"
            phx-click="continue"
          >
            Next Round
          </button>
          <button
            :if={@game.current_round == :river}
            class="px-4 py-2 rounded-lg bg-ctp-mauve hover:bg-ctp-pink text-ctp-base font-medium transition-colors"
            phx-click="continue"
          >
            Evaluate Hands
          </button>
        <% end %>

        <%= if @game.current_round == :evaluation do %>
          <div class="flex flex-col items-center gap-4">
            <div class="text-lg font-bold mb-2">
              <div
                :if={@game.last_round_result == :vault}
                class="text-xl animate-pulse text-ctp-green"
              >
                Success! Vault Secured!
              </div>
              <div :if={@game.last_round_result == :alarm} class="text-xl animate-pulse text-ctp-red">
                Alarm Triggered!
              </div>
              <span :if={@game.vaults >= 3} class="text-ctp-green">
                Victory! You've secured the vault!
              </span>
              <span :if={@game.alarms >= 3} class="text-ctp-red">
                Game Over! Too many alarms triggered!
              </span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  def player_card(assigns) do
    ~H"""
    <div class={[
      "bg-ctp-mantle/80 backdrop-blur-sm rounded-lg shadow-lg p-2",
      "border border-ctp-surface0/50",
      @is_current && "ring-2 ring-ctp-lavender"
    ]}>
      <div class="flex justify-between items-center mb-1">
        <h3 class="text-sm font-medium text-ctp-text truncate flex-1">
          {@player.name}
        </h3>
        <span class={[
          "px-1 py-1 text-xs rounded-full ml-1",
          (@player.connected && "bg-ctp-green animate-pulse") ||
            "bg-ctp-red/20 text-ctp-red"
        ]}>
        </span>
      </div>

      <.player_rank_chips player={@player} size={@size} />

      <%= if @show_cards do %>
        <div class="flex flex-col gap-2">
          <div class="flex justify-center gap-0.5">
            <%= for card <- @player.cards do %>
              <.card card={card} size={@card_size} />
            <% end %>
          </div>
          <%= if @game.current_round == :evaluation && @game.evaluated_hands do %>
            <.hand_result hand={Map.get(@game.evaluated_hands, @player.name)} size={@size} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def hand_result(assigns) do
    ~H"""
    <%= if @hand do %>
      <div class={[
        "text-center font-medium",
        @size == "small" && "text-xs",
        @size == "normal" && "text-sm",
        @size == "large" && "text-base"
      ]}>
        <span class="text-ctp-mauve">
          <%= case elem(@hand, 0) do %>
            <% :royal_flush -> %>
              Royal Flush
            <% :straight_flush -> %>
              Straight Flush
            <% :four_of_a_kind -> %>
              Four of a Kind
            <% :full_house -> %>
              Full House
            <% :flush -> %>
              Flush
            <% :straight -> %>
              Straight
            <% :three_of_a_kind -> %>
              Three of a Kind
            <% :two_pair -> %>
              Two Pair
            <% :pair -> %>
              Pair
            <% :high_card -> %>
              High Card
          <% end %>
        </span>
      </div>
    <% end %>
    """
  end

  def player_rank_chips(assigns) do
    ~H"""
    <div class="mb-1">
      <div class="flex flex-wrap gap-0.5">
        <%= for color <- [:white, :yellow, :orange, :red] do %>
          <%= if player_chip = Enum.find(@player.rank_chips, &(&1.color == color)) do %>
            <div
              class={[
                "rounded-full flex items-center justify-center font-bold border transition-colors cursor-pointer",
                @size == "small" && "w-5 h-5 text-xs",
                @size == "normal" && "w-8 h-8 text-base border-2",
                case color do
                  :white -> "bg-ctp-text border-ctp-overlay0 text-ctp-base"
                  :yellow -> "bg-ctp-yellow border-ctp-peach text-ctp-base"
                  :orange -> "bg-ctp-peach border-ctp-red text-ctp-base"
                  :red -> "bg-ctp-red border-ctp-maroon text-ctp-base"
                end
              ]}
              phx-click="claim_chip"
              phx-value-rank={player_chip.rank}
              phx-value-color={player_chip.color}
            >
              {player_chip.rank}
            </div>
          <% else %>
            <div class={[
              "rounded-full flex items-center justify-center border border-dashed border-ctp-overlay0",
              @size == "small" && "w-5 h-5",
              @size == "normal" && "w-8 h-8 border-2"
            ]}>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  def community_cards(assigns) do
    ~H"""
    <div class="flex flex-shrink-0 justify-center gap-1 mb-4">
      <%= for {card, idx} <- Enum.with_index(@cards) do %>
        <.card
          card={card || %Card{rank: idx + 1, suit: :spades}}
          revealed={!is_nil(card)}
          size={@size}
        />
      <% end %>
    </div>
    """
  end

  def available_rank_chips(assigns) do
    ~H"""
    <div class="flex justify-center gap-1 mt-4">
      <%= for rank <- 1..@max_players do %>
        <% claimed = rank in @claimed_ranks

        claimed_by =
          Enum.find(@players, fn p ->
            Enum.any?(p.rank_chips, fn c ->
              c.rank == rank && c.color == @current_color
            end)
          end)

        is_mine = claimed_by && claimed_by.id == @player.id
        can_claim_from_other = claimed && !is_mine && @player %>

        <div class="relative">
          <button
            phx-click={if !claimed, do: "claim_chip"}
            phx-value-rank={rank}
            phx-value-color={@current_color}
            disabled={claimed || !@player}
            class={[
              "rounded-full flex items-center justify-center font-bold border-2 transition-all duration-300",
              "hover:scale-110 transform",
              @size == "small" && "w-6 h-6 text-sm",
              @size == "normal" && "w-8 h-8 text-base",
              @size == "large" && "w-10 h-10 text-lg",
              @selected_rank == rank &&
                "ring-2 ring-ctp-lavender ring-offset-2 ring-offset-ctp-base",
              case @current_color do
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
    """
  end

  def mobile_layout(assigns) do
    ~H"""
    <div class="md:hidden flex flex-col gap-4">
      <!-- Other Players Section -->
      <div class="bg-ctp-mantle rounded-lg p-4">
        <div class="grid grid-cols-2 gap-2">
          <%= for player <- @player_split.other_players do %>
            <.player_card
              player={player}
              is_current={false}
              size="small"
              card_size="small"
              show_cards={@game.current_round == :evaluation}
              game={@game}
            />
          <% end %>
        </div>
      </div>
      
    <!-- Game Table Section -->
      <div class="bg-ctp-mantle rounded-lg p-4">
        <div class="flex flex-col items-center">
          <.community_cards cards={@game.community_cards} size="small" />

          <%= if @game.current_phase == :rank_chip_selection do %>
            <.available_rank_chips
              players={@game.players}
              current_color={@game.current_round_color}
              player={@player}
              player_name={@player_name}
              selected_rank={@selected_rank_chip && @selected_rank_chip.rank}
              max_players={min(6, length(@game.players))}
              size="normal"
              claimed_ranks={get_claimed_ranks(@game.players, @game.current_round_color)}
            />
          <% end %>
        </div>
      </div>
      
    <!-- Current Player Section -->
      <%= if @player_split.current_player do %>
        <div class={[
          "bg-ctp-mantle rounded-lg p-2",
          "border-2 border-ctp-lavender"
        ]}>
          <div class="w-full flex justify-center items-center py-2">
            <.player_rank_chips player={@player_split.current_player} size="normal" />
          </div>
          <div class="flex flex-col gap-2">
            <div class="flex justify-center gap-2">
              <%= for card <- @player_split.current_player.cards do %>
                <.card card={card} size="normal" />
              <% end %>
            </div>
            <%= if @game.current_round == :evaluation && @game.evaluated_hands do %>
              <.hand_result
                hand={Map.get(@game.evaluated_hands, @player_split.current_player.name)}
                size="normal"
              />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def desktop_layout(assigns) do
    ~H"""
    <div class="hidden md:block">
      <.central_table
        community_cards={@game.community_cards}
        game={@game}
        player={@player}
        player_name={@player_name}
        selected_rank_chip={@selected_rank_chip}
      />
      <.circular_players players={@game.players} player_name={@player_name} game={@game} />
    </div>
    """
  end

  def central_table(assigns) do
    ~H"""
    <div class="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
      <div class="relative w-[240px] h-[240px] md:w-[320px] md:h-[320px] lg:w-[400px] lg:h-[400px]">
        <div class="absolute inset-4 bg-ctp-base/80 backdrop-blur rounded-full border border-ctp-surface0/20">
          <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[180px] md:w-[240px] lg:w-[300px]">
            <div class="text-center">
              <.community_cards cards={@community_cards} size="normal" />

              <%= if @game.current_phase == :rank_chip_selection do %>
                <.available_rank_chips
                  players={@game.players}
                  current_color={@game.current_round_color}
                  player={@player}
                  player_name={@player_name}
                  selected_rank={@selected_rank_chip && @selected_rank_chip.rank}
                  max_players={min(6, length(@game.players))}
                  size="large"
                  claimed_ranks={get_claimed_ranks(@game.players, @game.current_round_color)}
                />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def circular_players(assigns) do
    # Move calculations into assigns
    assigns =
      assigns
      |> assign(:rotated_players, rotate_players_for_circle(assigns.players, assigns.player_name))
      |> assign(
        :player_count,
        length(rotate_players_for_circle(assigns.players, assigns.player_name))
      )

    ~H"""
    <%= for {player, index} <- Enum.with_index(@rotated_players) do %>
      <% {x, y} = calculate_player_position(index, @player_count) %>

      <div
        class="absolute w-40 md:w-48 lg:w-64 -translate-x-1/2 -translate-y-1/2"
        style={"left: #{x}%; top: #{y}%"}
      >
        <.player_card
          player={player}
          is_current={player.name == @player_name}
          size="normal"
          card_size="normal"
          show_cards={@game.current_round == :evaluation || player.name == @player_name}
          game={@game}
        />
      </div>
    <% end %>
    """
  end

  # Helper functions for circular layout
  defp rotate_players_for_circle(players, current_player_name) do
    unique_players = Enum.uniq_by(players, & &1.name)
    current_index = Enum.find_index(unique_players, &(&1.name == current_player_name))

    if current_index do
      {before_current, [current | after_current]} = Enum.split(unique_players, current_index)
      [current | after_current] ++ before_current
    else
      unique_players
    end
  end

  defp calculate_player_position(index, player_count) do
    base_angle = 90
    angle_step = 360 / player_count
    angle = base_angle + angle_step * index

    base_radius =
      cond do
        player_count <= 3 -> 300
        player_count <= 4 -> 350
        true -> 400
      end

    x = 50 + base_radius * :math.cos(angle * :math.pi() / 180) / 10
    y = 50 + base_radius * :math.sin(angle * :math.pi() / 180) / 10
    {x, y}
  end

  defp get_claimed_ranks(players, current_color) do
    players
    |> Enum.flat_map(& &1.rank_chips)
    |> Enum.filter(&(&1.color == current_color))
    |> Enum.map(& &1.rank)
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
          "extra_small" -> "w-12 h-18 text-sm"
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

  def hand_ranking_guide(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-ctp-base/80 backdrop-blur-sm z-50 flex items-center justify-center p-1 pb-6">
      <div class="bg-ctp-mantle rounded-lg shadow-xl w-full max-w-2xl max-h-[60vh] overflow-y-auto">
        <div class="p-2 sm:p-4">
          <div class="flex justify-around items-center sticky top-0 bg-ctp-mantle z-10 py-4">
            <h2 class="text-lg sm:text-2xl font-bold text-ctp-text">Hand Ranking Guide</h2>
            <button
              class="text-ctp-subtext0 hover:text-ctp-text transition-colors"
              phx-click="toggle_hand_guide"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 sm:h-6 sm:w-6"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>

          <div class="space-y-1 sm:space-y-2">
            <div
              :for={
                {hand_name, example_cards} <- [
                  {"Royal Flush",
                   [
                     %Card{rank: 14, suit: :hearts},
                     %Card{rank: 13, suit: :hearts},
                     %Card{rank: 12, suit: :hearts},
                     %Card{rank: 11, suit: :hearts},
                     %Card{rank: 10, suit: :hearts}
                   ]},
                  {"Straight Flush",
                   [
                     %Card{rank: 9, suit: :spades},
                     %Card{rank: 8, suit: :spades},
                     %Card{rank: 7, suit: :spades},
                     %Card{rank: 6, suit: :spades},
                     %Card{rank: 5, suit: :spades}
                   ]},
                  {"Four of a Kind",
                   [
                     %Card{rank: 10, suit: :hearts},
                     %Card{rank: 10, suit: :diamonds},
                     %Card{rank: 10, suit: :clubs},
                     %Card{rank: 10, suit: :spades},
                     %Card{rank: 5, suit: :hearts}
                   ]},
                  {"Full House",
                   [
                     %Card{rank: 7, suit: :hearts},
                     %Card{rank: 7, suit: :diamonds},
                     %Card{rank: 7, suit: :clubs},
                     %Card{rank: 4, suit: :spades},
                     %Card{rank: 4, suit: :hearts}
                   ]},
                  {"Flush",
                   [
                     %Card{rank: 14, suit: :diamonds},
                     %Card{rank: 10, suit: :diamonds},
                     %Card{rank: 8, suit: :diamonds},
                     %Card{rank: 6, suit: :diamonds},
                     %Card{rank: 3, suit: :diamonds}
                   ]},
                  {"Straight",
                   [
                     %Card{rank: 10, suit: :hearts},
                     %Card{rank: 9, suit: :diamonds},
                     %Card{rank: 8, suit: :clubs},
                     %Card{rank: 7, suit: :spades},
                     %Card{rank: 6, suit: :hearts}
                   ]},
                  {"Three of a Kind",
                   [
                     %Card{rank: 8, suit: :hearts},
                     %Card{rank: 8, suit: :diamonds},
                     %Card{rank: 8, suit: :clubs},
                     %Card{rank: 5, suit: :spades},
                     %Card{rank: 2, suit: :hearts}
                   ]},
                  {"Two Pair",
                   [
                     %Card{rank: 9, suit: :hearts},
                     %Card{rank: 9, suit: :diamonds},
                     %Card{rank: 5, suit: :clubs},
                     %Card{rank: 5, suit: :spades},
                     %Card{rank: 2, suit: :hearts}
                   ]},
                  {"Pair",
                   [
                     %Card{rank: 10, suit: :hearts},
                     %Card{rank: 10, suit: :diamonds},
                     %Card{rank: 8, suit: :clubs},
                     %Card{rank: 5, suit: :spades},
                     %Card{rank: 2, suit: :hearts}
                   ]},
                  {"High Card",
                   [
                     %Card{rank: 14, suit: :hearts},
                     %Card{rank: 10, suit: :diamonds},
                     %Card{rank: 8, suit: :clubs},
                     %Card{rank: 5, suit: :spades},
                     %Card{rank: 2, suit: :hearts}
                   ]}
                ]
              }
              class="flex flex-col justify-center items-center gap-1 p-1 sm:p-2 bg-ctp-base rounded-lg"
            >
              <div class="font-medium text-ctp-text w-full text-center">
                {hand_name}
              </div>
              <div class="flex gap-0 overflow-x-auto w-full justify-center">
                <%= for card <- example_cards do %>
                  <div class="scale-[0.9] origin-center">
                    <.card card={card} size="small" />
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
