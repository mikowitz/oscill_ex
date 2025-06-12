defmodule OscillEx do
  @moduledoc """
  Documentation for `OscillEx`.
  """

  def port_helper do
    Application.get_env(:oscill_ex, :port_helper, OscillEx.SystemPortHelper)
  end
end
