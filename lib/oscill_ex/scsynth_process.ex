defmodule OscillEx.ScsynthProcess do
  @moduledoc """
  Manages the running `scsynth` process
  """

  alias OscillEx.Server
  require Logger

  def start(config) do
    command_to_run = Server.Config.command(config)
    command_args = Server.Config.command_args(config)

    Logger.info("Server starting with #{command_to_run}")

    port =
      port_helper().open(
        {:spawn_executable, "./bin/scsynth_wrapper"},
        [:binary, args: command_args]
      )

    case port_helper().info(port) do
      nil ->
        Logger.error("Could not start `#{command_to_run}`")
        {:error, :could_not_start_scsynth}

      _ ->
        Logger.info("Server started with `#{command_to_run}`")
        monitor = Port.monitor(port)

        {:ok, port, monitor}
    end
  end

  def restart(config, old_monitor) do
    Port.demonitor(old_monitor)
    start(config)
  end

  defp port_helper do
    Application.get_env(:oscill_ex, :port_helper, OscillEx.SystemPortHelper)
  end
end
