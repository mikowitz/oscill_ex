defmodule OscillEx.Logger do
  @moduledoc false

  require Logger

  def server_starting(command), do: Logger.info("Server starting with `#{command}`")
  def server_started(command), do: Logger.info("Server started with `#{command}`")
  def server_start_failed(command), do: Logger.error("Could not start server with `#{command}`")
  def server_stopped(reason), do: Logger.warning("scsynth server stopped with #{inspect(reason)}")
  def missing_executable(path), do: Logger.error("Could not find executable `#{path}`")
  def unexpected_message(msg), do: Logger.debug("Unexpected message: #{String.trim(msg)}")
end
