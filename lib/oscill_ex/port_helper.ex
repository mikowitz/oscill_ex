defmodule OscillEx.PortHelper do
  @moduledoc false
  @callback find_executable(String.t()) :: String.t() | nil
  @callback open(term(), term()) :: port()
  @callback info(port()) :: Keyword.t() | nil
end
