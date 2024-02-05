defmodule Blammo.File do
  def tail(fpath, limit) do
    fpath
    |> File.stream!()
    |> Stream.take(-limit)
    |> Enum.join()
  end
end
