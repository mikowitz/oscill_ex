defmodule OscillEx.Server do
  @moduledoc """
  A GenServer that manages a configurable `scsynth` process with OSC communication.

  This module provides a complete lifecycle management for SuperCollider's synthesis
  server (`scsynth`), including process spawning, UDP socket management, and OSC
  message handling. The server maintains a state machine with proper error handling
  and crash recovery.

  ## Usage

      # Start a server with default configuration
      {:ok, pid} = OscillEx.Server.start_link()

      # Start with custom configuration
      config = %OscillEx.Server.Config{
        port: 57120,
        ip_address: {127, 0, 0, 1},
        num_audio_bus_channels: 128
      }
      {:ok, pid} = OscillEx.Server.start_link(config)

      # Boot the scsynth process
      :ok = OscillEx.Server.boot(pid)

      # Send OSC messages
      message = <<...>>  # OSC-formatted binary data
      :ok = OscillEx.Server.send_osc_message(pid, message)

      # Shut down the server
      :ok = OscillEx.Server.quit(pid)

  ## State Machine

  The server operates in the following states:

  - `:stopped` - Initial state, no processes running
  - `:running` - scsynth process and UDP socket are active
  - `:error` - Failed to start due to configuration or system error
  - `:crashed` - Process terminated unexpectedly

  ## Error Handling

  The server handles various failure scenarios:

  - Invalid executable paths or permissions
  - Port conflicts and network errors
  - Process crashes and unexpected termination
  - UDP socket failures with automatic recovery
  """
  alias OscillEx.Scsynth
  alias OscillEx.Server.Config
  alias OscillEx.UdpSocket

  require Logger

  use GenServer

  defstruct status: :stopped,
            error: nil,
            port: nil,
            monitor: nil,
            config: nil,
            udp: nil

  @type server_status :: :stopped | :running | :error | :crashed
  @type t :: %__MODULE__{
          status: server_status(),
          error: term() | nil,
          port: port() | nil,
          monitor: reference() | nil,
          config: Config.t(),
          udp: UdpSocket.t() | nil
        }

  #########
  ## API ##
  #########

  @doc """
  Starts a new Server GenServer process.

  ## Parameters

  - `config` - Server configuration. Can be a `Config` struct, map, or keyword list.
    Defaults to a basic configuration suitable for local development.

  ## Returns

  - `{:ok, pid}` - Server process started successfully
  - `{:error, reason}` - Failed to start the GenServer

  ## Examples

      # Start with default configuration
      {:ok, pid} = Server.start_link()

      # Start with custom config struct
      config = %Config{port: 57121, num_audio_bus_channels: 64}
      {:ok, pid} = Server.start_link(config)

      # Start with keyword list
      {:ok, pid} = Server.start_link(port: 57122, ip_address: {192, 168, 1, 100})
  """
  @spec start_link(Config.t() | map() | keyword()) :: GenServer.on_start()
  def start_link(config \\ Config.default()) do
    config = normalize_config(config)
    GenServer.start_link(__MODULE__, config)
  end

  @doc """
  Boots the scsynth process and establishes UDP communication.

  This starts the external `scsynth` executable with the configured parameters
  and opens a UDP socket for OSC message communication.

  ## Parameters

  - `pid` - The Server process identifier

  ## Returns

  - `:ok` - Server booted successfully and is now running
  - `{:error, :already_running}` - Server is already booted or booting
  - `{:error, reason}` - Boot failed due to system error, invalid config, etc.

  ## Examples

      {:ok, pid} = Server.start_link()
      :ok = Server.boot(pid)

      # Attempting to boot an already running server
      {:error, :already_running} = Server.boot(pid)
  """
  @spec boot(pid()) :: :ok | {:error, atom()}
  def boot(pid) do
    GenServer.call(pid, :boot)
  end

  @doc """
  Gracefully shuts down the scsynth process and closes the UDP socket.

  This terminates the running `scsynth` process and cleans up all associated
  resources including the UDP socket and port monitors.

  ## Parameters

  - `pid` - The Server process identifier

  ## Returns

  - `:ok` - Server shut down successfully

  ## Examples

      {:ok, pid} = Server.start_link()
      Server.boot(pid)
      :ok = Server.quit(pid)

      # Quitting an already stopped server is safe
      :ok = Server.quit(pid)
  """
  @spec quit(pid()) :: :ok
  def quit(pid) do
    GenServer.call(pid, :quit)
  end

  @doc """
  Sends an OSC message to the running scsynth server.

  Returns `:ok` on success, or `{:error, reason}` on failure.

  ## Examples

      iex> {:ok, pid} = Server.start_link()
      iex> Server.boot(pid)
      iex> Server.send_osc_message(pid, <<1, 2, 3>>)
      :ok

      iex> {:ok, pid} = Server.start_link()
      iex> Server.send_osc_message(pid, <<1, 2, 3>>)
      {:error, :not_running}

  ## Error cases

  - `{:error, :not_running}` - Server is not in running state
  - `{:error, :no_udp_socket}` - UDP socket is not available
  - `{:error, reason}` - UDP send operation failed
  """
  @spec send_osc_message(pid(), binary()) :: :ok | {:error, atom()}
  def send_osc_message(pid, message) when is_binary(message) do
    GenServer.call(pid, {:send_osc_message, message})
  end

  ###############
  ## CALLBACKS ##
  ###############

  @impl GenServer
  def init(config) do
    {:ok, %__MODULE__{config: config}}
  end

  @impl GenServer
  def handle_call({:send_osc_message, message}, _from, %__MODULE__{status: :running} = state) do
    %__MODULE__{config: %Config{ip_address: host, port: port}, udp: %{socket: socket}} = state

    case UdpSocket.send_message(socket, host, port, message) do
      :ok -> {:reply, :ok, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:send_osc_message, _message}, _from, %__MODULE__{udp: nil} = state) do
    {:reply, {:error, :no_udp_socket}, state}
  end

  def handle_call({:send_osc_message, _message}, _from, %__MODULE__{} = state) do
    {:reply, {:error, :not_running}, state}
  end

  def handle_call(:boot, _, %__MODULE__{status: status} = state)
      when status in [:booting, :running] do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call(:boot, _, %{config: config} = state) do
    {reply, new_state} =
      case Scsynth.start_process(config) do
        {:ok, port, monitor} ->
          {:ok, udp} = UdpSocket.open()

          {:ok,
           %{
             state
             | port: port,
               monitor: monitor,
               udp: udp
           }
           |> set_status(:running)}

        {:error, error} = error_tuple ->
          {error_tuple, set_status(state, :error, error)}
      end

    {:reply, reply, new_state}
  end

  def handle_call(:quit, _, %__MODULE__{status: :stopped} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:quit, _, %__MODULE__{port: port} = state) when is_port(port) do
    new_state = close_port(state) |> close_udp_socket() |> set_status(:stopped)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info({port, {:exit_status, exit_code}}, %__MODULE__{port: port} = state) do
    new_state = close_port(state) |> close_udp_socket()
    error = Scsynth.handle_exit_status(exit_code)

    case exit_code do
      0 ->
        {:noreply, set_status(new_state, :stopped, error)}

      _ ->
        {:noreply, new_state |> set_status(:crashed, error)}
    end
  end

  def handle_info({port, {:exit_status, _exit_code}}, %__MODULE__{udp: %{socket: port}} = state) do
    new_state = close_udp_socket(state)

    {:ok, udp} = UdpSocket.open()

    new_state = %{new_state | udp: udp}

    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :port, port, reason}, %__MODULE__{port: port} = state) do
    error = Scsynth.handle_port_down(reason)
    new_state = close_port(state) |> close_udp_socket() |> set_status(:crashed, error)
    {:noreply, new_state}
  end

  def handle_info({:DOWN, _, :port, port, _reason}, %__MODULE__{udp: %{socket: port}} = state) do
    new_state = close_udp_socket(state)

    {:ok, udp} = UdpSocket.open()

    new_state = %{new_state | udp: udp}

    {:noreply, new_state}
  end

  def handle_info({port, {:data, data}}, %__MODULE__{port: port} = state) do
    new_state =
      case Scsynth.parse_scsynth_error(data) do
        :ok ->
          state

        {:error, error} ->
          state
          |> close_port()
          |> close_udp_socket()
          |> set_status(:crashed, {:exit, error})
      end

    {:noreply, new_state}
  end

  def handle_info(
        {:udp, socket, _, port, message},
        %__MODULE__{
          config: %Config{port: port},
          udp: %{socket: socket}
        } = state
      ) do
    Logger.info("UDP message from #{port}: #{inspect(message)}")
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.info("unexpected message: #{inspect(info)}")
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, %__MODULE__{status: :running} = state) do
    state
    |> close_port()
    |> close_udp_socket()

    :ok
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp close_port(%__MODULE__{monitor: monitor, port: port} = state) do
    Scsynth.close_port(port, monitor)
    %{state | monitor: nil, port: nil}
  end

  defp close_udp_socket(%__MODULE__{udp: udp} = state) do
    UdpSocket.close(udp)
    %{state | udp: nil}
  end

  defp normalize_config(config) when is_struct(config, Config), do: config
  defp normalize_config(config), do: struct(Config, Enum.into(config, %{}))

  defp set_status(state, status, error \\ nil), do: %{state | status: status, error: error}
end
