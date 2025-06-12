defmodule OscillEx.Server do
  @moduledoc """
  Manages running an `scsynth` process that can receive OSC messages.
  """
  use GenServer

  alias OscillEx.Logger
  alias OscillEx.ScsynthProcess
  alias OscillEx.Server.Config

  @typedoc """
  Process state for the server

  * `:scsynth_port` - the `Port` representing the running `scsynth` process
  * `:scsynth_monitor` - the `Reference` pointing to the process's monitor
  * `:server_config` - a `Config` struct holding the configuration options for the process
  * `:transport` - the transport layer implementation for sending messages to the `scsynth` process
  """
  @type t :: %__MODULE__{
          scsynth_port: port() | nil,
          scsynth_monitor: reference() | nil,
          server_config: Config.t() | nil,
          transport: {atom(), pid()}
        }

  defstruct [
    :scsynth_port,
    :scsynth_monitor,
    :server_config,
    :transport
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :server_name, __MODULE__))
  end

  @doc """
  Starts the `scsynth` server
  """
  def boot(opts \\ []) do
    start_link(opts)
  end

  @doc """
  Stops the `scsynth` server
  """
  def quit do
    send_message("/quit")
  end

  def send_message(address, params \\ []) do
    GenServer.cast(__MODULE__, {:send, address, params})
  end

  def send(message) do
    GenServer.cast(__MODULE__, {:send, message})
  end

  @impl true
  def init(opts) do
    raw_server_config = Keyword.get(opts, :server_config, [])

    transport =
      Keyword.get(
        opts,
        :transport,
        Application.get_env(:oscill_ex, :transport, OscillEx.UDPTransport)
      )

    with {:ok, config} <- Config.build(raw_server_config),
         {:ok, port, monitor} <- ScsynthProcess.start(config) do
      {:ok, transport_pid} = transport.start_link()

      {:ok,
       %__MODULE__{
         scsynth_port: port,
         scsynth_monitor: monitor,
         server_config: config,
         transport: {transport, transport_pid}
       }}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_cast(
        {:send, message},
        %__MODULE__{server_config: config, transport: {mod, pid}} = state
      ) do
    mod.send(pid, config.port, message)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(
        {:send, address, params},
        %__MODULE__{server_config: config, transport: {mod, pid}} = state
      ) do
    mod.send_message(pid, config.port, address, params)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _, :port, port, reason}, %__MODULE__{scsynth_port: port} = state) do
    {:stop, reason, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, %__MODULE__{transport: {_, transport}} = state) do
    Port.demonitor(state.scsynth_monitor)
    send(transport, {:quit, reason})
    Logger.server_quit()
  end

  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
