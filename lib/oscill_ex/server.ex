defmodule OscillEx.Server do
  @moduledoc """
  Manages running an `scsynth` process that can receive OSC messages.
  """

  use GenServer

  require Logger

  # credo:disable-for-next-line
  @default_port 57110

  defstruct [
    :scsynth_executable,
    :scsynth_port,
    :scsynth_port_monitor,
    :server_config
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :server_name, __MODULE__))
  end

  @impl true
  def init(opts) do
    path = find_scsynth_executable(opts)

    case port_helper().find_executable(path) do
      nil ->
        {:stop, :missing_scsynth_executable}

      executable ->
        server_config =
          Keyword.get(opts, :server_config, [])
          |> Keyword.put_new(:executable, executable)

        case start_scsynth_port(server_config) do
          {:ok, port, monitor} ->
            {:ok,
             %__MODULE__{
               scsynth_executable: executable,
               scsynth_port: port,
               scsynth_port_monitor: monitor,
               server_config: server_config
             }}

          _ ->
            {:stop, :could_not_start_scsynth}
        end
    end
  end

  @impl true
  def handle_info({port, {:data, message}}, %__MODULE__{scsynth_port: port} = state) do
    Logger.info(String.trim(message))
    {:noreply, state}
  end

  def handle_info({:DOWN, _, :port, port, _}, %__MODULE__{scsynth_port: port} = state) do
    Logger.warning("scsynth Port closed")
    Port.demonitor(state.scsynth_port_monitor)

    case start_scsynth_port(state.server_config) do
      {:ok, port, monitor} ->
        {:noreply,
         %__MODULE__{
           state
           | scsynth_port: port,
             scsynth_port_monitor: monitor
         }}

      _ ->
        {:stop, :could_not_start_scsynth}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @behaviour OscillEx.PortHelper
  @impl true
  defdelegate find_executable(path), to: System
  @impl true
  defdelegate open(port, options), to: Port
  @impl true
  defdelegate info(port), to: Port

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

  defp start_scsynth_port(server_config) do
    port = Keyword.get(server_config, :port, @default_port)
    executable = Keyword.get(server_config, :executable, "scsynth")

    scsynth_port =
      port_helper().open(
        {:spawn_executable, "./bin/scsynth_wrapper"},
        [:binary, args: [executable, "-u", to_string(port)]]
      )

    case port_helper().info(scsynth_port) do
      nil ->
        nil

      _ ->
        Logger.info("Server started with `#{executable} -u #{port}`")
        monitor = Port.monitor(scsynth_port)

        {:ok, scsynth_port, monitor}
    end
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
