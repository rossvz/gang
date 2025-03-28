defmodule Gang.Game.Supervisor do
  @moduledoc """
  Supervisor for Gang game processes.
  """

  use Supervisor
  require Logger

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Gang.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Gang.GameDynamicSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc """
  Creates a new game with a unique code.
  """
  def create_game do
    code = generate_unique_code()

    case DynamicSupervisor.start_child(
           Gang.GameDynamicSupervisor,
           {Gang.Game.Game, code}
         ) do
      {:ok, _pid} -> {:ok, code}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all active games.
  Returns a list of {code, pid} tuples.
  """
  def list_games do
    Registry.select(Gang.GameRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Gets the PID of a game by its code.
  """
  def get_game_pid(code) do
    case Registry.lookup(Gang.GameRegistry, code) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  @doc """
  Checks if a game exists with the given code.
  """
  def game_exists?(code) do
    case Registry.lookup(Gang.GameRegistry, code) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Terminates a game process.
  """
  def terminate_game(code) do
    case Registry.lookup(Gang.GameRegistry, code) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(Gang.GameDynamicSupervisor, pid)

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Generates a unique 4-character alphanumeric code.
  """
  def generate_unique_code do
    code = random_code()

    if game_exists?(code) do
      # Recursively try again if the code is already in use
      generate_unique_code()
    else
      code
    end
  end

  @doc """
  Generates a random 4-character alphanumeric code.
  """
  def random_code do
    chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

    0..3
    |> Enum.map(fn _ -> :rand.uniform(String.length(chars)) - 1 end)
    |> Enum.map(fn idx -> String.at(chars, idx) end)
    |> Enum.join("")
  end
end
