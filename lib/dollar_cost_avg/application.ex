defmodule DollarCostAvg.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DollarCostAvgWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:dollar_cost_avg, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DollarCostAvg.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DollarCostAvg.Finch},
      # Start a worker by calling: DollarCostAvg.Worker.start_link(arg)
      # {DollarCostAvg.Worker, arg},
      # Start to serve requests, typically the last entry
      DollarCostAvgWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DollarCostAvg.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DollarCostAvgWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
