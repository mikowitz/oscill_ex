defmodule OscillEx do
  @moduledoc """
  Documentation for `OscillEx`.
  """

  def start_server(opts) do
    Supervisor.start_child(OscillEx.Supervisor, OscillEx.Server.child_spec(opts))
  end
end
