defmodule Gang.Avatar do
  @moduledoc """
  Generates simple identicon style avatars as SVG data URIs.
  The avatar is deterministic based on the provided seed.
  """

  use Bitwise

  @doc """
  Generate an avatar as a data URI SVG using the given seed.
  """
  @spec generate(String.t()) :: String.t()
  def generate(seed) when is_binary(seed) do
    hash = :crypto.hash(:sha256, seed)
    color = "#" <> Base.encode16(:binary.part(hash, 0, 3), case: :lower)

    bits =
      for <<byte <- hash>>, reduce: [] do
        acc ->
          for i <- 0..7, reduce: acc do
            acc2 -> [(byte >>> i &&& 1) | acc2]
          end
      end
      |> Enum.reverse()

    pattern_bits = Enum.slice(bits, 0, 15)
    square = 20

    rects =
      pattern_bits
      |> Enum.with_index()
      |> Enum.flat_map(fn {bit, idx} ->
        if bit == 1 do
          row = div(idx, 3)
          col = rem(idx, 3)
          base_x = col * square
          mirror_x = (4 - col) * square
          y = row * square

          [
            ~s(<rect x="#{base_x}" y="#{y}" width="#{square}" height="#{square}" />),
            if col != 2 do
              ~s(<rect x="#{mirror_x}" y="#{y}" width="#{square}" height="#{square}" />)
            end
          ]
        else
          []
        end
      end)
      |> Enum.filter(& &1)
      |> Enum.join()

    svg = """
    <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 #{square * 5} #{square * 5}' shape-rendering='crispEdges'>
      <rect width='100%' height='100%' fill='white'/>
      <g fill='#{color}'>#{rects}</g>
    </svg>
    """

    "data:image/svg+xml;utf8," <> URI.encode(svg)
  end
end
