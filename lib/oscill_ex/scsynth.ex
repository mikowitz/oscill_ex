defmodule OscillEx.Scsynth do
  @moduledoc """
  Manages a running `scsynth` process
  """
  alias OscillEx.Server.Config

  def start_process(%Config{} = config) do
    case validate_executable(config.executable) do
      :ok -> open_port(config)
      {:error, error} -> {:error, error}
    end
  end

  def stop_process(port, monitor) do
    if is_reference(monitor) do
      Port.demonitor(monitor, [:flush])
    end

    if is_port(port) and Port.info(port) != nil do
      Port.close(port)
    end

    :ok
  end

  def handle_exit_status(0), do: nil
  def handle_exit_status(code), do: {:exit, code}

  def handle_port_down(reason), do: {:exit, reason}

  def parse_scsynth_error(data) when is_binary(data) do
    cond do
      data =~ ~r/ERROR.*address in use/ -> {:error, :scsynth_port_in_use}
      data =~ ~r/ERROR.*(There must be a -u|Invalid option)/ -> {:error, :scsynth_invalid_args}
      true -> :ok
    end
  end

  def parse_scsynth_error(_), do: :ok

  defp validate_executable(executable) do
    case File.stat(executable) do
      {:ok, %File.Stat{type: :regular}} ->
        if can_execute?(executable) do
          :ok
        else
          {:error, {:permission_denied, executable}}
        end

      {:ok, %File.Stat{type: type}} ->
        {:error, {:not_executable, "#{executable} is a #{type}, not an executable file"}}

      {:error, :enoent} ->
        {:error, {:file_not_found, executable}}
    end
  end

  defp can_execute?(executable) do
    case System.cmd("test", ["-x", executable]) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp open_port(config) do
    args = Config.command_line_args(config)

    port =
      Port.open(
        {:spawn_executable, "./bin/wrapper"},
        [
          {:args, args},
          :binary,
          :exit_status
        ]
      )

    monitor = Port.monitor(port)

    {:ok, port, monitor}
  end

  def close_port(port, monitor) do
    if is_reference(monitor), do: Port.demonitor(monitor, [:flush])

    if is_port(port) and Port.info(port) != nil do
      Port.close(port)
    end

    nil
  end
end
