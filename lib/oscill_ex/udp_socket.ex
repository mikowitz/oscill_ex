defmodule OscillEx.UdpSocket do
  @moduledoc """
  Manages UDP socket connections for OSC communication with scsynth.
  """

  @type t :: %{
          socket: port() | nil,
          port: integer() | nil,
          monitor: reference() | nil
        }

  @doc """
  Opens a new UDP socket for OSC communication.

  Returns `{:ok, socket, port_number, monitor_ref}` on success.
  """
  @spec open() :: {:ok, t()}
  def open do
    {:ok, udp_socket} = :gen_udp.open(0, [:binary, {:active, true}])
    {:ok, udp_port} = :inet.port(udp_socket)
    udp_monitor = Port.monitor(udp_socket)

    {:ok, %{socket: udp_socket, port: udp_port, monitor: udp_monitor}}
  end

  @doc """
  Closes a UDP socket connection and cleans up monitoring.

  Takes a UDP socket map and returns `nil`.
  """
  @spec close(t() | nil) :: nil
  def close(%{socket: socket, monitor: monitor}) do
    if is_reference(monitor) do
      Port.demonitor(monitor, [:flush])
    end

    if is_port(socket) && Port.info(socket) != nil do
      Port.close(socket)
    end

    nil
  end

  def close(nil), do: nil

  @doc """
  Sends an OSC message through the UDP socket to the specified host and port.

  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @spec send_message(port(), String.t(), integer(), binary()) :: :ok | {:error, atom()}
  def send_message(socket, host, port, message) when is_port(socket) and is_binary(message) do
    :gen_udp.send(socket, to_charlist(host), port, message)
  end
end
