defmodule OscillEx.Logger do
  @moduledoc false

  require Logger

  def server_starting(command), do: Logger.info("Server starting with `#{command}`")
  def server_started(command), do: Logger.info("Server started with `#{command}`")
  def server_start_failed(command), do: Logger.error("Could not start server with `#{command}`")
  def server_quit, do: Logger.info("`scsynth` server quit")
  def missing_executable(path), do: Logger.error("Could not find executable `#{path}`")
  def udp(msg), do: Logger.info(inspect(to_string(msg)))
  def server_not_started, do: Logger.warning("`scsynth` server is not running")
  def server_running, do: Logger.warning("`scsynth` server is already running")
end
