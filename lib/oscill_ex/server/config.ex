# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
defmodule OscillEx.Server.Config do
  @moduledoc """
  Configuration for the `scsynth` process server
  """

  @typedoc """
  Configuration options for the scsynth server

  * `:executable` - Path to the scsynth executable
  * `:port` - Port number for OSC communication (defaults to 57110)
  * `:protocol` - Communication protocol: `:udp` (default) or `:tcp`

  """
  @type t :: %__MODULE__{
          executable: String.t(),
          port: pos_integer(),
          protocol: :udp | :tcp
        }

  @enforce_keys [:executable, :port, :protocol]
  defstruct [
    :executable,
    :port,
    :protocol
  ]

  @default_executable "scsynth"
  @default_port 57110
  @default_protocol :udp

  alias OscillEx.Logger
  import OscillEx, only: [port_helper: 0]

  def build(config \\ []) do
    with {:ok, executable} <- resolve_config_value(:executable, config, @default_executable),
         {:ok, port} <- resolve_config_value(:port, config, @default_port),
         {:ok, protocol} <- resolve_config_value(:protocol, config, @default_protocol) do
      {:ok,
       %__MODULE__{
         executable: executable,
         port: port,
         protocol: protocol
       }}
    end
  end

  def command_list(%__MODULE__{executable: exec} = config) do
    [exec | protocol_args(config)]
  end

  def command_string(%__MODULE__{} = config) do
    config |> command_list() |> Enum.join(" ")
  end

  defp protocol_args(%__MODULE__{port: port, protocol: protocol}),
    do: [protocol_flag(protocol), to_string(port)]

  defp protocol_flag(:udp), do: "-u"
  defp protocol_flag(:tcp), do: "-t"

  defp resolve_config_value(:executable, config, default) do
    path = lookup_config_value(:executable, config, default)
    validate_executable(path)
  end

  defp resolve_config_value(key, config, default) do
    {:ok, lookup_config_value(key, config, default)}
  end

  defp lookup_config_value(key, config, default) do
    Keyword.get(config, key, Application.get_env(:oscill_ex, key, default))
  end

  def validate_executable(path) do
    case port_helper().find_executable(path) do
      nil ->
        Logger.missing_executable(path)
        {:error, :missing_scsynth_executable}

      executable ->
        {:ok, executable}
    end
  end
end
