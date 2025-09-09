defmodule Gang.MixProject do
  use Mix.Project

  def project do
    [
      app: :gang,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Gang.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:lazy_html, ">= 0.0.0", only: :test},
      {:deps_changelog, "~> 0.3", only: :dev, runtime: false},
      {:styler, "~> 1.5"},
      {:phoenix, "~> 1.8.0"},
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, "~> 0.37", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:live_debugger, "~> 0.3", only: [:dev]},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons", tag: "v2.2.0", sparse: "optimized", app: false, compile: false, depth: 1},
      {:swoosh, "~> 1.19"},
      {:finch, "~> 0.20"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.3"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2"},
      {:bandit, "~> 1.7"},
      {:igniter, "~> 0.6.21"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind gang", "esbuild gang"],
      "assets.deploy": [
        "tailwind gang --minify",
        "esbuild gang --minify",
        "phx.digest"
      ],
      update: [
        # Isolated processes/Mix runners seem to work best when shuffling deps
        "cmd mix deps.changelog --before",
        "cmd mix deps.update igniter",
        "cmd mix igniter.upgrade --all",
        "cmd mix deps.changelog --after",
        fn _args ->
          Mix.shell().info("Run `mix igniter.apply_upgrades igniter:old_version:new_version` to finish igniter update!")
        end
      ]
    ]
  end
end
