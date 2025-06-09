defmodule OscillEx.Server do
  use GenServer

  defstruct [
    :scsynth_executable
  ]

  def start(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    path = find_scsynth_executable(opts)

    case port_helper().find_executable(path) do
      nil ->
        {:stop, :missing_scsynth_executable}

      executable ->
        {:ok, %__MODULE__{scsynth_executable: executable}}
    end
  end

  @behaviour OscillEx.PortHelper
  @impl true
  def find_executable(path), do: System.find_executable(path)

  defp port_helper do
    Application.get_env(:oscill_ex, :port_helper, __MODULE__)
  end

  defp find_scsynth_executable(opts) do
    Keyword.get(
      opts,
      :scsynth_executable,
      Application.get_env(
        :oscill_ex,
        :scsynth_executable,
        "scsynth"
      )
    )
  end
end
