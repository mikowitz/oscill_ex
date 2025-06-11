defmodule OscillEx do
  @moduledoc """
  Documentation for `OscillEx`.
  """

  @sup OscillEx.Supervisor
  @server OscillEx.Server

  def start_server(opts \\ []) do
    Supervisor.start_child(@sup, @server.child_spec(opts))
  end

  def stop_server do
    Supervisor.terminate_child(@sup, @server)
    Supervisor.delete_child(@sup, @server)
  end

  def port_helper do
    Application.get_env(:oscill_ex, :port_helper, OscillEx.SystemPortHelper)
  end
end
