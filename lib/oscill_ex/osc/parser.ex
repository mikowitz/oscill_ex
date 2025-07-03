defmodule OscillEx.Osc.Parser do
  @moduledoc false

  def parse(message) when is_binary(message) do
    message = :erlang.binary_to_list(message)

    if length(message) < 4 do
      {:error, :invalid_message}
    else
      with {:ok, "/" <> _ = address, rest} <- parse_address(message),
           {:ok, tags, rest} <- parse_type_tags(rest),
           {:ok, params, ""} <- parse_params(tags, :erlang.list_to_binary(rest)) do
        {:ok, {address, params}}
      end
    end
  end

  def parse(_), do: {:error, :invalid_message}

  defp parse_address([?/ | _rest] = message) do
    {address, rest} = Enum.split_while(message, &(&1 != 0))

    case Enum.all?(address, &(&1 > 32 && &1 < 127)) do
      false ->
        {:error, :malformed_address}

      true ->
        {padding, rest} = Enum.split_while(rest, &(&1 == 0))

        case rem(length(address) + length(padding), 4) do
          0 ->
            {:ok, :erlang.list_to_binary(address), rest}

          _ ->
            {:error, :malformed_address}
        end
    end
  end

  defp parse_address(_), do: {:error, :malformed_address}

  defp parse_type_tags([]), do: {:ok, [], []}

  defp parse_type_tags([?, | rest]) do
    parse_type_tags(rest, [?,])
  end

  defp parse_type_tags(_), do: {:error, :malformed_type_tag}

  defp parse_type_tags(message, [0 | _] = tags) when rem(length(tags), 4) == 0 do
    tags = Enum.drop_while(tags, &(&1 == 0))
    {:ok, tl(Enum.reverse(tags)), message}
  end

  defp parse_type_tags([tag | rest], tags), do: parse_type_tags(rest, [tag | tags])

  defp parse_params(tags, message) do
    params =
      Enum.reduce_while(tags, {[], message}, fn tag, {params, rest} ->
        {param, rest} = extract_param(tag, rest)

        case param do
          {:error, _} = error -> {:halt, error}
          _ -> {:cont, {[param | params], rest}}
        end
      end)

    case params do
      {[:error], error} ->
        {:error, error}

      {params, rest} ->
        {:ok, Enum.reverse(params), rest}
    end
  end

  @supported_type_tags ~c"ifbs"

  defp extract_param(type_tag, <<>>) when type_tag in @supported_type_tags,
    do: {:error, :truncated_message}

  defp extract_param(?i, <<i::big-signed-size(32), rest::binary>>), do: {i, rest}
  defp extract_param(?f, <<f::big-float-size(32), rest::binary>>), do: {f, rest}

  defp extract_param(?b, <<i::big-signed-size(32), blob::binary-size(i), rest::binary>>),
    do: {blob, rest}

  defp extract_param(?s, rest) do
    extract_string(:erlang.binary_to_list(rest), [])
  end

  defp extract_param(type_tag, _) when type_tag in @supported_type_tags,
    do: {:error, :malformed_argument}

  defp extract_param(type_tag, _) do
    {:error, {:unsupported_type_tag, to_string([type_tag])}}
  end

  defp extract_string([], s) when rem(length(s), 4) != 0, do: {:error, :malformed_argument}

  defp extract_string(rest, [0 | _] = s) when rem(length(s), 4) == 0 do
    s = Enum.drop_while(s, &(&1 == 0)) |> Enum.reverse() |> :erlang.list_to_binary()

    {s, :erlang.list_to_binary(rest)}
  end

  defp extract_string([c | rest], s), do: extract_string(rest, [c | s])
end
