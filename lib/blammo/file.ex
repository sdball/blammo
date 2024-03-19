defmodule Blammo.File do
  @moduledoc """
  Blammo.File provides functions for files useful to the Blammo domain.
  """

  defmodule TailOptions do
    defstruct [:file, :file_size, :filter_function, limit: 1000, chunk: 1_048_576]
  end

  @doc """
  `tail/2` returns the last `limit` lines of the given file path.
  """
  def tail(fpath, limit) do
    with {:ok, file} <- File.open(fpath) do
      file_size = File.stat!(fpath).size

      options =
        struct(TailOptions, %{
          file: file,
          file_size: file_size,
          filter_function: nil,
          limit: limit
        })

      current = max(file_size - options.chunk, 0)
      recur_tail(options, current: current, lines: [])
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  `tail/3` accepts a callback function and will search backwards
  until it accumulations `limit` lines that pass the filter or
  reaches the start of the file.

  The callback function must have an arity of 1 and it will
  be called with each line from the file. The callback must
  return true/false.
  """
  def tail(fpath, limit, filter_function) do
    with {:ok, file} <- File.open(fpath) do
      file_size = File.stat!(fpath).size

      options =
        struct(TailOptions, %{
          file: file,
          file_size: file_size,
          filter_function: filter_function,
          limit: limit
        })

      current = max(file_size - options.chunk, 0)
      recur_tail(options, current: current, lines: [])
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- private ---------------------------------------------------------------

  defp recur_tail(options = %TailOptions{}, current: current, lines: lines) do
    with {:ok, bytes} <- :file.pread(options.file, current, options.chunk) do
      split_lines = String.split(bytes, "\n", trim: true)

      {partial, more_lines} =
        if current == 0 && options.chunk > options.file_size do
          {"", split_lines}
        else
          maybe_drop_partial_line(split_lines, current)
        end

      more_lines =
        more_lines
        |> maybe_filter(options.filter_function)
        |> Enum.to_list()

      lines = (more_lines ++ lines) |> Enum.take(-options.limit)

      cond do
        # start of file
        current == 0 ->
          lines

        # not yet reached the limit
        Enum.count(lines) < options.limit ->
          recur_tail(options,
            current: max(current - options.chunk + byte_size(partial), 0),
            lines: lines
          )

        # return what we have
        true ->
          lines
      end
    end
  end

  defp maybe_drop_partial_line(lines, 0) do
    {"", List.delete_at(lines, -1)}
  end

  defp maybe_drop_partial_line(lines, _start) when length(lines) == 1, do: {"", lines}

  defp maybe_drop_partial_line(lines, _start) do
    [partial | remaining] = lines
    {partial, remaining}
  end

  defp maybe_filter(lines, nil), do: lines

  defp maybe_filter(lines, filter_function) do
    lines
    |> Stream.filter(filter_function)
  end
end
