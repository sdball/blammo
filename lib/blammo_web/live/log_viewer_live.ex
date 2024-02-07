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
       error: nil
     ), layout: false}
  end

  def handle_event("tail_log", %{"file" => file, "lines" => lines, "filter" => filter}, socket) do
    case Integer.parse(lines) do
      {lines, _} when lines <= 0 ->
        {:noreply, socket}

      {lines, _} ->
        case tail_log(file, lines, filter) do
          {:ok, content} ->
            {:noreply,
             assign(socket,
               error: nil,
               log_content: content,
               lines: lines,
               filter: filter,
               file: file
             )}

          {:error, reason} ->
            {:noreply,
             assign(socket,
               log_content: "",
               error: reason,
               lines: lines,
               filter: filter,
               file: file
             )}
        end

      _error ->
        {:noreply, socket}
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
