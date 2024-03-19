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

  test "tail/3 with a valid file, limit, and filter function" do
    filepath = TestData.log_path()
    filter_fn = &String.contains?(&1, "line")
    limit = 10
    expected = TestData.log_contents()
    assert Blammo.File.tail(filepath, limit, filter_fn) === expected
  end

  test "tail/3 with a nil filter function acts like tail/2" do
    filepath = TestData.log_path()
    limit = 10
    expected = TestData.log_contents()
    assert Blammo.File.tail(filepath, limit, nil) === expected
  end

  test "tail/3 filters until it reaches the limit or entire file" do
    filepath = TestData.log_path()
    filter_fn = &String.contains?(&1, "line 2")
    limit = 1
    expected = ["line 2"]
    assert Blammo.File.tail(filepath, limit, filter_fn) === expected
  end

  if TestData.large_file?() do
    test "tail/2 is performant against a large file" do
      {timing, _lines} =
        :timer.tc(fn ->
          TestData.large_file_path()
          |> Blammo.File.tail(100)
        end)

      # 10000 microseconds = 10ms
      assert timing <= 10000
    end

    test "tail/3 is performant against a large file" do
      {timing, _lines} =
        :timer.tc(fn ->
          TestData.large_file_path()
          |> Blammo.File.tail(100, &String.contains?(&1, "xyzzy"))
        end)

      # 1_000_000 microseconds = 1000ms
      assert timing <= 1_000_000
    end
  end
end
