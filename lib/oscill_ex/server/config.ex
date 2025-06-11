# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
defmodule OscillEx.Server.Config do
  @moduledoc """
  Stores config for the `scsynth` process server
  """
  defstruct [
    :executable,
    :port,
    :protocol
  ]

  def build(config \\ []) do
    with {:ok, executable} <- resolve_config_value(:executable, config, "scsynth"),
         {:ok, port} <- resolve_config_value(:port, config, 57110) do
      {:ok,
       %__MODULE__{
         executable: executable,
         port: port,
         protocol: lookup_config_value(:protocol, config, :udp)
       }}
    end
  end

  def command_args(%__MODULE__{executable: exec, port: port, protocol: :udp}) do
    [exec, "-u", to_string(port)]
  end

  def command(%__MODULE__{} = config) do
    config |> command_args() |> Enum.join(" ")
  end

  defp resolve_config_value(:executable, config, default) do
    path = lookup_config_value(:executable, config, default)

    case port_helper().find_executable(path) do
      nil -> {:error, {:missing_executable, path}}
      executable -> {:ok, executable}
    end
  end

  defp resolve_config_value(key, config, default) do
    {:ok, lookup_config_value(key, config, default)}
  end

  defp lookup_config_value(key, config, default) do
    Keyword.get(config, key, Application.get_env(:oscill_ex, key, default))
  end

  defp port_helper do
    Application.get_env(:oscill_ex, :port_helper, OscillEx.SystemPortHelper)
  end
end
