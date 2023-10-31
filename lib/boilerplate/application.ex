defmodule BoilerPlate.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Start the Ecto repository
      BoilerPlate.Repo,
      # Start the endpoint when the application starts
      BoilerPlateWeb.Endpoint,
      {BoilerPlate.QuantumScheduler, []},
      # Starts a worker by calling: BoilerPlate.Worker.start_link(arg)
      # {BoilerPlate.Worker, arg},
      {BoilerPlate.DueDateChecker, []},
      {BoilerPlate.WeeklyStatusChecker, []},
      # {BoilerPlate.TrialChecker, []},
      {BoilerPlate.DashboardCache, []},
      {BoilerPlate.FileCleaner, 1000},
      {Phoenix.PubSub, name: BoilerPlate.PubSub},
      BoilerPlateWeb.Presence,
      {BoilerPlate.ExpirationTracker, []}
    ]

    # Create the ETS cache for the internal telemetry collection
    :ets.new(:boilerplate_stats_plug, [:named_table, :public])

    # ETS table for currently running timers
    :ets.new(:boilerplate_assist_sendafter, [:named_table, :public])

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BoilerPlate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    BoilerPlateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
