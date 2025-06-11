defmodule OscillEx.Server do
  @moduledoc """
  Manages running an `scsynth` process that can receive OSC messages.
  """
  use GenServer

  require Logger

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

    case __MODULE__.Config.build(raw_server_config) do
      {:ok, server_config} ->
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

      {:error, {:missing_executable, path}} ->
        Logger.error("Could not find executable `#{path}`")
        {:stop, :missing_scsynth_executable}
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

  defp start_scsynth_port(%__MODULE__.Config{} = server_config) do
    command_to_run = __MODULE__.Config.command(server_config)
    command_args = __MODULE__.Config.command_args(server_config)
    Logger.info("Server starting with #{command_to_run}")

    scsynth_port =
      port_helper().open(
        {:spawn_executable, "./bin/scsynth_wrapper"},
        [:binary, args: command_args]
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

  defp port_helper do
    Application.get_env(:oscill_ex, :port_helper, OscillEx.SystemPortHelper)
  end
end
