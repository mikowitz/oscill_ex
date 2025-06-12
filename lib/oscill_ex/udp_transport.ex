defmodule OscillEx.UDPTransport do
  @moduledoc """
  Implementation of the generic `Transport` for `udp`
  """

  use GenServer

  defstruct [:socket]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(_) do
    {:ok, socket} = :gen_udp.open(0)
    {:ok, %__MODULE__{socket: socket}}
  end

  def send(transport, port, message) do
    GenServer.cast(transport, {:send, port, message})
  end

  def handle_cast({:send, port, message}, %__MODULE__{socket: sock} = state) do
    :ok = :gen_udp.send(sock, {127, 0, 0, 1}, port, message)
    {:noreply, state}
  end

  def terminate(_reason, %__MODULE__{socket: sock}) do
    :gen_udp.close(sock)
    :ok
  end
end
