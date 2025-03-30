defmodule Gang.Game.DeckTest do
  use ExUnit.Case

  alias Gang.Game.Deck

  describe "new/0" do
    test "creates a standard 52-card deck" do
      deck = Deck.new()
      assert length(deck) == 52

      # Check that the deck has all ranks and suits
      ranks = deck |> Enum.map(& &1.rank) |> Enum.sort() |> Enum.uniq()
      suits = deck |> Enum.map(& &1.suit) |> Enum.sort() |> Enum.uniq()

      assert ranks == Enum.to_list(2..14)
      assert suits == [:clubs, :diamonds, :hearts, :spades]
    end
  end

  describe "shuffle/1" do
    test "shuffles the cards in the deck" do
      original_deck = Deck.new()
      shuffled_deck = Deck.shuffle(original_deck)

      # Should have the same cards
      assert Enum.sort_by(original_deck, fn card -> {card.suit, card.rank} end) ==
               Enum.sort_by(shuffled_deck, fn card -> {card.suit, card.rank} end)

      # But likely in a different order
      # Note: This is a probabilistic test, but the chance of getting the same order is 1/52!
      assert original_deck != shuffled_deck
    end
  end

  describe "deal/2" do
    test "deals specified number of cards" do
      deck = Deck.new()
      {dealt, remaining} = Deck.deal(deck, 5)

      assert length(dealt) == 5
      assert length(remaining) == 47
      assert dealt ++ remaining == deck
    end
  end

  describe "deal_to_players/3" do
    test "deals cards to multiple players" do
      deck = Deck.new()
      player_count = 4
      cards_per_player = 2

      {hands, remaining} = Deck.deal_to_players(deck, player_count, cards_per_player)

      assert length(hands) == player_count
      assert Enum.all?(hands, fn hand -> length(hand) == cards_per_player end)
      assert length(remaining) == 52 - player_count * cards_per_player

      # All cards should be accounted for
      all_dealt_cards = List.flatten(hands)
      assert all_dealt_cards ++ remaining == deck
    end
  end
end
