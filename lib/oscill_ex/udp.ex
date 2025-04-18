defmodule OscillEx.Udp do
  defstruct [:port, :socket, :send_fn, host: "localhost", read_responses: false]

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

    send_fn = fn message ->
      :ok = :gen_udp.send(socket, to_charlist(host), port, message)

      if udp.read_responses do
        case :gen_udp.recv(socket, 0, 100) do
          {:ok, {_, _, packet}} -> {:ok, packet}
          other -> other
        end
      else
        :ok
      end
    end

    {:ok, %__MODULE__{udp | socket: socket, send_fn: send_fn}}
  end

  def open(_), do: {:error, "cannot open UDP socket"}

  def send(%__MODULE__{send_fn: send_fn}, message)
      when is_function(send_fn, 1) and is_bitstring(message) do
    send_fn.(message)
  end
end
