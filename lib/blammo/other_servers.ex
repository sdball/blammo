defmodule Blammo.OtherServers do
  use GenServer

  defstruct servers: %{}

  def list() do
    GenServer.call(__MODULE__, :servers)
  end

  def files(nodename) do
    nodename
    |> server_pid()
    |> GenServer.call(:files)
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

  def handle_call(:servers, _from, %__MODULE__{} = state) do
    {:reply, state.servers, state}
  end

  def handle_call(:files, _from, %__MODULE__{} = state) do
    {:reply, Blammo.LogConsumer.log_files(), state}
  end

  def handle_call({:tail_log, filename, filter, lines}, _from, %__MODULE__{} = state)
      when is_integer(lines) do
    options =
      Blammo.LogConsumer.Options.build!(%{
        filename: filename,
        filter: filter,
        lines: lines
      })

    result = Blammo.LogConsumer.consume_filter_first(options)
    {:reply, result, state}
  end

  def handle_call({:tail_log, filename, lines, filter}, _from, %__MODULE__{} = state)
      when is_integer(lines) do
    options =
      Blammo.LogConsumer.Options.build!(%{
        filename: filename,
        filter: filter,
        lines: lines
      })

    result = Blammo.LogConsumer.consume_lines_first(options)
    {:reply, result, state}
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