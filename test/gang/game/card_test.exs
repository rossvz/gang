defmodule Gang.Game.CardTest do
  use ExUnit.Case

  alias Gang.Game.Card

  describe "to_string/1" do
    test "converts a card to its string representation" do
      assert Card.to_string(%Card{rank: 14, suit: :hearts}) == "A♥"
      assert Card.to_string(%Card{rank: 13, suit: :spades}) == "K♠"
      assert Card.to_string(%Card{rank: 12, suit: :diamonds}) == "Q♦"
      assert Card.to_string(%Card{rank: 11, suit: :clubs}) == "J♣"
      assert Card.to_string(%Card{rank: 10, suit: :hearts}) == "10♥"
      assert Card.to_string(%Card{rank: 2, suit: :diamonds}) == "2♦"
    end
  end

  describe "compare/2" do
    test "compares two cards by rank" do
      # Ace > King
      assert Card.compare(
               %Card{rank: 14, suit: :hearts},
               %Card{rank: 13, suit: :hearts}
             ) == :gt

      # King > Queen
      assert Card.compare(
               %Card{rank: 13, suit: :clubs},
               %Card{rank: 12, suit: :diamonds}
             ) == :gt

      # 2 < 3
      assert Card.compare(
               %Card{rank: 2, suit: :hearts},
               %Card{rank: 3, suit: :spades}
             ) == :lt

      # Same rank is equal
      assert Card.compare(
               %Card{rank: 10, suit: :hearts},
               %Card{rank: 10, suit: :diamonds}
             ) == :eq
    end
  end
end
