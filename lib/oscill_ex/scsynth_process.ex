defmodule OscillEx.ScsynthProcess do
  @moduledoc """
  Manages the running `scsynth` process
  """

  alias OscillEx.Logger
  alias OscillEx.Server
  import OscillEx, only: [port_helper: 0]

  @port_name {:spawn_executable, "./bin/scsynth_wrapper"}

  def start(config) do
    command_to_run = Server.Config.command_string(config)
    command_args = Server.Config.command_list(config)

    Logger.server_starting(command_to_run)

    port = port_helper().open(@port_name, [:binary, args: command_args])

    case port_helper().info(port) do
      nil ->
        Logger.server_start_failed(command_to_run)
        {:error, :could_not_start_scsynth}

      _ ->
        Logger.server_started(command_to_run)
        monitor = Port.monitor(port)
        {:ok, port, monitor}
    end
  end

  def restart(config, old_monitor) do
    Port.demonitor(old_monitor, [:flush])
    start(config)
  end
end
