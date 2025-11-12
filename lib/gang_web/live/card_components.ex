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

  def how_to_play_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-ctp-base/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div class="bg-ctp-mantle rounded-2xl shadow-xl w-full max-w-3xl max-h-[80vh] overflow-y-auto">
        <div class="sticky top-0 bg-ctp-mantle z-10 border-b border-ctp-surface0 px-6 py-4">
          <div class="flex justify-between items-center">
            <h2 class="text-2xl font-bold text-ctp-text">How to Play The Gang</h2>
            <button
              class="text-ctp-subtext0 hover:text-ctp-text transition-colors p-2 hover:bg-ctp-surface0 rounded-lg"
              phx-click="toggle_how_to_play"
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
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        </div>

        <div class="p-6 space-y-6">
          <div class="bg-ctp-surface0/50 rounded-xl p-5 border border-ctp-surface1">
            <div class="flex items-start gap-3 mb-3">
              <div class="p-2 bg-ctp-blue/20 rounded-lg">
                <svg class="w-5 h-5 text-ctp-blue" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9 6a3 3 0 11-6 0 3 3 0 016 0zM17 6a3 3 0 11-6 0 3 3 0 016 0zM12.93 17c.046-.327.07-.66.07-1a6.97 6.97 0 00-1.5-4.33A5 5 0 0119 16v1h-6.07zM6 11a5 5 0 015 5v1H1v-1a5 5 0 015-5z" />
                </svg>
              </div>
              <div>
                <h3 class="text-xl font-bold text-ctp-text mb-2">Game Overview</h3>
                <p class="text-ctp-subtext0">
                  The Gang is a cooperative multiplayer poker game for 3-6 players. Work together to correctly rank your hands across 4 rounds of Texas Hold'em poker. Win by ensuring the team's hands are ranked in the correct order!
                </p>
              </div>
            </div>
          </div>

          <div class="space-y-4">
            <div class="bg-gradient-to-br from-ctp-surface0/50 to-ctp-surface1/30 rounded-xl p-5 border border-ctp-yellow/30">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0 w-10 h-10 bg-ctp-yellow/20 rounded-lg flex items-center justify-center">
                  <span class="text-xl font-bold text-ctp-yellow">1</span>
                </div>
                <div class="flex-1">
                  <h4 class="text-lg font-bold text-ctp-text mb-2">Round 1: Preflop (White Chips)</h4>
                  <p class="text-ctp-subtext0 mb-3">
                    Each player receives 2 hole cards. Without communicating your hand, claim a white Rank Chip (1, 2, 3, 4, etc.) representing how strong you think your hand is relative to other players.
                  </p>
                  <ul class="text-sm text-ctp-subtext0 space-y-1 ml-4">
                    <li class="flex items-start gap-2">
                      <span class="text-ctp-yellow">•</span>
                      <span>Take an unclaimed rank chip from the middle</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="text-ctp-yellow">•</span>
                      <span>Take a rank chip from another player</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="text-ctp-yellow">•</span>
                      <span>Put your rank chip back in the middle</span>
                    </li>
                    <li class="flex items-start gap-2">
                      <span class="text-ctp-yellow">•</span>
                      <span>Round ends when all chips are claimed</span>
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-br from-ctp-surface0/50 to-ctp-surface1/30 rounded-xl p-5 border border-ctp-peach/30">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0 w-10 h-10 bg-ctp-peach/20 rounded-lg flex items-center justify-center">
                  <span class="text-xl font-bold text-ctp-peach">2</span>
                </div>
                <div class="flex-1">
                  <h4 class="text-lg font-bold text-ctp-text mb-2">Round 2: The Flop (Yellow Chips)</h4>
                  <p class="text-ctp-subtext0">
                    Three community cards are dealt face up. Players reassess their hands and claim yellow rank chips. Previous white chips remain visible, helping the team infer hand strength changes.
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-br from-ctp-surface0/50 to-ctp-surface1/30 rounded-xl p-5 border border-ctp-mauve/30">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0 w-10 h-10 bg-ctp-mauve/20 rounded-lg flex items-center justify-center">
                  <span class="text-xl font-bold text-ctp-mauve">3</span>
                </div>
                <div class="flex-1">
                  <h4 class="text-lg font-bold text-ctp-text mb-2">Round 3: The Turn (Orange Chips)</h4>
                  <p class="text-ctp-subtext0">
                    One more community card is added. Another round of ranking with orange chips. The pressure builds!
                  </p>
                </div>
              </div>
            </div>

            <div class="bg-gradient-to-br from-ctp-surface0/50 to-ctp-surface1/30 rounded-xl p-5 border border-ctp-red/30">
              <div class="flex items-start gap-3">
                <div class="flex-shrink-0 w-10 h-10 bg-ctp-red/20 rounded-lg flex items-center justify-center">
                  <span class="text-xl font-bold text-ctp-red">4</span>
                </div>
                <div class="flex-1">
                  <h4 class="text-lg font-bold text-ctp-text mb-2">Round 4: The River (Red Chips)</h4>
                  <p class="text-ctp-subtext0">
                    The final community card is revealed. Final ranking with red chips. This is your last chance to get it right!
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-ctp-surface0/50 rounded-xl p-5 border border-ctp-green/30">
            <div class="flex items-start gap-3">
              <div class="p-2 bg-ctp-green/20 rounded-lg">
                <svg class="w-5 h-5 text-ctp-green" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                </svg>
              </div>
              <div>
                <h3 class="text-xl font-bold text-ctp-text mb-2">Win Condition</h3>
                <p class="text-ctp-subtext0 mb-3">
                  After the river, players reveal their hands in order (red chip 1, 2, 3, etc.). You win if hands are correctly ranked from weakest to strongest!
                </p>
                <div class="flex gap-4 text-sm">
                  <div class="flex items-center gap-2">
                    <div class="w-8 h-8 bg-ctp-green/20 rounded flex items-center justify-center">
                      <span class="text-ctp-green font-bold">✓</span>
                    </div>
                    <span class="text-ctp-subtext0">Correct = Vault (3 to win!)</span>
                  </div>
                  <div class="flex items-center gap-2">
                    <div class="w-8 h-8 bg-ctp-red/20 rounded flex items-center justify-center">
                      <span class="text-ctp-red font-bold">✗</span>
                    </div>
                    <span class="text-ctp-subtext0">Wrong = Alarm (3 loses!)</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-ctp-surface0/30 rounded-xl p-5 border border-ctp-surface1">
            <h3 class="text-lg font-bold text-ctp-text mb-3">Key Strategy Tips</h3>
            <ul class="text-sm text-ctp-subtext0 space-y-2">
              <li class="flex items-start gap-2">
                <span class="text-ctp-blue">→</span>
                <span>Watch how other players move their chips between rounds</span>
              </li>
              <li class="flex items-start gap-2">
                <span class="text-ctp-blue">→</span>
                <span>Remember: only the RED (final) chip ranking matters for winning</span>
              </li>
              <li class="flex items-start gap-2">
                <span class="text-ctp-blue">→</span>
                <span>Player with chip "1" should have the WEAKEST hand, not the strongest</span>
              </li>
              <li class="flex items-start gap-2">
                <span class="text-ctp-blue">→</span>
                <span>Chip movement is communication - use it wisely!</span>
              </li>
            </ul>
          </div>
        </div>
      </div>
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
