defmodule BlammoWeb.LogViewerLive do
  use BlammoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       files: get_files(),
       log_content: "",
       lines: 25,
       filter: nil,
       file: nil,
       error: nil,
       busy: false
     ), layout: false}
  end

  def handle_event("tail_log", %{"file" => file, "lines" => lines, "filter" => filter}, socket) do
    GenServer.cast(self(), {:tail_log, %{"file" => file, "lines" => lines, "filter" => filter}})
    {:noreply, assign(socket, busy: true, log_content: "Reading … … …")}
  end

  def handle_cast({:tail_log, %{"file" => file, "lines" => lines, "filter" => filter}}, socket) do
    case Integer.parse(lines) do
      {lines, _} when lines <= 0 ->
        {:noreply, assign(socket, busy: false)}

      {lines, _} ->
        case tail_log(file, lines, filter) do
          {:ok, ""} ->
            {:noreply,
             assign(socket,
               error: nil,
               log_content: "--- NO RESULTS ---",
               lines: lines,
               filter: filter,
               file: file,
               busy: false
             )}

          {:ok, content} ->
            {:noreply,
             assign(socket,
               error: nil,
               log_content: content,
               lines: lines,
               filter: filter,
               file: file,
               busy: false
             )}

          {:error, reason} ->
            {:noreply,
             assign(socket,
               log_content: "",
               error: reason,
               lines: lines,
               filter: filter,
               file: file,
               busy: false
             )}
        end

      _error ->
        {:noreply, assign(socket, busy: false, log_content: "")}
    end
  end

  def handle_info(_any, socket) do
    {:noreply, socket}
  end

  defp get_files do
    Blammo.LogConsumer.log_files()
  end

  defp tail_log(file, lines, filter) do
    opts = %{
      filename: file,
      lines: lines,
      filter: filter
    }

    with {:ok, options} <- Blammo.LogConsumer.Options.build(opts) do
      Blammo.LogConsumer.consume_filter_first(options)
    end
  end
end
