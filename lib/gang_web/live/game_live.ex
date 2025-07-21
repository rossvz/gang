defmodule GangWeb.GameLive do
  @moduledoc false
  use GangWeb, :live_view

  alias Gang.Game.Card
  alias Gang.Game.Player
  alias Gang.Games
  alias GangWeb.CardComponents

  on_mount {GangWeb.ParamHandlers, :extract_query_params}

  # Add types for clarity
  @type player_split :: %{
          current_player: map() | nil,
          other_players: list(map())
        }

  @impl true
  def mount(%{"id" => game_id} = params, _session, socket) do
    player_name = params["player_name"] || socket.assigns.player_name
    player_id = params["player_id"] || socket.assigns.player_id

    # Check if we have valid player info
    has_player_info = player_name && player_id && player_name != "" && player_id != ""

    player = if has_player_info, do: Player.new(player_name, player_id)

    if connected?(socket) do
      Games.subscribe(game_id)

      if has_player_info do
        Games.join_game(game_id, player)
      end
    end

    case Games.get_game(game_id) do
      {:ok, game} ->
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
          |> assign(needs_player_info: !has_player_info)

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
  def handle_event("claim_from_player", %{"rank" => rank, "color" => color, "player" => from_player}, socket) do
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
    if socket.assigns.player_id do
      Games.leave_game(socket.assigns.game_id, socket.assigns.player_id)
    end

    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("join_game_with_name", %{"player_name" => player_name}, socket) do
    player_id = Ecto.UUID.generate()
    player = Player.new(player_name, player_id)

    case Games.join_game(socket.assigns.game_id, player) do
      {:ok, _} ->
        # Update socket with player info
        player_split = split_players(socket.assigns.game.players, player_id)

        socket =
          socket
          |> assign(player_name: player_name)
          |> assign(player_id: player_id)
          |> assign(player: player)
          |> assign(player_split: player_split)
          |> assign(needs_player_info: false)
          |> push_event("save_player_info", %{player_name: player_name, player_id: player_id})

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to join game: #{reason}")}
    end
  end

  @impl true
  def handle_event("continue", _params, socket) do
    Games.advance_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_hand_guide", _params, socket) do
    {:noreply, assign(socket, show_hand_guide: !socket.assigns.show_hand_guide)}
  end

  @impl true
  def handle_event("copy_link", %{"code" => game_code}, socket) do
    # Generate the path using the ~p sigil for compile-time checks
    game_path = ~p"/games/#{game_code}"
    share_url = GangWeb.Endpoint.url() <> game_path
    {:noreply, push_event(socket, "copy_to_clipboard", %{text: share_url})}
  end

  @impl true
  def handle_info(:advance_after_evaluation, socket) do
    Games.advance_round(socket.assigns.game_id)
    {:noreply, socket}
  end

  def handle_info({:game_updated, game}, socket) do
    # Update the player object and player split when game state changes
    player_id = socket.assigns.player_id
    player = if player_id, do: Enum.find(game.players, &(&1.id == player_id))
    player_split = split_players(game.players, player_id)

    {:noreply,
     socket
     |> assign(game: game)
     |> assign(player: player)
     |> assign(player_split: player_split)}
  end

  @spec split_players(list(map()), String.t() | nil) :: player_split()
  defp split_players(players, current_player_id) do
    unique_players = Enum.uniq_by(players, & &1.id)

    if current_player_id do
      current_player = Enum.find(unique_players, &(&1.id == current_player_id))
      other_players = List.delete(unique_players, current_player)
      %{current_player: current_player, other_players: other_players}
    else
      %{current_player: nil, other_players: unique_players}
    end
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

  def waiting_room(assigns) do
    ~H"""
    <div class="bg-ctp-mantle/80 backdrop-blur-sm rounded-lg shadow-lg shadow-ctp-crust/10 p-6 text-center">
      <h2 class="text-xl font-semibold mb-4 text-ctp-text">Waiting for Players</h2>
      <p class="mb-4 text-ctp-text flex items-center justify-center space-x-2">
        <span>Share this game code with your friends:</span>
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
      
    <!-- Show current players -->
      <%= if length(@game.players) > 0 do %>
        <div class="mt-4">
          <h3 class="text-sm font-medium text-ctp-subtext0 mb-2">Current Players:</h3>
          <div class="flex flex-wrap justify-center gap-2">
            <%= for player <- @game.players do %>
              <span class="px-2 py-1 bg-ctp-surface0 text-ctp-text rounded text-sm">
                {player.name}
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
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
      <div class="flex items-center space-x-2">
        <h1 class="text-lg font-bold text-ctp-text">{@game_id}</h1>
        <button
          id={"share-link-button-#{@game_id}"}
          phx-hook="Clipboard"
          phx-click="copy_link"
          phx-value-code={@game_id}
          class="p-1 rounded hover:bg-ctp-overlay0 focus:outline-none focus:ring-2 focus:ring-ctp-blue"
          aria-label="Copy game link"
          title="Copy game link"
        >
          <.icon name="hero-clipboard" class="w-4 h-4 text-ctp-subtext0" />
        </button>
      </div>
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

    <%= if @needs_player_info do %>
      <div class="bg-ctp-mantle/80 backdrop-blur-sm rounded-lg shadow-lg shadow-ctp-crust/10 p-6 mb-8">
        <h2 class="text-xl font-semibold mb-4 text-ctp-text">Join Game</h2>
        <p class="mb-4 text-ctp-subtext0">Enter your name to join this game:</p>
        <form phx-submit="join_game_with_name" class="flex gap-2">
          <input
            type="text"
            name="player_name"
            placeholder="Your name"
            required
            class="flex-1 px-3 py-2 bg-ctp-surface0 border border-ctp-overlay0 rounded-md text-ctp-text placeholder-ctp-subtext0 focus:outline-none focus:ring-2 focus:ring-ctp-blue"
          />
          <button
            type="submit"
            class="px-4 py-2 bg-ctp-blue hover:bg-ctp-sapphire text-ctp-base font-medium rounded-md transition-colors"
          >
            Join Game
          </button>
        </form>
      </div>
    <% end %>

    <CardComponents.hand_ranking_guide :if={@show_hand_guide} />
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
              <CardComponents.card card={card} size={@card_size} />
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
                color_classes(color)
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
        <CardComponents.card
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
              color_classes(@current_color),
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
                <CardComponents.card card={card} size="normal" />
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
end
