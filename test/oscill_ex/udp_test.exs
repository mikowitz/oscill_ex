defmodule OscillEx.UdpTest do
  use ExUnit.Case, async: true

  alias OscillEx.Udp

  describe "building" do
    test "configures a socket with sufficient configuration" do
      {:ok, u} =
        Udp.new()
        |> Udp.with_host("example.com")
        |> Udp.with_port(7001)
        |> Udp.open()

      assert is_port(u.socket)
    end

    test "errors when trying to open socket without sufficient configuration" do
      assert {:error, "cannot open UDP socket"} =
               Udp.new()
               |> Udp.open()
    end

    test "defaults `host` to `localhost`" do
      {:ok, u} =
        Udp.new()
        |> Udp.with_port(7001)
        |> Udp.open()

      assert u.host == "localhost"
    end
  end

  describe "closing" do
    test "closing a connection removes the socket" do
      {:ok, u} =
        Udp.new()
        |> Udp.with_host("example.com")
        |> Udp.with_port(7001)
        |> Udp.open()

      socket = u.socket
      refute is_nil(Port.info(socket))
      {:ok, u} = Udp.close(u)

      assert is_nil(u.socket)
      assert is_nil(Port.info(socket))
    end
  end

  describe "sending messages" do
    test "when no response is expected" do
      {:ok, u} =
        Udp.new()
        |> Udp.with_port(7001)
        |> Udp.open()

      assert :ok = Udp.send(u, "hello")
    end

    test "when a response is expected" do
      {:ok, receiver} = :gen_udp.open(7001, [:binary, active: false])

      spawn(fn ->
        {:ok, {_, port, message}} = :gen_udp.recv(receiver, 0)
        :gen_udp.send(receiver, ~c'localhost', port, "received #{message}")
      end)

      {:ok, u} =
        Udp.new()
        |> Udp.with_port(7001)
        |> Udp.with_responses()
        |> Udp.open()

      assert {:ok, "received hello"} = Udp.send(u, "hello")
    end

    test "when waiting for a response times out" do
      {:ok, u} =
        Udp.new()
        |> Udp.with_port(7001)
        |> Udp.with_responses()
        |> Udp.open()

      assert Udp.send(u, "hello") == {:error, :timeout}
    end
  end
end
