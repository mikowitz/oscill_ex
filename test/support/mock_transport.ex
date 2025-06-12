defmodule OscillEx.MockTransport do
  @moduledoc false
  alias OscillEx.OSC

  @behaviour OscillEx.Transport
  use GenServer

  defstruct messages: []

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl OscillEx.Transport
  def send_message(transport, port, address, arguments) do
    message = OSC.encode_message(address, arguments)
    send(transport, port, message)
  end

  @impl OscillEx.Transport
  def send(transport, port, message) do
    GenServer.cast(transport, {:record, port, message})
  end

  @impl GenServer
  def init(_) do
    {:ok, %__MODULE__{messages: []}}
  end

  def get_messages do
    GenServer.call(__MODULE__, :get_messages)
  end

  @impl GenServer
  def handle_call(:get_messages, _, %{messages: messages} = state) do
    {:reply, messages, state}
  end

  @impl GenServer
  def handle_cast({:record, port, message}, %__MODULE__{messages: messages} = state) do
    new_messages = [{port, message} | messages]
    {:noreply, %__MODULE__{state | messages: new_messages}}
  end
end
