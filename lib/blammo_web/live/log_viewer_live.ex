defmodule BlammoWeb.LogViewerLive do
  use BlammoWeb, :live_view

  alias Blammo.OtherServers

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Blammo.PubSub, "servers")
    end

    {:ok,
     assign(socket,
       servers: OtherServers.list(),
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
    server_files = OtherServers.files(server |> String.to_existing_atom())
    {:noreply, assign(socket, files: server_files, file: nil, log_content: "", server: server)}
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
    OtherServers.tail_log(server |> String.to_existing_atom(), file, filter, lines)
  end
end
