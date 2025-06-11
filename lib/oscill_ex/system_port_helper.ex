defmodule OscillEx.SystemPortHelper do
  @moduledoc """
  Delegates the `b:SystemPort` behaviour to the real Elixir functions 
  """

  @behaviour OscillEx.PortHelper
  @impl true
  defdelegate find_executable(path), to: System
  @impl true
  defdelegate open(port, options), to: Port
  @impl true
  defdelegate info(port), to: Port
end
