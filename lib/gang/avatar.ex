defmodule Gang.Avatar do
  @moduledoc """
  Generates avatars using DiceBear's HTTP API.
  The avatar is deterministic based on the provided seed.
  """

  @doc """
  Generate an avatar URL using DiceBear's API with the given seed.
  """
  @spec generate(String.t() | nil) :: String.t()
  def generate(nil), do: generate("default-avatar")

  def generate(seed) when is_binary(seed) do
    # URL encode the seed to handle special characters
    encoded_seed = URI.encode(seed)

    # Catppuccin Macchiato colors (perfect contrast against dark UI)
    catppuccin_colors = [
      # macchiato-pink
      "f5bde6",
      # macchiato-mauve
      "c6a0f6",
      # macchiato-red
      "ed8796",
      # macchiato-maroon
      "ee99a0",
      # macchiato-peach
      "f5a97f",
      # macchiato-yellow
      "eed49f",
      # macchiato-green
      "a6da95",
      # macchiato-teal
      "8bd5ca",
      # macchiato-sky
      "91d7e3",
      # macchiato-sapphire
      "7dc4e4",
      # macchiato-blue
      "8aadf4",
      # macchiato-lavender
      "b7bdf8"
    ]

    background_colors = Enum.join(catppuccin_colors, ",")

    # Use DiceBear's fun-emoji style with Catppuccin theme colors
    "https://api.dicebear.com/9.x/fun-emoji/svg?seed=#{encoded_seed}&radius=30&backgroundColor=#{background_colors}"
  end
end
