defmodule BlammoWeb.LogsController do
  @moduledoc """
  Provide web functions for Blammo capabilities.

  Right now the only collaborator is `Blammo.LogConsumer`
  """
  alias Blammo.LogConsumer
  use BlammoWeb, :controller

  @doc """
  Return the Blammo tagline.
  """
  def tagline(conn, _params) do
    conn
    |> text("🪵  Log! From BLAMMO!\n")
  end

  def logs(conn, _params) do
    conn
    |> json(LogConsumer.log_files())
  end

  def loglines(conn, params) do
    with {:ok, valid} <- validate_params(params),
         {:ok, options} <- Blammo.LogConsumer.Options.build(valid),
         {:ok, lines} <-
           Blammo.LogConsumer.consume(options) do
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
