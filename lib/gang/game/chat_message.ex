defmodule Gang.Game.ChatMessage do
  @moduledoc """
  Represents a chat message within a game.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          player_id: String.t(),
          player_name: String.t(),
          player_avatar: String.t(),
          message: String.t(),
          timestamp: DateTime.t()
        }

  defstruct [
    :id,
    :player_id,
    :player_name,
    :player_avatar,
    :message,
    :timestamp
  ]

  @doc """
  Creates a new chat message.
  """
  def new(player_id, player_name, player_avatar, message) do
    %__MODULE__{
      id: generate_id(),
      player_id: player_id,
      player_name: player_name,
      player_avatar: player_avatar,
      message: String.slice(message, 0, 140), # Enforce 140 character limit
      timestamp: DateTime.utc_now()
    }
  end

  # Generate a simple unique ID
  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  @doc """
  Formats timestamp for display in chat.
  """
  def format_timestamp(%__MODULE__{timestamp: timestamp}) do
    try do
      Calendar.strftime(timestamp, "%I:%M %p")
    rescue
      _ -> 
        # Fallback to simple time formatting
        timestamp
        |> DateTime.to_time()
        |> Time.to_string()
        |> String.slice(0, 5)
    end
  end
end