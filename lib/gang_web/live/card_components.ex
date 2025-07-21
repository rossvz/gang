defmodule GangWeb.CardComponents do
  @moduledoc false
  use GangWeb, :html

  alias Gang.Game.Card

  attr :card, Card, required: true
  attr :revealed, :boolean, default: true
  attr :size, :string, default: "normal"

  def card(assigns) do
    ~H"""
    <div class={[
      "group rounded-xl flex flex-col flex-shrink-0 items-center justify-between font-bold relative cursor-default",
      "transform transition-all duration-300 hover:scale-105 hover:-translate-y-1",
      "shadow-lg hover:shadow-xl border-2",
      case @size do
        "extra_small" -> "w-12 h-18 text-sm"
        "small" -> "w-14 h-20 p-2 text-sm"
        "normal" -> "w-[4.5rem] h-[6.5rem] p-2"
        "large" -> "w-20 h-28 p-3"
      end,
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
    ]}>
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
