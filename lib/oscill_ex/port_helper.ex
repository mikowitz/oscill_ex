defmodule OscillEx.PortHelper do
  @callback find_executable(String.t()) :: String.t() | nil
end
