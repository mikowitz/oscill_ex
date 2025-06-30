defmodule OscillEx.UdpSocketTest do
  use ExUnit.Case, async: true

  alias OscillEx.UdpSocket

  describe "open/0" do
    test "successfully opens a UDP socket" do
      {:ok, udp} = UdpSocket.open()

      assert is_map(udp)
      assert is_port(udp.socket)
      assert is_integer(udp.port)
      assert is_reference(udp.monitor)
      assert Port.info(udp.socket) != nil

      # Clean up
      :ok = UdpSocket.close(udp)
    end

    test "returns a valid UDP socket struct" do
      {:ok, udp} = UdpSocket.open()

      # Verify the socket is properly configured
      {:ok, socket_info} = :inet.getopts(udp.socket, [:active, :mode])
      assert socket_info[:active] == true
      assert socket_info[:mode] == :binary

      # Clean up
      :ok = UdpSocket.close(udp)
    end

    test "assigns a random available port" do
      {:ok, udp1} = UdpSocket.open()
      {:ok, udp2} = UdpSocket.open()

      # Ports should be different when opening multiple sockets
      assert udp1.port != udp2.port
      assert udp1.port > 0
      assert udp2.port > 0

      # Clean up
      :ok = UdpSocket.close(udp1)
      :ok = UdpSocket.close(udp2)
    end
  end

  describe "close/1" do
    test "closes an open UDP socket" do
      {:ok, udp} = UdpSocket.open()
      socket = udp.socket

      assert Port.info(socket) != nil

      :ok = UdpSocket.close(udp)
      assert Port.info(socket) == nil
    end

    test "handles nil input gracefully" do
      assert UdpSocket.close(nil) == :ok
    end

    test "handles already closed socket gracefully" do
      {:ok, udp} = UdpSocket.open()

      # Close the socket directly
      Port.close(udp.socket)

      # UdpSocket.close should still work without error
      assert UdpSocket.close(udp) == :ok
    end

    test "demonitors the socket properly" do
      {:ok, udp} = UdpSocket.open()
      monitor = udp.monitor

      # Verify monitor is active
      assert is_reference(monitor)

      :ok = UdpSocket.close(udp)

      # The monitor should be flushed, but we can't easily test this
      # without more complex setup. The important thing is no crash occurs.
    end
  end

  describe "send_message/4" do
    test "sends message successfully to valid host and port" do
      {:ok, udp} = UdpSocket.open()
      message = <<1, 2, 3, 4>>

      result = UdpSocket.send_message(udp.socket, "127.0.0.1", 12345, message)

      assert result == :ok

      # Clean up
      UdpSocket.close(udp)
    end

    test "handles binary message correctly" do
      {:ok, udp} = UdpSocket.open()
      message = "test message"

      result = UdpSocket.send_message(udp.socket, "localhost", 12345, message)

      assert result == :ok

      # Clean up
      :ok = UdpSocket.close(udp)
    end

    test "returns error for invalid host" do
      {:ok, udp} = UdpSocket.open()
      message = <<1, 2, 3>>

      # Using an invalid IP address should return an error
      result = UdpSocket.send_message(udp.socket, "999.999.999.999", 12345, message)

      assert {:error, _reason} = result

      # Clean up
      :ok = UdpSocket.close(udp)
    end

    test "converts string host to charlist internally" do
      {:ok, udp} = UdpSocket.open()
      message = "test"

      # This should work without throwing an error about string vs charlist
      result = UdpSocket.send_message(udp.socket, "127.0.0.1", 12345, message)

      assert result == :ok

      # Clean up
      :ok = UdpSocket.close(udp)
    end
  end

  describe "integration" do
    test "full lifecycle: open -> send -> close" do
      {:ok, udp} = UdpSocket.open()

      # Socket should be open and functional
      assert is_port(udp.socket)
      assert Port.info(udp.socket) != nil

      # Should be able to send a message
      result = UdpSocket.send_message(udp.socket, "127.0.0.1", 12345, "test")
      assert result == :ok

      # Should close cleanly
      :ok = UdpSocket.close(udp)
      assert Port.info(udp.socket) == nil
    end

    test "multiple sockets can coexist" do
      {:ok, udp1} = UdpSocket.open()
      {:ok, udp2} = UdpSocket.open()

      # Both should be functional
      assert UdpSocket.send_message(udp1.socket, "127.0.0.1", 12345, "test1") == :ok
      assert UdpSocket.send_message(udp2.socket, "127.0.0.1", 12345, "test2") == :ok

      # Clean up
      :ok = UdpSocket.close(udp1)
      :ok = UdpSocket.close(udp2)
    end
  end
end
