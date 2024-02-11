defmodule Blammo.OtherServers do
  @moduledoc """
  Blammo.OtherServers provides functions to discover and interact with other servers.
  """

  use GenServer

  defstruct servers: %{}

  @doc """
  Lists other known servers.
  """
  def list() do
    GenServer.call(__MODULE__, :servers)
  end

  @doc """
  Lists files available at the given other server `nodename`

  Returns `{:ok, files}` if successful or `{:error, :no_connection}` if
  there is no connection to the other server. (i.e. it's gone offline)
  """
  def files(nodename) do
    nodename
    |> Node.ping()
    |> case do
      :pong ->
        files =
          nodename
          |> server_pid()
          |> GenServer.call(:files)

        {:ok, files}

      :pang ->
        {:error, :no_connection}
    end
  end

  @doc """
  Sends a GenServer call to the given `nodename` with the `:tail_log` message.

  If the arguments are given with `filter` before `lines` then the response will
  be the log contents filtered to the latest `lines` count containing `filter`.

  If the arguments are given with `lines` before `filter` then the response will
  be the log contents limited to the `lines` count and then filtered to `filter`.
  """
  def tail_log(nodename, filename, filter, lines) when is_integer(lines) do
    nodename
    |> server_pid()
    |> GenServer.call({:tail_log, filename, filter, lines}, 600_000)
  end

  def tail_log(nodename, filename, lines, filter) when is_integer(lines) do
    nodename
    |> server_pid()
    |> GenServer.call({:tail_log, filename, lines, filter}, 10_000)
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :no_args, name: __MODULE__)
  end

  def init(:no_args) do
    state = %__MODULE__{}
    {:ok, state, {:continue, :join}}
  end

  @doc """
  Joins the collective of servers.

  - Connects to the mesh network
  - Subscribes to the server topic
  - Begins the heartbeat

  Continuation from `init/1`
  """
  def handle_continue(:join, %__MODULE__{} = state) do
    connect_to_known_peers(1..4)
    subscribe_to_servers()
    heartbeat()
    {:noreply, state}
  end

  def handle_info(:heartbeat, %__MODULE__{} = state) do
    heartbeat()
    {:noreply, state}
  end

  def handle_info({:server, nodename, pid}, %__MODULE__{} = state) do
    updated_servers = Map.put(state.servers, nodename, pid)
    {:noreply, %{state | servers: updated_servers}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def handle_call(:servers, _from, %__MODULE__{} = state) do
    {:reply, state.servers, state}
  end

  def handle_call(:files, _from, %__MODULE__{} = state) do
    {:reply, Blammo.LogConsumer.log_files(), state}
  end

  def handle_call({:tail_log, filename, filter, lines}, from, %__MODULE__{} = state)
      when is_integer(lines) do
    Task.async(fn ->
      options =
        Blammo.LogConsumer.Options.build!(%{
          filename: filename,
          filter: filter,
          lines: lines
        })

      result = Blammo.LogConsumer.consume_filter_first(options)
      GenServer.reply(from, result)
    end)

    {:noreply, state}
  end

  def handle_call({:tail_log, filename, lines, filter}, from, %__MODULE__{} = state)
      when is_integer(lines) do
    Task.async(fn ->
      options =
        Blammo.LogConsumer.Options.build!(%{
          filename: filename,
          filter: filter,
          lines: lines
        })

      result = Blammo.LogConsumer.consume_lines_first(options)
      GenServer.reply(from, result)
    end)

    {:noreply, state}
  end

  defp connect_to_known_peers(range) do
    range
    |> Enum.each(fn n ->
      Node.connect(:"node#{n}@localhost")
    end)
  end

  defp subscribe_to_servers() do
    Phoenix.PubSub.subscribe(Blammo.PubSub, "servers")
  end

  defp heartbeat() do
    Phoenix.PubSub.broadcast(Blammo.PubSub, "servers", {:server, Node.self(), self()})
    Process.send_after(self(), :heartbeat, 5000)
  end

  defp server_pid(nodename) do
    Map.get(list(), nodename)
  end
end
