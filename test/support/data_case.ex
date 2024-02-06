defmodule Blammo.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to log data.

  You may define functions here to be used as helpers in
  data tests.
  """

  @file_contents [
    "line 1",
    "line 2",
    "line 3",
    "line 4"
  ]

  use ExUnit.CaseTemplate

  setup do
    File.mkdir("sample_logs")
    contents = @file_contents |> Enum.join("\n")
    File.write!(log_path(), contents <> "\n")
  end

  def log_contents do
    @file_contents
  end

  def log_path do
    Path.join(["sample_logs", log_name()])
  end

  def log_name do
    "test.log"
  end

  def large_file? do
    large_file_path()
    |> File.exists?()
  end

  def large_file_path do
    Path.join(["sample_logs", "sample.1GB.log"])
  end
end
