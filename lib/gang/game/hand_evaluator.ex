defmodule Gang.Game.HandEvaluator do
  @moduledoc """
  Evaluates poker hands to determine their strength.
  """

  alias Gang.Game.Card

  @type hand_type ::
          :high_card
          | :pair
          | :two_pair
          | :three_of_a_kind
          | :straight
          | :flush
          | :full_house
          | :four_of_a_kind
          | :straight_flush
          | :royal_flush

  @type hand_result :: {hand_type, list(Card.t()), map()}

  @hand_rankings [
    :high_card,
    :pair,
    :two_pair,
    :three_of_a_kind,
    :straight,
    :flush,
    :full_house,
    :four_of_a_kind,
    :straight_flush,
    :royal_flush
  ]

  @doc """
  Evaluates the best 5-card poker hand from a player's 2 cards and the community cards.
  Returns a tuple containing the hand type and the cards making up the hand.
  """
  def evaluate(player_cards, community_cards) do
    cards = player_cards ++ community_cards

    # Generate all possible 5-card combinations from the 7 cards
    combinations = combinations(cards, 5)

    # Evaluate each combination and find the best hand
    combinations
    |> Enum.map(&evaluate_hand/1)
    |> Enum.max_by(fn {hand_type, _cards, _details} ->
      Enum.find_index(@hand_rankings, &(&1 == hand_type))
    end)
  end

  @doc """
  Generates all possible k-sized combinations from a list
  """
  def combinations(_list, 0), do: [[]]
  def combinations([], _k), do: []

  def combinations([head | tail], k) do
    Enum.map(combinations(tail, k - 1), fn combo -> [head | combo] end) ++
      combinations(tail, k)
  end

  @doc """
  Evaluates a 5-card hand and returns its type with tie-breaker details
  """
  def evaluate_hand(cards) when length(cards) == 5 do
    sorted_cards = Enum.sort_by(cards, & &1.rank, :desc)

    cond do
      is_royal_flush(sorted_cards) -> {:royal_flush, sorted_cards, %{}}
      is_straight_flush(sorted_cards) -> {:straight_flush, sorted_cards, get_straight_details(sorted_cards)}
      is_four_of_a_kind(sorted_cards) -> {:four_of_a_kind, sorted_cards, get_four_of_a_kind_details(sorted_cards)}
      is_full_house(sorted_cards) -> {:full_house, sorted_cards, get_full_house_details(sorted_cards)}
      is_flush(sorted_cards) -> {:flush, sorted_cards, get_high_card_details(sorted_cards)}
      is_straight(sorted_cards) -> {:straight, sorted_cards, get_straight_details(sorted_cards)}
      is_three_of_a_kind(sorted_cards) -> {:three_of_a_kind, sorted_cards, get_three_of_a_kind_details(sorted_cards)}
      is_two_pair(sorted_cards) -> {:two_pair, sorted_cards, get_two_pair_details(sorted_cards)}
      is_pair(sorted_cards) -> {:pair, sorted_cards, get_pair_details(sorted_cards)}
      true -> {:high_card, sorted_cards, get_high_card_details(sorted_cards)}
    end
  end

  @doc """
  Compares two poker hands and returns :gt if the first hand is better,
  :lt if the second hand is better, and :eq if they are equal.
  """
  def compare_hands({type1, _cards1, _details1}, {type2, _cards2, _details2}) when type1 != type2 do
    rank1 = Enum.find_index(@hand_rankings, &(&1 == type1))
    rank2 = Enum.find_index(@hand_rankings, &(&1 == type2))

    cond do
      rank1 > rank2 -> :gt
      rank1 < rank2 -> :lt
      true -> :eq
    end
  end

  def compare_hands({same_type, cards1, _details1}, {same_type, cards2, _details2}) do
    # For hands of the same type, we need to compare kickers
    # This is a simplified version - a complete implementation would handle
    # all the tie-breaking rules for each hand type
    compare_high_cards(cards1, cards2)
  end

  # Helper functions for evaluating hand types

  defp is_royal_flush(cards) do
    is_straight_flush(cards) && Enum.at(cards, 0).rank == 14
  end

  defp is_straight_flush(cards) do
    is_flush(cards) && is_straight(cards)
  end

  defp is_four_of_a_kind(cards) do
    cards
    |> Enum.group_by(& &1.rank)
    |> Map.values()
    |> Enum.any?(fn group -> length(group) == 4 end)
  end

  defp is_full_house(cards) do
    groups =
      cards
      |> Enum.group_by(& &1.rank)
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.sort(:desc)

    groups == [3, 2]
  end

  defp is_flush(cards) do
    length(Enum.uniq_by(cards, & &1.suit)) == 1
  end

  defp is_straight(cards) do
    ranks = cards |> Enum.map(& &1.rank) |> Enum.sort(:desc)

    # Handle special case of A-5-4-3-2 straight (A can be low)
    if ranks == [14, 5, 4, 3, 2] do
      true
    else
      ranks
      |> Enum.zip(tl(ranks))
      |> Enum.all?(fn {a, b} -> a == b + 1 end)
    end
  end

  defp is_three_of_a_kind(cards) do
    cards
    |> Enum.group_by(& &1.rank)
    |> Map.values()
    |> Enum.any?(fn group -> length(group) == 3 end)
  end

  defp is_two_pair(cards) do
    pairs =
      cards
      |> Enum.group_by(& &1.rank)
      |> Map.values()
      |> Enum.filter(fn group -> length(group) == 2 end)

    length(pairs) == 2
  end

  defp is_pair(cards) do
    cards
    |> Enum.group_by(& &1.rank)
    |> Map.values()
    |> Enum.any?(fn group -> length(group) == 2 end)
  end

  defp compare_high_cards(cards1, cards2) do
    ranks1 = cards1 |> Enum.map(& &1.rank) |> Enum.sort(:desc)
    ranks2 = cards2 |> Enum.map(& &1.rank) |> Enum.sort(:desc)

    compare_ranks(ranks1, ranks2)
  end

  defp compare_ranks([], []), do: :eq

  defp compare_ranks([r1 | rs1], [r2 | rs2]) do
    cond do
      r1 > r2 -> :gt
      r1 < r2 -> :lt
      true -> compare_ranks(rs1, rs2)
    end
  end

  # Helper functions for getting tie-breaker details

  defp get_high_card_details(cards) do
    high_card = Enum.max_by(cards, & &1.rank)
    %{high_card: rank_to_string(high_card.rank)}
  end

  defp get_pair_details(cards) do
    {pair_rank, kickers} = get_pair_and_kickers(cards)
    kicker = Enum.max_by(kickers, & &1.rank)
    %{pair_rank: rank_to_string(pair_rank), kicker: rank_to_string(kicker.rank)}
  end

  defp get_two_pair_details(cards) do
    pairs = get_pairs(cards)
    high_pair = Enum.max_by(pairs, & &1.rank)
    low_pair = Enum.min_by(pairs, & &1.rank)
    kicker = cards |> Enum.reject(&(&1.rank in [high_pair.rank, low_pair.rank])) |> Enum.max_by(& &1.rank)

    %{
      high_pair: rank_to_string(high_pair.rank),
      low_pair: rank_to_string(low_pair.rank),
      kicker: rank_to_string(kicker.rank)
    }
  end

  defp get_three_of_a_kind_details(cards) do
    three_rank = get_three_of_a_kind_rank(cards)
    kickers = cards |> Enum.reject(&(&1.rank == three_rank)) |> Enum.sort_by(& &1.rank, :desc)
    high_kicker = Enum.at(kickers, 0)
    %{three_rank: rank_to_string(three_rank), kicker: rank_to_string(high_kicker.rank)}
  end

  defp get_straight_details(cards) do
    high_card = if is_wheel_straight?(cards), do: 5, else: cards |> Enum.max_by(& &1.rank) |> Map.get(:rank)
    %{high_card: rank_to_string(high_card)}
  end

  defp get_full_house_details(cards) do
    three_rank = get_three_of_a_kind_rank(cards)
    pair_rank = get_pair_rank(cards, three_rank)
    %{three_rank: rank_to_string(three_rank), pair_rank: rank_to_string(pair_rank)}
  end

  defp get_four_of_a_kind_details(cards) do
    four_rank = get_four_of_a_kind_rank(cards)
    kicker = cards |> Enum.reject(&(&1.rank == four_rank)) |> Enum.at(0)
    %{four_rank: rank_to_string(four_rank), kicker: rank_to_string(kicker.rank)}
  end

  defp get_pair_and_kickers(cards) do
    grouped = Enum.group_by(cards, & &1.rank)
    {pair_rank, _} = Enum.find(grouped, fn {_rank, group} -> length(group) == 2 end)
    kickers = Enum.reject(cards, &(&1.rank == pair_rank))
    {pair_rank, kickers}
  end

  defp get_pairs(cards) do
    cards
    |> Enum.group_by(& &1.rank)
    |> Enum.filter(fn {_rank, group} -> length(group) == 2 end)
    |> Enum.map(fn {rank, _group} -> %{rank: rank} end)
  end

  defp get_three_of_a_kind_rank(cards) do
    cards
    |> Enum.group_by(& &1.rank)
    |> Enum.find(fn {_rank, group} -> length(group) == 3 end)
    |> elem(0)
  end

  defp get_pair_rank(cards, exclude_rank) do
    cards
    |> Enum.reject(&(&1.rank == exclude_rank))
    |> Enum.group_by(& &1.rank)
    |> Enum.find(fn {_rank, group} -> length(group) == 2 end)
    |> elem(0)
  end

  defp get_four_of_a_kind_rank(cards) do
    cards
    |> Enum.group_by(& &1.rank)
    |> Enum.find(fn {_rank, group} -> length(group) == 4 end)
    |> elem(0)
  end

  defp is_wheel_straight?(cards) do
    ranks = cards |> Enum.map(& &1.rank) |> Enum.sort()
    ranks == [2, 3, 4, 5, 14]
  end

  defp rank_to_string(14), do: "Ace"
  defp rank_to_string(13), do: "King"
  defp rank_to_string(12), do: "Queen"
  defp rank_to_string(11), do: "Jack"
  defp rank_to_string(rank) when rank >= 2 and rank <= 10, do: Integer.to_string(rank)
end
