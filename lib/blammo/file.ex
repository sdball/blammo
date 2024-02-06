defmodule Blammo.File do
  defmodule TailOptions do
    defstruct [:file, :file_size, limit: 1000, chunk: 65536]
  end

  defmodule FilteredTailOptions do
    defstruct [:file, :file_size, :filter, limit: 1000, chunk: 65536]
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

      recur_filtered_tail(options)
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
        |> Enum.drop(1)
        |> Enum.take(-options.limit)

      cond do
        Enum.count(lines) < options.limit ->
          recur_tail(%{options | chunk: options.chunk * 2})

        start == 0 ->
          lines

        true ->
          lines
      end
    end
  end

  def recur_filtered_tail(options = %FilteredTailOptions{}) do
    start = max(options.file_size - options.chunk, 0)

    with {:ok, bytes} <- :file.pread(options.file, start, options.file_size) do
      lines =
        bytes
        |> String.split("\n", trim: true)
        |> Enum.drop(1)
        |> maybe_filter(options.filter)
        |> Enum.take(-options.limit)

      cond do
        Enum.count(lines) < options.limit ->
          recur_filtered_tail(%{options | chunk: options.chunk * 2})

        start == 0 ->
          lines

        true ->
          lines
      end
    end
  end

  defp maybe_filter(lines, nil), do: lines

  defp maybe_filter(lines, filter) do
    Enum.filter(lines, &String.contains?(&1, filter))
  end
end
