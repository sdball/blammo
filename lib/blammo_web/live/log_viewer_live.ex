defmodule BlammoWeb.LogViewerLive do
  @moduledoc """
  A LiveView process providing the Blammo log tailing capabilities via
  `Blammo.Servers`.

  Yes we use `Blammo.Servers` even for talking to our own logs. That
  allows a consistent interface regardless of log source.
  """

  use BlammoWeb, :live_view

  alias Blammo.Servers

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blammo.PubSub, "servers")
    end

    {:ok,
     assign(socket,
       servers: Servers.list(),
       files: get_files(),
       server: nil,
       file: nil,
       log_content: "",
       lines: 25,
       filter: nil,
       error: nil,
       busy: false
     ), layout: false}
  end

  def handle_event("fetch_server_files", %{"server" => server}, socket) do
    case Servers.files(server |> String.to_existing_atom()) do
      {:ok, server_files} ->
        {:noreply,
         assign(socket, files: server_files, file: nil, log_content: "", server: server)}

      {:error, :no_connection} ->
        updated_servers = Map.drop(socket.assigns.servers, [server |> String.to_existing_atom()])
        {:noreply, assign(socket, servers: updated_servers, error: "No connection to #{server}")}
    end
  end

  def handle_event(
        "tail_log",
        %{"server" => server, "file" => file, "lines" => lines, "filter" => filter},
        socket
      ) do
    GenServer.cast(
      self(),
      {:tail_log,
       %{
         "server" => server,
         "file" => file,
         "lines" => lines,
         "filter" => filter
       }}
    )

    {:noreply, assign(socket, busy: true, log_content: "Reading … … …")}
  end

  def handle_event("tail_log", _params, socket), do: {:noreply, socket}

  def handle_cast(
        {:tail_log,
         %{
           "server" => server,
           "file" => file,
           "lines" => lines,
           "filter" => filter
         }},
        socket
      ) do
    socket =
      assign(socket,
        server: server,
        file: file,
        lines: lines,
        filter: filter,
        busy: false,
        error: nil,
        log_content: ""
      )

    case Integer.parse(lines) do
      {lines, _} when lines <= 0 ->
        {:noreply,
         assign(socket,
           error: "lines must be greater than zero"
         )}

      {lines, _} ->
        case tail_log(server, file, lines, filter) do
          {:ok, ""} ->
            {:noreply,
             assign(socket,
               log_content: "--- NO RESULTS ---"
             )}

          {:ok, content} ->
            if String.valid?(content) do
              {:noreply,
               assign(socket,
                 log_content: content
               )}
            else
              {:noreply,
               assign(socket,
                 log_content: "--- NON PRINTABLE FILE CONTENT --"
               )}
            end

          {:error, reason} ->
            {:noreply, assign(socket, error: reason)}
        end

      _error ->
        {:noreply, socket}
    end
  end

  def handle_info({:server, nodename, pid}, socket) do
    updated_servers = Map.put(socket.assigns.servers, nodename, pid)
    {:noreply, assign(socket, servers: updated_servers)}
  end

  def handle_info(_any, socket) do
    {:noreply, socket}
  end

  defp get_files do
    Blammo.LogConsumer.log_files()
  end

  defp tail_log(server, file, lines, filter) do
    Servers.tail_log(server |> String.to_existing_atom(), file, filter, lines)
  end
end
