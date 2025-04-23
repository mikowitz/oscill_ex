defmodule OscillEx.Udp do
  @moduledoc """
  Manages a UDP connection

  ## Configuring the connection 

  `Udp` provides builder functions to programmatically build up a connection struct 
  by setting the host, the port, and whether the connection should try to read 
  reseponses it receives 

      iex> udp = Udp.new()
      ...>   |> Udp.with_host("example.com")
      ...>   |> Udp.with_port(8000)
      ...>   |> Udp.with_responses()

  If no host is specified, the value defaults to `"localhost"`.

  ## Opening the connection

  Once the connection has been constructed, it can be opened by calling

      iex> {:ok, udp} = Udp.open(udp)

  ## Sending data 

  Sending data is done via `Udp.send`, which takes a message in (bit)string format 
  as its second parameter

      iex> :ok = Udp.send(udp, "hello")

  If you have configured your connection to return a response, it will be in the form of `{:ok, data}`

      iex> {:ok, resp} = Udp.send(udp, "please reply")

  ## Closing the connection

      iex> :ok = Udp.close(udp)

  This will close the socket and unassign it from the returned struct.
  """

  alias OscillEx.Osc.Message.Parser
  alias OscillEx.Osc.Message

  defstruct [:port, :socket, host: "localhost", read_responses: false]

  @type t :: %__MODULE__{
          port: integer(),
          host: String.t(),
          read_responses: boolean()
        }

  def new, do: %__MODULE__{}

  def with_host(%__MODULE__{} = udp, host) when is_bitstring(host) do
    %__MODULE__{udp | host: host}
  end

  def with_port(%__MODULE__{} = udp, port) when is_integer(port) do
    %__MODULE__{udp | port: port}
  end

  def with_responses(%__MODULE__{} = udp) do
    %__MODULE__{udp | read_responses: true}
  end

  def open(%__MODULE__{host: host, port: port} = udp)
      when is_bitstring(host) and is_integer(port) do
    {:ok, socket} = :gen_udp.open(0, [:binary, active: false])

    {:ok, %__MODULE__{udp | socket: socket}}
  end

  def open(_), do: {:error, "cannot open UDP socket"}

  def send(%__MODULE__{} = udp, %Message{} = message) do
    message = Message.to_osc(message)
    __MODULE__.send(udp, message)
  end

  def send(
        %__MODULE__{host: host, port: port, read_responses: read_responses, socket: socket},
        message
      )
      when is_bitstring(message) do
    :ok = :gen_udp.send(socket, to_charlist(host), port, message)

    if read_responses do
      case :gen_udp.recv(socket, 0, 100) do
        {:ok, {_, _, packet}} -> Parser.parse(packet)
        other -> other
      end
    else
      :ok
    end
  end

  def close(%__MODULE__{socket: socket} = udp) do
    :ok = :gen_udp.close(socket)

    {:ok, %__MODULE__{udp | socket: nil}}
  end
end
