defmodule Blammo.FileTest do
  use Blammo.DataCase
  alias Blammo.DataCase, as: TestData

  test "tail/2 with valid file and limit" do
    expected = TestData.log_contents()
    assert Blammo.File.tail(TestData.log_path(), 10) === expected
  end

  test "tail/2 with a valid file and limit smaller than the file" do
    expected = TestData.log_contents() |> Enum.take(-2)
    assert Blammo.File.tail(TestData.log_path(), 2) == expected
  end

  test "filtered_tail/3 with a valid file, filter, and limit" do
    filepath = TestData.log_path()
    filter = "line"
    limit = 10
    expected = TestData.log_contents()
    assert Blammo.File.filtered_tail(filepath, filter, limit) === expected
  end

  test "filtered_tail/3 with a nil filter acts like tail/2" do
    filepath = TestData.log_path()
    filter = nil
    limit = 10
    expected = TestData.log_contents()
    assert Blammo.File.filtered_tail(filepath, filter, limit) === expected
  end

  test "filtered_tail/3 filters until it reaches the limit or entire file" do
    filepath = TestData.log_path()
    filter = "line 2"
    limit = 1
    expected = ["line 2"]
    assert Blammo.File.filtered_tail(filepath, filter, limit) === expected
  end

  if TestData.large_file?() do
    test "tail/2 is performant against a large file" do
      {timing, _lines} =
        :timer.tc(fn ->
          TestData.large_file_path()
          |> Blammo.File.tail(100)
        end)

      # 1000 microseconds = 1ms
      assert timing <= 1000
    end

    test "filtered_tail/3 is performant against a large file" do
      {timing, _lines} =
        :timer.tc(fn ->
          TestData.large_file_path()
          |> Blammo.File.filtered_tail("xyzzy", 100)
        end)

      # 10_000 microseconds = 10ms
      assert timing <= 10_000
    end
  end
end
