defmodule OscillEx.OSC do
  @moduledoc """
  Tools for encoding and decoding OSC messages

  ## OSC message format

  A basic OSC message consists of 3 parts:
  * an address
  * a type tag, an encoded representation of the types and number of arguments
  * the encoded arguments

  ### Address

  An address is an OSC string prefixed with the "/" character

  ### Type Tag

  The type tag is an OSC string beginning with the character "," followed by a
  sequence of characters corresponding to the arguments included in the message.
  `OscillEx` currently supports int32, float32, and string, encoded by the following
  type tags

  | type tag | argument type |
  |----------|---------------|
  | i        | int32         |
  | f        | float32       |
  | s        | OSC-string    |

  ### Arguments

  The arguments are a series of values matching the type tag signature preceding
  them in the message

  #### Data types

  **int32** - 32-bit big-endian two's complement integer

  **float32** - 32-bit big-endian IEEE 754 floating point number

  **OSC-string** - a sequence of non-null ASCII characters followed by 1-4
  null characters (`<<0>>`) in order to make the total number of bits a
  multiple of 32.

  """

  @doc """
  Encodes an address and argument list to a valid OSC message
  """
  def encode_message(address, arguments) do
    pad_four(address) <>
      type_tag_string(arguments) <>
      encoded_arguments(arguments)
  end

  defp pad_four(message) do
    padding_size = 4 - rem(byte_size(message), 4)
    message <> <<0::size(padding_size * 8)>>
  end

  defp type_tag_string([]), do: <<>>

  defp type_tag_string(arguments) do
    pad_four("," <> Enum.map_join(arguments, "", &type_tag/1))
  end

  defp type_tag(i) when is_integer(i), do: "i"
  defp type_tag(f) when is_float(f), do: "f"
  defp type_tag(s) when is_binary(s), do: "s"

  defp encoded_arguments([]), do: <<>>

  defp encoded_arguments(arguments) do
    Enum.map_join(arguments, "", &encode_argument/1)
  end

  defp encode_argument(i) when is_integer(i) do
    <<i::signed-size(32)>>
  end

  defp encode_argument(f) when is_float(f) do
    <<f::float-signed-size(32)>>
  end

  defp encode_argument(s) when is_binary(s) do
    pad_four(s)
  end
end
