defmodule OscillEx.Server do
  use GenServer

  require Logger

  @default_port 57110

  defstruct [
    :scsynth_executable,
    :scsynth_port,
    :scsynth_port_monitor,
    :server_config
  ]

  def start(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :server_name, __MODULE__))
  end

  @impl true
  def init(opts) do
    path = find_scsynth_executable(opts)

    case port_helper().find_executable(path) do
      nil ->
        {:stop, :missing_scsynth_executable}

      executable ->
        server_config = Keyword.get(opts, :server_config, [])
        port = Keyword.get(server_config, :port, @default_port)

        scsynth_port =
          port_helper().open(
            {:spawn_executable, "./bin/scsynth_wrapper"},
            [:binary, args: [executable, "-u", to_string(port)]]
          )

        case port_helper().info(scsynth_port) do
          nil ->
            {:stop, :could_not_start_scsynth}

          _ ->
            Logger.info("Server started with `#{executable} -u #{port}`")
            monitor = Port.monitor(scsynth_port)

            {:ok,
             %__MODULE__{
               scsynth_executable: executable,
               scsynth_port: scsynth_port,
               scsynth_port_monitor: monitor,
               server_config: [
                 port: port
               ]
             }}
        end
    end
  end

  @behaviour OscillEx.PortHelper
  @impl true
  defdelegate find_executable(path), to: System
  @impl true
  defdelegate open(port, options), to: Port
  @impl true
  defdelegate info(port), to: Port

  defp port_helper do
    Application.get_env(:oscill_ex, :port_helper, __MODULE__)
  end

  defp find_scsynth_executable(opts) do
    Keyword.get(
      opts,
      :scsynth_executable,
      Application.get_env(
        :oscill_ex,
        :scsynth_executable,
        "scsynth"
      )
    )
  end
end
