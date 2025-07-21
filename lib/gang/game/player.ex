defmodule Gang.Game.Player do
  @moduledoc """
  Represents a player in the game with their cards and claimed rank chips.
  """

  alias Gang.Game.Card
  alias Gang.Game.RankChip
  alias Gang.Avatar

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          avatar: String.t() | nil,
          cards: list(Card.t()),
          rank_chips: list(RankChip.t()),
          connected: boolean(),
          last_activity: DateTime.t()
        }

  defstruct [
    :id,
    :name,
    :avatar,
    cards: [],
    rank_chips: [],
    connected: true,
    last_activity: nil
  ]

  @doc """
  Creates a new player with the given name.
  """
  def new(name, id \\ Ecto.UUID.generate()) do
    %__MODULE__{
      id: id,
      name: name,
      avatar: Avatar.generate(id),
      last_activity: DateTime.utc_now()
    }
  end

  @doc """
  Marks a player as connected.
  """
  def connect(player) do
    %{player | connected: true, last_activity: DateTime.utc_now()}
  end

  @doc """
  Marks a player as disconnected.
  """
  def disconnect(player) do
    %{player | connected: false}
  end

  @doc """
  Updates the player's activity timestamp.
  """
  def touch(player) do
    %{player | last_activity: DateTime.utc_now()}
  end

  @doc """
  Deal cards to the player.
  """
  def deal_cards(player, cards) do
    %{player | cards: cards}
  end
end
