defmodule BlammoWeb.LogsController do
  use BlammoWeb, :controller

  def tagline(conn, _params) do
    conn
    |> text("🪵  Log! From BLAMMO!\n")
  end

  def loglines(conn, params) do
    with {:ok, valid} <- validate_params(params),
         {:ok, options} <- Blammo.LogConsumer.Options.build(valid),
         {:ok, lines} <-
           Blammo.LogConsumer.consume_filter_first(options) do
      text(conn, lines <> "\n")
    else
      {:error, reason} ->
        conn
        |> send_resp(400, reason)

      nil ->
        conn
        |> send_resp(400, "error reading log file")
    end
  end

  defp validate_params(%{"filename" => filename} = params) when is_binary(filename) do
    valid =
      params
      |> Enum.reduce(%{}, fn
        {"filename", filename}, acc -> Map.put(acc, :filename, filename)
        {"lines", lines}, acc -> Map.put(acc, :lines, Integer.parse(lines))
        {"filter", filter}, acc -> Map.put(acc, :filter, filter)
        _, acc -> acc
      end)

    case Map.get(valid, :lines) do
      {lines, _} when is_integer(lines) ->
        {:ok, %{valid | lines: lines}}

      nil ->
        {:ok, valid}

      :error ->
        {:error, "lines must be a valid integer"}
    end
  end

  defp validate_params(_params) do
    {:error, "filename parameter is required"}
  end
end
