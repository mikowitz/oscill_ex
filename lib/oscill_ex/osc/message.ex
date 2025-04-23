defmodule OscillEx.Osc.Message do
  @moduledoc """
  Models a message that can be encoded into OSC's format and sent over 
  a UDP connection.
  """
  alias OscillEx.Osc.ToOsc
  defstruct [:address, :parameters]

  @type osc_param :: integer() | number() | bitstring()
  @type t :: %__MODULE__{
          address: bitstring(),
          parameters: [osc_param()]
        }

  def new(address, parameters \\ []) do
    %__MODULE__{address: address, parameters: parameters}
  end

  def to_osc(%__MODULE__{} = message) do
    {?m, osc_message} = ToOsc.to_osc(message)
    osc_message
  end

  defimpl OscillEx.Osc.ToOsc do
    def to_osc(%@for{address: address, parameters: parameters}) do
      {?s, encoded_address} = @protocol.to_osc(address)

      if Enum.empty?(parameters) do
        {?m, encoded_address}
      else
        {type_tags, encoded_params} =
          parameters
          |> Enum.map(&@protocol.to_osc/1)
          |> Enum.unzip()

        {_, encoded_type_tags} =
          type_tags
          |> to_string()
          |> then(fn ts -> "," <> ts end)
          |> @protocol.to_osc()

        encoded_params =
          Enum.join(encoded_params, "")

        {?m, encoded_address <> encoded_type_tags <> encoded_params}
      end
    end
  end
end
