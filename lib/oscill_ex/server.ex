defmodule OscillEx.Server do
  @moduledoc """
  Manages running an `scsynth` process that can receive OSC messages.
  """

  use GenServer

  require Logger

  # credo:disable-for-next-line Credo.Check.Readability.LargeNumbers
  @default_port 57110

  defstruct [
    :scsynth_port,
    :scsynth_port_monitor,
    :server_config
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :server_name, __MODULE__))
  end

  @impl true
  def init(opts) do
    raw_server_config = Keyword.get(opts, :server_config, [])

    path = lookup_server_config_value(:executable, raw_server_config, "scsynth")

    case port_helper().find_executable(path) do
      nil ->
        Logger.error("Could not find executable `#{path}`")
        {:stop, :missing_scsynth_executable}

      executable ->
        server_config = %__MODULE__.Config{
          port: lookup_server_config_value(:port, raw_server_config, @default_port),
          executable: executable
        }

        case start_scsynth_port(server_config) do
          {:ok, port, monitor} ->
            {:ok,
             %__MODULE__{
               scsynth_port: port,
               scsynth_port_monitor: monitor,
               server_config: server_config
             }}

          _ ->
            {:stop, :could_not_start_scsynth}
        end
    end
  end

  @impl true
  def handle_info({port, {:data, message}}, %__MODULE__{scsynth_port: port} = state) do
    Logger.info(String.trim(message))
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :port, port, reason}, %__MODULE__{scsynth_port: port} = state) do
    Logger.warning("scsynth server stopped: #{inspect(reason)}. Attempting to restart")
    Port.demonitor(state.scsynth_port_monitor)

    case start_scsynth_port(state.server_config) do
      {:ok, port, monitor} ->
        {:noreply,
         %__MODULE__{
           state
           | scsynth_port: port,
             scsynth_port_monitor: monitor
         }}

      _ ->
        {:stop, :could_not_start_scsynth}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp lookup_server_config_value(key, config, default) do
    Keyword.get(config, key, Application.get_env(:oscill_ex, key, default))
  end

  defp start_scsynth_port(%{executable: executable, port: port}) do
    command_to_run = "#{executable} -u #{port}"
    Logger.info("Server starting with #{command_to_run}")

    scsynth_port =
      port_helper().open(
        {:spawn_executable, "./bin/scsynth_wrapper"},
        [:binary, args: [executable, "-u", to_string(port)]]
      )

    case port_helper().info(scsynth_port) do
      nil ->
        Logger.error("Could not start `#{command_to_run}`")
        nil

      _ ->
        Logger.info("Server started with `#{command_to_run}`")
        monitor = Port.monitor(scsynth_port)

        {:ok, scsynth_port, monitor}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
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
end
