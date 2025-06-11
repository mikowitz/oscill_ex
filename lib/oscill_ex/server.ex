defmodule OscillEx.Server do
  @moduledoc """
  Manages running an `scsynth` process that can receive OSC messages.
  """
  use GenServer

  require Logger

  alias OscillEx.ScsynthProcess

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

    with {:ok, config} <- __MODULE__.Config.build(raw_server_config),
         {:ok, port, monitor} <- ScsynthProcess.start(config) do
      {:ok,
       %__MODULE__{
         scsynth_port: port,
         scsynth_port_monitor: monitor,
         server_config: config
       }}
    else
      {:error, {:missing_executable, path}} ->
        Logger.error("Could not find executable `#{path}`")
        {:stop, :missing_scsynth_executable}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({port, {:data, message}}, %__MODULE__{scsynth_port: port} = state) do
    Logger.info(String.trim(message))
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, _, :port, port, reason},
        %__MODULE__{scsynth_port: port, server_config: config, scsynth_port_monitor: monitor} =
          state
      ) do
    Logger.warning("scsynth server stopped: #{inspect(reason)}. Attempting to restart")
    Port.demonitor(state.scsynth_port_monitor)

    case ScsynthProcess.restart(config, monitor) do
      {:ok, new_port, new_monitor} ->
        {:noreply,
         %__MODULE__{
           state
           | scsynth_port: new_port,
             scsynth_port_monitor: new_monitor
         }}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
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
end
