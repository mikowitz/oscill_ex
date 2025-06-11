defmodule OscillEx.Server.Config do
  @moduledoc """
  Stores config for the `scsynth` process server
  """
  defstruct [
    :executable,
    :port
  ]
end
