defprotocol OscillEx.Osc.ToOsc do
  @moduledoc """
  Protocol for converting Elixir terms to {`type_tag`, `value`} pairs usable in 
  constructing an OSC message.

  These pairs can represent the following types:

  ## Integer

  OSC integers are 32-bit, big-endian, two's complement integers

  The `type_key` for integers is `?i`

  ### Examples

  The value `1` would be represented by the pair 

      {?i, <<0, 0, 0, 1>>}

  The value `-1` would be represented by the pair 

      {?i, <<255, 255, 255, 255>>}

  ## Float 

  OSC floats are 32-bit, big-endian, IEEE 754 floating point values

  The `type_key` for floats is `?f`

  ### Examples

  The value `1.0` would be represented by the pair 

      {?f, <<63, 128, 0, 0>>}

  The value `-:math.pi` would be represented by the pair 

      {?f, <<<192, 73, 15, 219>>}

  ## String

  OSC strings are a sequence of non-null ASCII characters, followed by a null, padded
  by the correct number of additional null characters to make the total number of bytes 
  a multiple of 4.

  The `type_key` for strings is `?s`

  ### Example

  The value `"hello"` would be represented by the pair 

      {?s, <<104, 101, 108, 108, 111, 0, 0, 0>>}

  ## Blob

  OSC blobs are arbitrary sized binary data, preceded by a 32-bit integer (see above) encoding 
  the length of the data, and padded with 0-3 null characters to bring the total byte size 
  to a multiple of 4

  The `type_key` for blobs is `?b`

  ### Examples 

  The value `<<1, 2, 3, 4>>` would be represented by the pair 

      {?b, <<0, 0, 0, 4, 1, 2, 3, 4>>}

  The value `<<1, 2, 3, 4, 5>>` would be represented by the pair 

      {?b, <<0, 0, 0, 5, 1, 2, 3, 4, 5, 0, 0, 0>>}

  """

  @spec to_osc(term()) :: {char(), binary()}
  def to_osc(x)
end

defimpl OscillEx.Osc.ToOsc, for: Integer do
  def to_osc(i) do
    {?i, <<i::size(32)>>}
  end
end

defimpl OscillEx.Osc.ToOsc, for: Float do
  def to_osc(f) do
    {?f, <<f::float-size(32)>>}
  end
end

defimpl OscillEx.Osc.ToOsc, for: BitString do
  def to_osc(s) do
    # if String.printable?(s) do
    if Enum.all?(to_charlist(s), &(&1 in 32..126)) do
      unpadded = <<s::binary, 0>>

      padding_size =
        case rem(byte_size(unpadded), 4) do
          0 -> 0
          n -> 4 - n
        end

      padding = <<0::integer-size(padding_size * 8)>>
      {?s, unpadded <> padding}
    else
      unpadded = <<byte_size(s)::size(32), s::binary>>

      padding_size =
        case rem(byte_size(unpadded), 4) do
          0 -> 0
          n -> 4 - n
        end

      padding = <<0::integer-size(padding_size * 8)>>
      {?b, unpadded <> padding}
    end
  end
end
