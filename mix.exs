defmodule BoilerPlate.MixProject do
  use Mix.Project

  def project do
    [
      app: :boilerplate,
      version: "0.1.0",
      elixir: "~> 1.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        warnings_as_errors: true
      ],
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      default_release: :boilerplate,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls, export: "cov"],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      releases: [
        boilerplate: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar],
          validate_compile_env: false,
          applications: [
            runtime_tools: :permanent,
            inets: :permanent,
            ssl: :permanent,
            briefly: :permanent,
            guardian: :permanent,
            fun_with_flags: :permanent,
            timex: :permanent,
            logger: :permanent,
            hcaptcha: :permanent
          ],
          version: "boilerplate-42"
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BoilerPlate.Application, []},
      extra_applications: [
        :inets,
        :ssl,
        :briefly,
        :ex_twilio,
        :timex,
        :logger,
        :runtime_tools,
        :hcaptcha
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/boilerplate_web/common_setup.exs", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.16.4"},
      {:phoenix_live_dashboard, "~> 0.5"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.1"},
      {:elixir_uuid, "~> 1.2"},
      {:arc, "~> 0.11.0"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.17.0"},
      {:poison, "~> 3.1"},
      {:sweet_xml, "~> 0.6"},
      {:guardian, "~> 2.3"},
      {:bamboo, "~> 1.3"},
      {:stripity_stripe, "~> 2.7.2"},
      {:httpoison, "~> 1.6"},
      {:timex, "~> 3.0"},
      {:briefly, "~> 0.3"},
      {:segment, "~> 0.2.2"},
      {:fun_with_flags, "1.7.0"},
      {:fun_with_flags_ui, "~> 0.7.2"},
      {:redix, "~> 1.1.2"},
      {:ex_twilio, "~> 0.8.1"},
      {:hcaptcha, "~> 0.0.1"},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.8", only: [:dev]},
      {:remote_ip, "~> 1.0"},
      {:enum_type, "~> 1.1.2"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:nimble_totp, "~> 0.2.0"},
      {:ex_machina, "~> 2.7.0", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:oauth2, "~> 2.0"},
      {:tesla, "~> 1.4"},
      {:joken, "~> 2.6"},
      {:google_certs, "~> 1.0"},
      {:quantum, "~> 3.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.setup_nomad": [
        "ecto.create",
        "ecto.migrate",
        "run priv/repo/seeds_nomad.exs",
        "run priv/repo/seeds_nomad_extra.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.reset_nomad": ["ecto.drop", "ecto.setup_nomad"],
      "seed.feature_flags": ["run priv/repo/seed_feature_flags.exs"],
      test: ["ecto.create --quiet", "ecto.migrate", "test"],
      "test.coveralls": ["coveralls"]
    ]
  end
end
