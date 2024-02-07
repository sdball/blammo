defmodule BlammoWeb.LogViewerLive do
  use BlammoWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, files: get_files(), log_content: "", lines: 25, filter: nil, file: nil),
     layout: false}
  end

  def handle_event("tail_log", %{"file" => file, "lines" => lines, "filter" => filter}, socket) do
    case Integer.parse(lines) do
      {lines, _} when lines <= 0 ->
        {:noreply, socket}

      {lines, _} ->
        content = tail_log(file, lines, filter)
        {:noreply, assign(socket, log_content: content, lines: lines, filter: filter, file: file)}

      _error ->
        {:noreply, socket}
    end
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

    dbg(opts)
    dbg(Blammo.LogConsumer.Options.build(opts))

    with {:ok, options} <- Blammo.LogConsumer.Options.build(opts),
         {:ok, lines} <- Blammo.LogConsumer.consume_filter_first(options) do
      lines
    else
      error ->
        error
    end
  end
end
