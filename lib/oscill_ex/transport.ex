defmodule OscillEx.Transport do
  @moduledoc """
  Behaviour for a generic transport layer
  """
  @callback send_message(
              transport :: pid() | atom(),
              port :: pos_integer(),
              address :: binary(),
              arguments :: [term()]
            ) :: :ok | {:error, term()}
  @callback send(transport :: pid() | atom(), port :: pos_integer(), message :: binary()) ::
              :ok | {:error, term()}
end
