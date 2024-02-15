defmodule Blammo.File do
  @moduledoc """
  Blammo.File provides functions for files useful to the Blammo domain.
  """

  defmodule TailOptions do
    @moduledoc """
    Options for the tail first approach.

    Specifically a small initial chunk size that is expected to increase
    unless it is large enough to return the requested number of log lines.
    """
    defstruct [:file, :file_size, limit: 1000, chunk: 65536]
  end

  defmodule FilteredTailOptions do
    @moduledoc """
    Options for the filter first approach.

    Specifically a relatively large initial chunk size that is expected
    to increase until an upper bound to allow efficient chunking backwards
    through the file since the given filter may be anywhere in the file.
    """
    defstruct [:file, :file_size, :filter, limit: 1000, chunk: 1_048_576]
  end

  @doc """
  Returns the requested `limit` of lines from the end of the given `fpath` file.

  If the file has fewer lines than requested then the entire file is returned.

  This is the "tail first" approach path.
  """
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

  @doc """
  Returns the latest `limit` number of lines that match the given `filter` starting
  from the end of the given `fpath`.

  This function will step backwards through the file accumulating lines that contain
  the `filter` until it reaches the `limit` and then returns the accumulated lines.

  If the file has fewer lines that contain `filter` than the `limit` then all of
  the matching lines are returned.

  This is the "filter first" approach path.
  """
  def filtered_tail(fpath, filter, limit, chunk_size \\ 1_048_576) do
    with {:ok, file} <- File.open(fpath) do
      file_size = File.stat!(fpath).size

      options =
        struct(FilteredTailOptions, %{
          file: file,
          file_size: file_size,
          filter: filter,
          limit: limit,
          chunk: chunk_size
        })

      current = max(file_size - options.chunk, 0)
      recur_filtered_tail(options, current: current, lines: [])
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- private ---------------------------------------------------------------

  defp recur_tail(options = %TailOptions{}) do
    start = max(options.file_size - options.chunk, 0)

    with {:ok, bytes} <- :file.pread(options.file, start, options.file_size) do
      lines = String.split(bytes, "\n", trim: true)

      lines =
        if start == 0 do
          lines
        else
          Enum.drop(lines, 1)
        end

      lines = Enum.take(lines, -options.limit)

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

  defp recur_filtered_tail(options = %FilteredTailOptions{}, current: current, lines: lines) do
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
        |> maybe_filter(options.filter)
        |> Enum.to_list()

      lines = (more_lines ++ lines) |> Enum.take(-options.limit)

      cond do
        current == 0 ->
          lines

        Enum.count(lines) < options.limit ->
          recur_filtered_tail(options,
            current: max(current - options.chunk + byte_size(partial), 0),
            lines: lines
          )

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

  defp maybe_filter(lines, filter) do
    lines
    |> Stream.filter(&String.contains?(&1, filter))
  end
end
