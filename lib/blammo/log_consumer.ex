defmodule Blammo.LogConsumer do
  @log_path Application.compile_env(:blammo, :log_consumer_path, "/var/log")

  defmodule Options do
    defstruct [:filename, lines: 1000, filter: nil]

    def build(given) when is_map(given) do
      options = struct(Options, given)

      cond do
        options.lines <= 0 ->
          {:error, "line count of less than 1 is invalid"}

        true ->
          {:ok, options}
      end
    end

    def build!(given) do
      struct(Options, given)
    end
  end

  def consume_filter_first(options = %Options{}) do
    result =
      Task.Supervisor.async_nolink(Blammo.LogSupervisor, fn ->
        tail =
          Path.join([@log_path, options.filename])
          |> Blammo.File.filtered_tail(options.filter, options.lines)

        case tail do
          {:error, :enoent} ->
            {:error, "file not found"}

          lines ->
            lines
            |> Enum.reverse()
            |> Enum.join("\n")
        end
      end)
      |> Task.yield()

    case result do
      {:ok, lines} when is_binary(lines) -> {:ok, lines}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, _reason} -> {:error, "error reading logfile"}
      nil -> {:error, "timed out reading logfile"}
    end
  end

  def consume_lines_first(options = %Options{}) do
    result =
      Task.Supervisor.async_nolink(Blammo.LogSupervisor, fn ->
        tail =
          Path.join([@log_path, options.filename])
          |> Blammo.File.tail(options.lines)
          |> maybe_filter(options.filter)

        case tail do
          {:error, :enoent} ->
            {:error, "file not found"}

          {:error, _reason} ->
            {:error, "error reading file"}

          lines ->
            lines
            |> Enum.reverse()
            |> Enum.join("\n")
        end
      end)
      |> Task.yield()

    case result do
      {:ok, lines} when is_binary(lines) -> {:ok, lines}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, "timed out reading logfile"}
    end
  end

  defp maybe_filter(lines, nil), do: lines

  defp maybe_filter(lines, filter) do
    lines
    |> Enum.filter(&String.contains?(&1, filter))
  end
end
