defmodule Blammo.File do
  defmodule TailOptions do
    defstruct [:file, :file_size, limit: 1000, chunk: 65536]
  end

  defmodule FilteredTailOptions do
    defstruct [:file, :file_size, :filter, limit: 1000, chunk: 1_048_576]
  end

  def tail(fpath, limit) do
    with {:ok, file} <- File.open(fpath) do
      file_size = File.stat!(fpath).size

      options =
        struct(TailOptions, %{
          file: file,
          file_size: file_size,
          limit: limit
        })

      recur_tail(options)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def filtered_tail(fpath, filter, limit) do
    with {:ok, file} <- File.open(fpath) do
      file_size = File.stat!(fpath).size

      options =
        struct(FilteredTailOptions, %{
          file: file,
          file_size: file_size,
          filter: filter,
          limit: limit
        })

      recur_filtered_tail(options, current: file_size, lines: [])
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- private ---------------------------------------------------------------

  defp recur_tail(options = %TailOptions{}) do
    start = max(options.file_size - options.chunk, 0)

    with {:ok, bytes} <- :file.pread(options.file, start, options.file_size) do
      lines =
        bytes
        |> String.split("\n", trim: true)
        |> maybe_drop_partial_line(start)
        |> Enum.take(-options.limit)

      cond do
        start == 0 ->
          lines

        Enum.count(lines) < options.limit ->
          recur_tail(%{options | chunk: options.chunk * 2})

        true ->
          lines
      end
    end
  end

  def recur_filtered_tail(options = %FilteredTailOptions{}, current: current, lines: lines) do
    start = max(current - options.chunk, 0)

    with {:ok, bytes} <- :file.pread(options.file, start, current) do
      more_lines =
        bytes
        |> String.split("\n", trim: true)
        |> maybe_drop_partial_line(start)
        |> maybe_filter(options.filter)

      lines = (lines ++ more_lines) |> Enum.take(-options.limit)

      cond do
        start == 0 ->
          lines

        Enum.count(lines) < options.limit ->
          next_chunk = max(options.chunk * 2, 52_428_800)

          recur_filtered_tail(%{options | chunk: next_chunk},
            current: current - options.chunk,
            lines: lines
          )

        true ->
          lines
      end
    end
  end

  defp maybe_drop_partial_line(lines, 0), do: lines

  defp maybe_drop_partial_line(lines, _start) do
    Enum.drop(lines, 1)
  end

  defp maybe_filter(lines, nil), do: lines

  defp maybe_filter(lines, filter) do
    Enum.filter(lines, &String.contains?(&1, filter))
  end
end
