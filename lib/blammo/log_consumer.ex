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

  def consume(options = %Options{}) do
    result =
      Task.Supervisor.async_nolink(Blammo.LogSupervisor, fn ->
        Path.join([@log_path, options.filename])
        |> Blammo.File.tail(options.lines)
      end)
      |> Task.yield()

    case result do
      {:ok, lines} -> {:ok, lines}
      {:exit, reason} -> {:error, reason}
      nil -> {:error, "timed out reading logfile"}
    end
  end

  def consume(filename) when is_binary(filename) do
    %{filename: filename}
    |> Options.build!()
    |> consume()
  end
end
