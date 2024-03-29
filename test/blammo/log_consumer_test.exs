defmodule Blammo.LogConsumerTest do
  use Blammo.DataCase
  alias Blammo.DataCase, as: TestData
  alias Blammo.LogConsumer

  describe("LogConsumer.Options") do
    test("build/1 called with a valid map of options") do
      {:ok, options} =
        LogConsumer.Options.build(%{
          filename: "file.txt",
          lines: 10,
          filter: "hello"
        })

      assert options.filename == "file.txt"
      assert options.lines == 10
      assert options.filter == "hello"
    end

    test("build/1 called only with a filename") do
      {:ok, options} = LogConsumer.Options.build(%{filename: "file.txt"})
      assert options.filename == "file.txt"
      assert options.lines == 1000
      assert options.filter == nil
    end

    test("build/1 called with invalid values") do
      case LogConsumer.Options.build(%{filename: nil}) do
        {:error, _reason} ->
          :passes

        _other ->
          flunk("build/1 should have returned error for nil filename")
      end

      case LogConsumer.Options.build(%{filename: "file", lines: 0}) do
        {:error, _reason} ->
          :passes

        _other ->
          flunk("build/1 should have returned error for zero lines")
      end

      case LogConsumer.Options.build(%{filename: "file", lines: -3}) do
        {:error, _reason} ->
          :passes

        _other ->
          flunk("build/1 should have returned error for negative lines")
      end

      case LogConsumer.Options.build(%{filename: "../README.md"}) do
        {:error, _reason} ->
          :passes

        _other ->
          flunk("build/1 should have rejected an unsafe filepath")
      end

      case LogConsumer.Options.build(%{filename: "/etc/passwd"}) do
        {:error, _reason} ->
          :passes

        _other ->
          flunk("build/1 should have rejected an unsafe filepath")
      end
    end
  end

  describe("LogConsumer") do
    test "consume/1 with a specific filter" do
      {:ok, options} =
        LogConsumer.Options.build(%{
          filename: TestData.log_name(),
          filter: "line 3",
          lines: 10
        })

      {:ok, result} = LogConsumer.consume(options)

      # got a result because we filter before we limit lines
      assert result === "line 3"
    end

    test "consume/1 with a wide filter" do
      {:ok, options} =
        LogConsumer.Options.build(%{
          filename: TestData.log_name(),
          filter: "line",
          lines: 10
        })

      {:ok, result} = LogConsumer.consume(options)

      assert result === TestData.log_contents() |> Enum.reverse() |> Enum.join("\n")
    end

    test "consume/1 with limited lines" do
      {:ok, options} =
        LogConsumer.Options.build(%{
          filename: TestData.log_name(),
          lines: 1
        })

      {:ok, result} = LogConsumer.consume(options)
      expected_last_line = TestData.log_contents() |> Enum.at(-1)
      assert result == expected_last_line
    end
  end
end
