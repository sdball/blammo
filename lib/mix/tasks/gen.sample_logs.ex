defmodule Mix.Tasks.Gen.SampleLogs do
  use Mix.Task

  @shortdoc "Generate sample log files up to a declared file size."

  @start_timestamp DateTime.add(DateTime.utc_now(), -2 * 365 * 24 * 60 * 60, :second)

  def run(args) do
    options =
      OptionParser.parse(args,
        switches: [log_size: :string]
      )

    case options do
      {[log_size: log_size_arg], _, _} when not is_nil(log_size_arg) ->
        log_size = parse_log_size(log_size_arg)
        generate_sample_logs(log_size, log_size_arg, @start_timestamp)

      _ ->
        Mix.shell().error(
          "Invalid or missing options. Usage: mix gen.sample_logs --log-size 100MB"
        )
    end
  end

  defp parse_log_size(size_string) do
    {size, unit} = Integer.parse(size_string)

    case unit do
      "MB" ->
        size * 1_000_000

      "GB" ->
        size * 1_000_000_000
    end
  end

  defp generate_sample_logs(target_size_bytes, target_size, timestamp) do
    File.mkdir_p!("sample_logs")
    log_path = Path.join(["sample_logs", "sample.#{target_size}.log"])

    File.open!(log_path, [:write], fn file ->
      Enum.reduce_while(
        Stream.iterate(timestamp, &DateTime.add(&1, 1, :second)),
        0,
        fn current_timestamp, acc ->
          if acc > target_size_bytes do
            {:halt, acc}
          else
            entry = generate_log_entry(current_timestamp)
            IO.write(file, entry)
            {:cont, acc + byte_size(entry)}
          end
        end
      )
    end)

    Mix.shell().info("Generated sample log file at #{log_path}")
  end

  defp generate_log_entry(timestamp) do
    timestamp_str = DateTime.to_string(timestamp)
    hostname = "server#{self() |> :erlang.pid_to_list() |> :erlang.list_to_bitstring()}"
    pid = Enum.random(1111..9999)
    message = "Sample log message from #{pid}"
    process = Enum.random(["xyzzy", "frotz", "nitfol", "plugh"])

    "#{timestamp_str} #{hostname} #{process}[#{pid}]: #{message}\n"
  end
end
