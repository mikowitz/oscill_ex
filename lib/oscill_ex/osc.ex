defmodule OscillEx.Osc do
  @moduledoc """
  Handles OSC message generation
  """

  def message(address, params \\ [])

  def message("/" <> _ = address, params) do
    case ascii_string?(address) do
      true ->
        case params do
          [] ->
            {:ok, pad(address)}

          [_ | _] ->
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

  defp params_to_osc([]), do: {:ok, <<>>, <<>>}

  defp params_to_osc(params) do
    params_to_osc(params, [","], [])
  end

  defp params_to_osc([], type_tags, encoded_params) do
    {:ok, Enum.join(type_tags, ""), Enum.join(encoded_params, "")}
  end

  defp params_to_osc([i | params], type_tags, encoded_params) when is_integer(i) do
    params_to_osc(params, type_tags ++ ["i"], encoded_params ++ [<<i::big-signed-size(32)>>])
  end

  defp params_to_osc([f | params], type_tags, encoded_params) when is_float(f) do
    params_to_osc(params, type_tags ++ ["f"], encoded_params ++ [<<f::big-float-size(32)>>])
  end

  defp params_to_osc([s | params], type_tags, encoded_params) when is_binary(s) do
    if ascii_string?(s) do
      params_to_osc(params, type_tags ++ ["s"], encoded_params ++ [pad(s)])
    else
      {:error, {:invalid_string, s}}
    end
  end

  defp params_to_osc([x | _], _, _), do: {:error, {:unsupported_type, x}}

  defp ascii_string?(s) do
    s
    |> to_charlist()
    |> Enum.all?(&(&1 >= 32 && &1 <= 127))
  end

  defp pad(s) when is_binary(s) do
    s <> String.duplicate(<<0>>, 4 - rem(byte_size(s), 4))
  end
end
