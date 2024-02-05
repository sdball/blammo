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
    Task.Supervisor.async(Blammo.LogSupervisor, fn ->
      Path.join([@log_path, options.filename])
      |> stream()
      |> last(options.lines)
      |> filter(options.filter)
      |> Enum.join()
    end)
    |> Task.await()
  end

  def consume(filename) when is_binary(filename) do
    %{filename: filename}
    |> Options.build!()
    |> consume()
  end

  defp stream(path) do
    File.stream!(path)
  end

  defp last(stream, limit), do: Stream.take(stream, -limit)

  defp filter(stream, pattern) when not is_nil(pattern) do
    stream
    |> Stream.filter(fn line ->
      line |> String.contains?(pattern)
    end)
  end

  defp filter(stream, _pattern), do: stream
end
