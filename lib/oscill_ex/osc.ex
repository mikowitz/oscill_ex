defmodule OscillEx.Osc do
  @moduledoc """
  Handles OSC message generation
  """

  alias OscillEx.Osc.Parser

  def message(address, params \\ [])

  def message("/" <> _ = address, params) do
    case ascii_string?(address) do
      true ->
        case params do
          [] ->
            {:ok, pad(address)}

          p when is_list(p) ->
            with({:ok, type_tag, encoded_params} <- params_to_osc(params)) do
              result = pad(address) <> pad(type_tag) <> encoded_params
              {:ok, result}
            end

          _ ->
            {:error, :invalid_arguments}
        end

      false ->
        {:error, :invalid_address}
    end
  end

  def message(_address, _params), do: {:error, :invalid_address}

  defdelegate parse(message), to: Parser

  @spec params_to_osc(list()) ::
          {:ok, String.t(), String.t()} | {:error, {:unsupported_type, term()}}
  defp params_to_osc([]), do: {:ok, "", ""}
  defp params_to_osc(params), do: params_to_osc(params, [","], [])

  defp params_to_osc([], type_tags, encoded_params) do
    {:ok, Enum.join(Enum.reverse(type_tags), ""), Enum.join(Enum.reverse(encoded_params), "")}
  end

  defp params_to_osc([i | params], type_tags, encoded_params) when is_integer(i) do
    params_to_osc(params, ["i" | type_tags], [<<i::big-signed-size(32)>> | encoded_params])
  end

  defp params_to_osc([f | params], type_tags, encoded_params) when is_float(f) do
    params_to_osc(params, ["f" | type_tags], [<<f::big-float-size(32)>> | encoded_params])
  end

  defp params_to_osc([s | params], type_tags, encoded_params) when is_binary(s) do
    if ascii_string?(s) do
      params_to_osc(params, ["s" | type_tags], [pad(s) | encoded_params])
    else
      params_to_osc(
        params,
        ["b" | type_tags],
        [<<byte_size(s)::big-size(32), s::binary>> | encoded_params]
      )
    end
  end

  defp params_to_osc([x | _], _, _), do: {:error, {:unsupported_type, x}}

  defp ascii_string?(s) do
    s
    |> String.codepoints()
    |> Enum.all?(fn
      <<c>> -> c >= 32 && c <= 126
      <<_, _>> -> false
    end)
  end

  defp pad(s) when is_binary(s) do
    s <> String.duplicate(<<0>>, 4 - rem(byte_size(s), 4))
  end
end
