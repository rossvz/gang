defmodule Gang.Game.Player do
  @moduledoc """
  Represents a player in the game with their cards and claimed rank chips.
  """

  alias Gang.Game.{Card, RankChip}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          cards: list(Card.t()),
          rank_chips: list(RankChip.t()),
          connected: boolean(),
          last_activity: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    cards: [],
    rank_chips: [],
    connected: true,
    last_activity: nil
  ]

  @doc """
  Creates a new player with the given name.
  """
  def new(name) when is_binary(name) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      name: name,
      last_activity: DateTime.utc_now()
    }
  end

  @doc """
  Marks a player as connected.
  """
  def connect(player) do
    %__MODULE__{player | connected: true, last_activity: DateTime.utc_now()}
  end

  @doc """
  Marks a player as disconnected.
  """
  def disconnect(player) do
    %__MODULE__{player | connected: false}
  end

  @doc """
  Updates the player's activity timestamp.
  """
  def touch(player) do
    %__MODULE__{player | last_activity: DateTime.utc_now()}
  end

  @doc """
  Deal cards to the player.
  """
  def deal_cards(player, cards) do
    %__MODULE__{player | cards: cards}
  end
end
