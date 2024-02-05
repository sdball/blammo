defmodule Blammo.LogConsumer do
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
  end

  def consume(options = %Options{}) do
    dbg(options)

    # TODO: actually read some file lines and such
    Task.Supervisor.async(Blammo.LogSupervisor, fn ->
      [
        "Line 4",
        "Line 3",
        "Line 2",
        "Line 1"
      ]
      |> Enum.join("\n")
    end)
    |> Task.await()
  end
end
