defmodule OscillEx.Osc.Message.Parser do
  @moduledoc """
  Module for parsing incoming OSC messages into their address and parameters
  """
  alias EarmarkParser.Message
  alias OscillEx.Osc.Message

  @error {:error, :invalid_osc_message}

  def parse(message) when is_bitstring(message) do
    case parse_string(message, "") do
      {:ok, address, rest} ->
        case rest do
          "" ->
            {:ok, Message.new(address)}

          _ ->
            message_with_parameters(address, rest)
        end

      _ ->
        @error
    end
  end

  defp parse_string(<<0, rest::binary>>, acc) do
    case rem(byte_size(acc) + 1, 4) do
      0 ->
        <<0::size(0 * 8), rest::binary>> = rest
        {:ok, acc, rest}

      n ->
        case rest do
          <<0::size((4 - n) * 8), rest::binary>> ->
            {:ok, acc, rest}

          _ ->
            @error
        end
    end
  end

  defp parse_string(<<c::binary-size(1), rest::binary>>, acc) do
    parse_string(rest, acc <> c)
  end

  defp extract_parameter_type_tags(<<44, rest::binary>>, []) do
    extract_parameter_type_tags(rest, [])
  end

  defp extract_parameter_type_tags(<<0, rest::binary>>, tags) do
    case rem(length(tags) + 2, 4) do
      0 ->
        {:ok, Enum.reverse(tags), rest}

      n ->
        <<0::size((4 - n) * 8), rest::binary>> = rest
        {:ok, Enum.reverse(tags), rest}
    end
  end

  defp extract_parameter_type_tags(<<t, rest::binary>>, tags) do
    extract_parameter_type_tags(rest, [t | tags])
  end

  defp message_with_parameters(address, rest) do
    {:ok, param_type_tags, rest} = extract_parameter_type_tags(rest, [])

    case extract_parameters(param_type_tags, rest) do
      {params, <<>>} ->
        {:ok, Message.new(address, Enum.reverse(params))}

      _ ->
        @error
    end
  end

  defp extract_parameters(param_tags, rest) do
    Enum.reduce(param_tags, {[], rest}, fn tag, {params, rest} ->
      case extract_parameter(tag, rest) do
        {:ok, param, rest} ->
          {[param | params], rest}

        _ ->
          @error
      end
    end)
  end

  defp extract_parameter(?i, <<int::signed-big-size(32), rest::binary>>), do: {:ok, int, rest}
  defp extract_parameter(?f, <<float::float-big-size(32), rest::binary>>), do: {:ok, float, rest}

  defp extract_parameter(?s, rest) do
    parse_string(rest, "")
  end

  defp extract_parameter(?b, <<blob_size::size(32), blob::binary-size(blob_size), rest::binary>>) do
    case rem(byte_size(blob) + 4, 4) do
      0 ->
        {:ok, blob, rest}

      n ->
        <<0::size((4 - n) * 8), rest::binary>> = rest
        {:ok, blob, rest}
    end
  end

  defp extract_parameter(_, _), do: @error
end
