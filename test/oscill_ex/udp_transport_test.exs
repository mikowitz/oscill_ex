defmodule OscillEx.UDPTransportTest do
  use ExUnit.Case, async: true

  alias OscillEx.UDPTransport

  describe "start_link/1" do
    test "starts with a running udp socket" do
      {:ok, transport} = UDPTransport.start_link()

      %{socket: socket} = :sys.get_state(transport)

      assert is_port(socket)
      assert Port.info(socket)[:name] == ~c"udp_inet"
    end
  end

  describe "send/3" do
    test "sends the message to the specified port on localhost" do
      {:ok, target} = :gen_udp.open(0)
      {:ok, target_port} = :inet.port(target)

      {:ok, transport} = UDPTransport.start_link()

      :ok = UDPTransport.send(transport, target_port, "hello")

      receive do
        {:udp, ^target, _, _, msg} -> assert to_string(msg) == "hello"
      end

      :ok = :gen_udp.close(target)
    end
  end

  describe "shutdown" do
    test "closes the port when the GenServer process is terminated" do
      {:ok, transport} = UDPTransport.start_link()

      %{socket: socket} = :sys.get_state(transport)

      refute is_nil(Port.info(socket))

      GenServer.stop(transport)

      assert is_nil(Port.info(socket))
    end
  end
end
