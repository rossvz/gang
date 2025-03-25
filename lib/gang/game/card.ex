defmodule Gang.Game.Card do
  @moduledoc """
  Represents a standard playing card with a rank and a suit.
  """

  @type t :: %__MODULE__{
          rank: 2..14,
          suit: :hearts | :diamonds | :clubs | :spades
        }

  defstruct [:rank, :suit]

  @doc """
  Convert a card to a string representation
  """
  def to_string(%__MODULE__{rank: rank, suit: suit}) do
    rank_str =
      case rank do
        14 -> "A"
        13 -> "K"
        12 -> "Q"
        11 -> "J"
        10 -> "10"
        n -> "#{n}"
      end

    suit_str =
      case suit do
        :hearts -> "♥"
        :diamonds -> "♦"
        :clubs -> "♣"
        :spades -> "♠"
      end

    "#{rank_str}#{suit_str}"
  end

  @doc """
  Compare two cards by their ranks.
  Returns :gt if first card is higher, :lt if second card is higher, and :eq if equal.
  """
  def compare(%__MODULE__{rank: rank1}, %__MODULE__{rank: rank2}) do
    cond do
      rank1 > rank2 -> :gt
      rank1 < rank2 -> :lt
      true -> :eq
    end
  end
end
