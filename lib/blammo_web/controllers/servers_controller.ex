defmodule BlammoWeb.ServersController do
  @moduledoc """
  Provides an interface to the `Blammo.Servers` capabilities.
  """
  use BlammoWeb, :controller

  alias Blammo.Servers

  def index(conn, _params) do
    server_names =
      Servers.list()
      |> Enum.map(fn {nodename, _pid} ->
        nodename
      end)

    conn
    |> json(server_names)
  end

  def logs(conn, params) do
    case Map.get(params, "server") do
      nil ->
        send_resp(conn, 400, "\"server\" parameter is required")

      server ->
        case Servers.files(server |> String.to_existing_atom()) do
          {:ok, files} ->
            json(conn, files)

          {:error, :no_connection} ->
            send_resp(conn, 500, "no connection to server")
        end
    end
  end

  def filter_first(conn, params) do
    with {:ok, valid} <- validate_params(params) do
      server = Map.fetch!(valid, :server)
      filename = Map.fetch!(valid, :filename)
      lines = Map.fetch!(valid, :lines)
      filter = Map.fetch!(valid, :filter)

      case Servers.tail_log(server, filename, filter, lines) do
        {:ok, lines} ->
          text(conn, lines <> "\n")

        {:error, reason} ->
          send_resp(conn, 400, reason)

        _other ->
          send_resp(conn, 400, "error reading server logfile")
      end
    else
      {:error, reason} ->
        send_resp(conn, 400, reason)
    end
  end

  def tail_first(conn, params) do
    with {:ok, valid} <- validate_params(params) do
      server = Map.fetch!(valid, :server)
      filename = Map.fetch!(valid, :filename)
      lines = Map.fetch!(valid, :lines)
      filter = Map.fetch!(valid, :filter)

      case Servers.tail_log(server, filename, lines, filter) do
        {:ok, lines} ->
          text(conn, lines <> "\n")

        {:error, reason} ->
          send_resp(conn, 400, reason)

        _other ->
          send_resp(conn, 400, "error reading server logfile")
      end
    else
      {:error, reason} ->
        send_resp(conn, 400, reason)
    end
  end

  defp validate_params(%{"server" => server, "filename" => filename} = params)
       when is_binary(filename) and is_binary(server) do
    defaults = %{
      lines: 1000,
      filter: nil
    }

    valid =
      params
      |> Enum.reduce(defaults, fn
        {"server", server}, acc -> Map.put(acc, :server, String.to_existing_atom(server))
        {"filename", filename}, acc -> Map.put(acc, :filename, filename)
        {"lines", lines}, acc -> Map.put(acc, :lines, Integer.parse(lines))
        {"filter", filter}, acc -> Map.put(acc, :filter, filter)
        _, acc -> acc
      end)

    case Map.get(valid, :lines) do
      1000 ->
        {:ok, valid}

      {lines, _} when is_integer(lines) ->
        {:ok, %{valid | lines: lines}}

      nil ->
        {:ok, valid}

      :error ->
        {:error, "lines must be a valid integer"}
    end
  end

  defp validate_params(_params) do
    {:error, "server and filename parameters are required"}
  end
end
