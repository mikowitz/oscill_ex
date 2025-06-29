defmodule OscillEx.Server do
  @moduledoc """
  Manages a port running a configurable instance of `scsynth`
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

  @type t :: %__MODULE__{
          status: :stopped | :booting | :error | :crashed,
          error: term() | nil,
          port: port() | nil,
          monitor: reference() | nil,
          config: Config.t(),
          udp: UdpSocket.t() | nil
        }

  #########
  ## API ##
  #########

  def start_link(config \\ Config.new(publish_to_rendezvous: false, max_logins: 1)) do
    config = normalize_config(config)
    GenServer.start_link(__MODULE__, config)
  end

  def boot(pid) do
    GenServer.call(pid, :boot)
  end

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
      case validate_executable(config.executable) do
        :ok ->
          {:ok, port, monitor} = open_port(config)
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
      case handle_scsynth_error(data) do
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

  defp validate_executable(executable) do
    case File.stat(executable) do
      {:ok, %File.Stat{type: :regular}} ->
        if can_execute?(executable) do
          :ok
        else
          {:error, {:permission_denied, executable}}
        end

      {:ok, %File.Stat{type: type}} ->
        {:error, {:not_executable, "#{executable} is a #{type}, not an executable file"}}

      {:error, :enoent} ->
        {:error, {:file_not_found, executable}}
    end
  end

  defp can_execute?(executable) do
    case System.cmd("test", ["-x", executable]) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp close_port(%__MODULE__{monitor: monitor, port: port} = state) when is_reference(monitor) do
    Port.demonitor(monitor, [:flush])

    if is_port(port) and Port.info(port) != nil do
      Port.close(port)
    end

    %{state | monitor: nil, port: nil}
  end

  defp close_udp_socket(%__MODULE__{udp: udp} = state) do
    UdpSocket.close(udp)
    %{state | udp: nil}
  end

  defp normalize_config(config) when is_struct(config, Config), do: config
  defp normalize_config(config), do: struct(Config, Enum.into(config, %{}))

  defp set_status(state, status, error \\ nil), do: %{state | status: status, error: error}

  defp handle_scsynth_error(data) do
    Scsynth.parse_scsynth_error(data)
  end

  defp open_port(config) do
    args = Config.command_line_args(config)

    port =
      Port.open(
        {:spawn_executable, "./bin/wrapper"},
        [
          {:args, args},
          :binary,
          :exit_status
        ]
      )

    monitor = Port.monitor(port)

    {:ok, port, monitor}
  end
end
