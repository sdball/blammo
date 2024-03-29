defmodule Blammo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BlammoWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:blammo, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Blammo.PubSub},
      {Task.Supervisor, name: Blammo.LogSupervisor},
      Blammo.Servers,
      BlammoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Blammo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BlammoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
