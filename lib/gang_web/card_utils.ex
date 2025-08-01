defmodule GangWeb.CardUtils do
  @moduledoc """
  Utilities for formatting card and hand-related text.
  """

  @doc """
  Properly pluralizes rank names for display in hand descriptions.
  
  Primary use case is converting singular rank names (from game data) to plural.
  Also handles already plural forms for backward compatibility.
  
  ## Examples
  
      iex> GangWeb.CardUtils.pluralize_rank("King")
      "Kings"
      
      iex> GangWeb.CardUtils.pluralize_rank("Kings")
      "Kings"
      
      iex> GangWeb.CardUtils.pluralize_rank("10")
      "10s"
  """
  def pluralize_rank(rank) do
    case rank do
      # Handle singular ranks (primary use case from game data)
      "King" -> "Kings"
      "Queen" -> "Queens"
      "Jack" -> "Jacks"
      "Ace" -> "Aces"
      # Handle already plural ranks (backward compatibility)
      "Kings" -> "Kings"
      "Queens" -> "Queens"
      "Jacks" -> "Jacks"
      "Aces" -> "Aces"
      # Numbers just add 's'
      num -> "#{num}s"
    end
  end
end