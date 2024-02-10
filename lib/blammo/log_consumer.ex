defmodule Blammo.LogConsumer do
  defmodule Options do
    @log_path Application.compile_env(:blammo, :log_consumer_path, "/var/log")

    defstruct [:filename, :filepath, lines: 1000, filter: nil]

    def build(given) when is_map(given) do
      options = struct(Options, given)

      cond do
        is_nil(options.filename) ->
          {:error, "filename must be provided"}

        options.lines <= 0 ->
          {:error, "line count of less than 1 is invalid"}

        Path.safe_relative(options.filename, @log_path) == :error ->
          {:error, "invalid file path"}

        true ->
          {:ok, %{options | filepath: Path.join(@log_path, options.filename)}}
      end
    end

    def build!(given) do
      {:ok, options} = build(given)
      options
    end

    def log_path, do: @log_path
  end

  def consume_filter_first(options = %Options{}) do
    task =
      Task.Supervisor.async_nolink(Blammo.LogSupervisor, fn ->
        tail =
          Blammo.File.filtered_tail(options.filepath, options.filter, options.lines)

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

    case Task.yield(task, 600_000) || Task.shutdown(task) do
      {:ok, lines} when is_binary(lines) -> {:ok, lines}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, "timed out reading logfile"}
    end
  end

  def consume_lines_first(options = %Options{}) do
    task =
      Task.Supervisor.async_nolink(Blammo.LogSupervisor, fn ->
        tail =
          Blammo.File.tail(options.filepath, options.lines)
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

    case Task.yield(task, 10_000) || Task.shutdown(task) do
      {:ok, lines} when is_binary(lines) -> {:ok, lines}
      {:ok, {:error, reason}} -> {:error, reason}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, "timed out reading logfile"}
    end
  end

  def log_files() do
    Options.log_path()
    |> File.ls!()
    |> Enum.sort()
  end

  defp maybe_filter(lines, nil), do: lines

  defp maybe_filter(lines, filter) do
    lines
    |> Enum.filter(&String.contains?(&1, filter))
  end
end
