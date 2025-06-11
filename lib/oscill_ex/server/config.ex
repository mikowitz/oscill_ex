defmodule OscillEx.Server.Config do
  @moduledoc """
  Stores config for the `scsynth` process server
  """
  defstruct [
    :executable,
    :port,
    protocol: :udp
  ]

  def command_args(%__MODULE__{executable: exec, port: port, protocol: :udp}) do
    [exec, "-u", to_string(port)]
  end

  def command(%__MODULE__{} = config) do
    config |> command_args() |> Enum.join(" ")
  end
end
