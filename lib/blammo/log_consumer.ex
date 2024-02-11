defmodule Blammo.LogConsumer do
  @moduledoc """
  Blammo.LogConsumer provides an interface to tailing/filtering log files
  capabilities provided by `Blammo.File`.

  Blammo.LogConsumer provides a `Blammo.LogConsumer.Options` struct which
  is used to ensure consistent arguments and configuration for tailing
  operations. This allows `Blammo.File` to simply work with what it's
  given without having to know about domain specific configuration like
  the allowed log path.

  Blammo.LogConsumer abstracts the creation and awaiting of supervised
  Tasks (via the `Task.Supervisor` named `Blammo.LogSupervisor`).

  Blammo.LogConsumer also handles transforming the array results from
  `Blammo.File` into the correctly ordered and formatted strings expected
  by log callers.

  ## Returns latest lines first

  Log files are assumed to be written latest entries last. Blammo.LogConsumer
  returns found lines in reverse so that the first lines are the latest lines.

  The list of lines returned from `Blammo.File` are joined by newlines when
  returned so callers just have the string data they asked for.

  ## Two paths: filter first / tail first

  Currently there are two ways to tail log files and they are represented as
  two parallel code paths.

  If we know we only want to support one path then the superfluous path can
  be easily removed.

  If we decide we want to support both paths then the code paths can be
  consolidated.
  """
  defmodule Options do
    @moduledoc """
    Handles the consistent configuration of options for tail operations.
    """
    defstruct [:filename, :filepath, lines: 1000, filter: nil]

    @doc """
    Ensures the given map of options is valid, safe, and complete.

    Joins the given `filename` to the configured log path (from `log_path/0`)
    to create a `filepath` option.

    ## Checking safe relative paths

    This function checks that the given filename is a safe relative path to
    the configured log path.

    i.e. unsafe absolute paths or relative paths like `../../../../etc/passwd`
    are rejected here.
    """
    def build(given) when is_map(given) do
      options = struct(Options, given)

      cond do
        is_nil(options.filename) ->
          {:error, "filename must be provided"}

        options.lines <= 0 ->
          {:error, "line count of less than 1 is invalid"}

        Path.safe_relative(options.filename, log_path()) == :error ->
          {:error, "invalid file path"}

        true ->
          {:ok, %{options | filepath: Path.join(log_path(), options.filename)}}
      end
    end

    @doc """
    Calls `build/1` with the given map but errors unless the result is
    `{:ok, options}` and returns `options`.
    """
    def build!(given) do
      {:ok, options} = build(given)
      options
    end

    @doc """
    Returns the log consumer path from configuration or `/var/log`.
    """
    def log_path do
      Application.get_env(:blammo, :log_consumer_path, "/var/log")
    end
  end

  @doc """
  The code path for the "filter first" tail approach.

  Calls `Blammo.File.filtered_tail` with relevant parts of the `Options` struct
  and consolidates the various possible results into a simple set of usable
  results for the caller in the formats

  - `{:ok, result}`
  - `{:error, reason}`
  """
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

  @doc """
  The code path for the "tail first" tail approach.

  Calls `Blammo.File.tail` with relevant parts of the `Options` struct
  and consolidates the various possible results into a simple set of usable
  results for the caller in the formats

  - `{:ok, result}`
  - `{:error, reason}`
  """
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

  @doc """
  Returns the log files available in the configured log path.

  ## Log files

  Currently this function simply returns ALL files available in the
  configured log path. We could improve this function to only, say,
  return `*.log` files or possibly only files with text contents.
  """
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
