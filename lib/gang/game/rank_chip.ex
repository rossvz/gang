defmodule Gang.Game.RankChip do
  @moduledoc """
  Represents a rank chip that players claim during each round.
  """

  @type color :: :white | :yellow | :orange | :red
  @type t :: %__MODULE__{
          rank: integer(),
          color: color()
        }

  defstruct [:rank, :color]

  @doc """
  Creates a new set of rank chips for a round with the specified color.
  The count parameter determines how many chips to create (1 to count).
  """
  def new_set(color, count) do
    Enum.map(1..count, fn rank ->
      %__MODULE__{rank: rank, color: color}
    end)
  end

  @doc """
  Maps a round number to the corresponding chip color
  """
  def color_for_round(1), do: :white
  def color_for_round(2), do: :yellow
  def color_for_round(3), do: :orange
  def color_for_round(4), do: :red
  def color_for_round(_), do: :white
end
