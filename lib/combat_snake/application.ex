defmodule CombatSnake.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CombatSnakeWeb.Telemetry,
      CombatSnake.Repo,
      {DNSCluster, query: Application.get_env(:combat_snake, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CombatSnake.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CombatSnake.Finch},
      # Start a worker by calling: CombatSnake.Worker.start_link(arg)
      # {CombatSnake.Worker, arg},
      # Start to serve requests, typically the last entry
      CombatSnakeWeb.Endpoint,
      CombatSnake.Game.GameServer
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CombatSnake.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CombatSnakeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
