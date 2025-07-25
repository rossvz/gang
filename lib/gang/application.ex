defmodule Gang.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GangWeb.Telemetry,
      # Gang.Repo,
      {DNSCluster, query: Application.get_env(:gang, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Gang.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Gang.Finch},
      # Start the Game Supervisor
      {Gang.Game.Supervisor, []},
      # Start to serve requests, typically the last entry
      GangWeb.Endpoint,
      Gang.Janitor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gang.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GangWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
