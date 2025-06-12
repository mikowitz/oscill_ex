defmodule OscillEx.Transport do
  @moduledoc """
  Behaviour for a generic transport layer
  """
  @callback send(pid :: pid(), port :: pos_integer(), message :: binary()) ::
              :ok | {:error, term()}
end
