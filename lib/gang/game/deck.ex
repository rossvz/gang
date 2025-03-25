defmodule Gang.Game.Deck do
  @moduledoc """
  Represents a deck of playing cards with operations for shuffling and dealing.
  """

  alias Gang.Game.Card

  @suits [:hearts, :diamonds, :clubs, :spades]
  @ranks 2..14

  @doc """
  Creates a new standard 52-card deck.
  """
  def new do
    for suit <- @suits, rank <- @ranks do
      %Card{rank: rank, suit: suit}
    end
  end

  @doc """
  Shuffles the deck randomly.
  """
  def shuffle(deck) do
    Enum.shuffle(deck)
  end

  @doc """
  Deals n cards from the deck, returning a tuple of {dealt_cards, remaining_deck}
  """
  def deal(deck, count) do
    {Enum.take(deck, count), Enum.drop(deck, count)}
  end

  @doc """
  Deals cards to a specified number of players, returning a tuple of
  {player_hands, remaining_deck}
  """
  def deal_to_players(deck, player_count, cards_per_player) do
    deal_to_players(deck, player_count, cards_per_player, [])
  end

  defp deal_to_players(deck, 0, _cards_per_player, hands) do
    {Enum.reverse(hands), deck}
  end

  defp deal_to_players(deck, player_count, cards_per_player, hands) do
    {hand, remaining_deck} = deal(deck, cards_per_player)
    deal_to_players(remaining_deck, player_count - 1, cards_per_player, [hand | hands])
  end
end
