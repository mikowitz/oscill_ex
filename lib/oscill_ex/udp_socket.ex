defmodule OscillEx.UdpSocket do
  @moduledoc """
  UDP socket management for OSC (Open Sound Control) communication.

  This module provides a simple interface for creating, managing, and using
  UDP sockets to communicate with `scsynth` servers. It handles socket lifecycle,
  monitoring, and message transmission with proper error handling.

  ## Usage

      # Open a UDP socket
      {:ok, socket_info} = UdpSocket.open()
      %{socket: socket, port: port_num, monitor: monitor} = socket_info

      # Send OSC messages
      message = <<...>>  # OSC-formatted binary data
      :ok = UdpSocket.send_message(socket, "127.0.0.1", 57120, message)

      # Clean up
      :ok = UdpSocket.close(socket_info)

  ## Socket Structure

  UDP sockets are represented as maps with the following fields:

  - `socket` - The actual UDP socket port
  - `port` - The local port number assigned to the socket
  - `monitor` - A monitor reference for the socket

  ## Error Handling

  The module handles socket creation, monitoring, and cleanup automatically.
  Sockets are opened in active mode to receive messages, and monitors are
  established to detect socket failures.
  """

  @type t :: %{
          socket: port() | nil,
          port: integer() | nil,
          monitor: reference() | nil
        }

  @doc """
  Opens a new UDP socket for OSC communication.

  Creates a UDP socket bound to an available port and establishes monitoring
  for the socket. The socket is opened in binary mode with active message
  reception enabled.

  ## Returns

  - `{:ok, socket_info}` - Socket created successfully with:
    - `socket` - The UDP socket port
    - `port` - The assigned local port number
    - `monitor` - Monitor reference for the socket

  ## Examples

      {:ok, socket_info} = UdpSocket.open()
      %{socket: socket, port: local_port, monitor: monitor} = socket_info
      IO.puts("Socket listening on port " <> to_string(local_port))
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

  Safely closes the socket and removes the monitor, handling cases where
  the socket or monitor may already be invalid. This function is safe to
  call multiple times.

  ## Parameters

  - `socket_info` - The socket map returned by `open/0`, or `nil`

  ## Returns

  - `nil` - Socket closed and cleaned up

  ## Examples

      {:ok, socket_info} = UdpSocket.open()
      nil = UdpSocket.close(socket_info)

      # Safe to call on nil
      nil = UdpSocket.close(nil)
  """
  @spec close(t() | nil) :: :ok
  def close(%{socket: socket, monitor: monitor}) do
    if is_reference(monitor) do
      Port.demonitor(monitor, [:flush])
    end

    if is_port(socket) && Port.info(socket) != nil do
      Port.close(socket)
    end

    :ok
  end

  def close(_), do: :ok

  @doc """
  Sends an OSC message through the UDP socket to the specified host and port.

  Transmits binary OSC data to a remote scsynth server using the UDP socket.
  The host address is automatically converted to the appropriate format.

  ## Parameters

  - `socket` - The UDP socket port to send from
  - `host` - Target host address as a string (e.g., "127.0.0.1")
  - `port` - Target port number
  - `message` - Binary OSC message data

  ## Returns

  - `:ok` - Message sent successfully
  - `{:error, reason}` - Send operation failed

  ## Examples

      {:ok, %{socket: socket}} = UdpSocket.open()
      osc_message = <<...>>  # Binary OSC data
      :ok = UdpSocket.send_message(socket, "127.0.0.1", 57120, osc_message)

      # Send to remote server
      :ok = UdpSocket.send_message(socket, "192.168.1.100", 57110, osc_message)
  """
  @spec send_message(port(), String.t(), integer(), binary()) :: :ok | {:error, atom()}
  def send_message(socket, host, port, message) when is_port(socket) and is_binary(message) do
    :gen_udp.send(socket, to_charlist(host), port, message)
  end
end
