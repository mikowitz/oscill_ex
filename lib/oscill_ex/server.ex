defmodule OscillEx.Server do
  @moduledoc """
  Manages a port running a configurable instance of `scsynth`
  """
  alias OscillEx.Server.Config

  use GenServer

  @type state :: %{
          status: :stopped | :booting | :error | :crash,
          error: term() | nil,
          port: port() | nil,
          monitor: reference() | nil,
          config: Config.t()
        }

  #########
  ## API ##
  #########

  def start_link(config \\ Config.new(publish_to_rendezvous: false, max_logins: 1)) do
    config =
      if is_struct(config, Config) do
        config
      else
        struct(Config, Enum.into(config, %{}))
      end

    GenServer.start_link(__MODULE__, config)
  end

  def boot(pid) do
    GenServer.call(pid, :boot)
  end

  def quit(pid) do
    GenServer.call(pid, :quit)
  end

  ###############
  ## CALLBACKS ##
  ###############

  @impl GenServer
  def init(config) do
    {:ok,
     %{
       status: :stopped,
       error: nil,
       config: config,
       port: nil,
       monitor: nil
     }}
  end

  @impl GenServer
  def handle_call(:boot, _, %{status: :booting} = state) do
    {:reply, {:error, :already_running}, state}
  end

  def handle_call(:boot, _, %{config: config} = state) do
    args = Config.command_line_args(config)

    {resp, new_state} =
      case validate_executable(config.executable) do
        :ok ->
          port =
            Port.open(
              {:spawn_executable, "./bin/wrapper"},
              [
                {:args, args},
                :binary,
                :exit_status
              ]
            )

          monitor = Port.monitor(port)

          {:ok, %{state | status: :booting, port: port, monitor: monitor}}

        {:error, error} ->
          {
            {:error, error},
            %{state | status: :error, error: error}
          }
      end

    {:reply, resp, new_state}
  end

  def handle_call(:quit, _, %{status: :stopped} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:quit, _, %{port: port} = state) when is_port(port) do
    new_state = close_port(state) |> set_status(:stopped)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info({port, {:exit_status, exit_code}}, %{port: port} = state) do
    new_state = close_port(state)

    case exit_code do
      0 ->
        {:noreply, set_status(new_state, :stopped)}

      _ ->
        {:noreply, new_state |> set_status(:crashed, {:exit, exit_code})}
    end
  end

  def handle_info({:DOWN, _, :port, port, reason}, %{port: port} = state) do
    new_state = close_port(state) |> set_status(:crashed, {:exit, reason})
    {:noreply, new_state}
  end

  def handle_info({port, {:data, data}}, %{port: port} = state) do
    new_state =
      cond do
        Regex.match?(~r/ERROR.*address in use/, data) ->
          close_port(state) |> set_status(:crashed, {:exit, :scsynth_port_in_use})

        Regex.match?(~r/ERROR.*Invalid option/, data) ||
            Regex.match?(~r/ERROR.*There must be a -u/, data) ->
          close_port(state) |> set_status(:crashed, {:exit, :scsynth_invalid_args})

        true ->
          state
      end

    {:noreply, new_state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  defp validate_executable(executable) do
    case File.stat(executable) do
      {:ok, %File.Stat{type: :regular}} ->
        if can_execute?(executable) do
          :ok
        else
          {:error, {:permission_denied, executable}}
        end

      {:ok, %File.Stat{type: type}} ->
        {:error, {:not_executable, "#{executable} is a #{type}, not an executable file"}}

      {:error, :enoent} ->
        {:error, {:file_not_found, executable}}
    end
  end

  defp can_execute?(executable) do
    case System.cmd("test", ["-x", executable]) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp close_port(%{monitor: monitor, port: port} = state) when is_reference(monitor) do
    Port.demonitor(monitor, [:flush])

    if is_port(port) and Port.info(port) != nil do
      Port.close(port)
    end

    %{state | monitor: nil, port: nil}
  end

  defp set_status(state, status, error \\ nil), do: %{state | status: status, error: error}
end
