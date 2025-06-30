defmodule OscillEx.Scsynth do
  @moduledoc """
  Low-level process management for SuperCollider's synthesis server (`scsynth`).

  This module handles the lifecycle of external `scsynth` processes including
  validation, spawning, monitoring, and termination. It provides error handling
  for common failure scenarios and parses `scsynth` output for meaningful error
  messages.

  ## Usage

      # Start a scsynth process with configuration
      config = %Config{port: 57120, executable: "/usr/local/bin/scsynth"}
      {:ok, port, monitor} = Scsynth.start_process(config)

      # Handle process termination
      :ok = Scsynth.stop_process(port, monitor)

      # Parse scsynth error output
      case Scsynth.parse_scsynth_error(stderr_data) do
        :ok -> IO.puts("No errors detected")
        {:error, :scsynth_port_in_use} -> IO.puts("Port already in use")
        {:error, :scsynth_invalid_args} -> IO.puts("Invalid arguments")
      end

  ## Error Handling

  The module recognizes several common `scsynth` failure modes:

  - **Executable validation**: Checks file existence, type, and permissions
  - **Port conflicts**: Detects when the configured port is already in use
  - **Invalid arguments**: Identifies malformed command-line parameters
  - **Process crashes**: Handles unexpected termination and exit codes

  ## Implementation Notes

  This module uses Erlang ports to spawn `scsynth` as an external process
  and monitors it for crashes or unexpected termination. All processes are
  spawned through a wrapper script (`./bin/wrapper`) for consistent handling.
  """
  alias OscillEx.Server.Config

  @doc """
  Starts a new `scsynth` process with the given configuration.

  Validates the executable path and spawns the process with configured
  parameters. Returns the port and monitor reference for the running process.

  ## Parameters

  - `config` - A `Config` struct containing scsynth configuration

  ## Returns

  - `{:ok, port, monitor}` - Process started successfully
  - `{:error, {:file_not_found, path}}` - Executable not found
  - `{:error, {:permission_denied, path}}` - Executable not executable
  - `{:error, {:not_executable, message}}` - Path is not a regular file

  ## Examples

      config = %Config{executable: "/usr/local/bin/scsynth", port: 57120}
      {:ok, port, monitor} = Scsynth.start_process(config)

      # Invalid executable
      bad_config = %Config{executable: "/nonexistent/scsynth"}
      {:error, {:file_not_found, "/nonexistent/scsynth"}} = Scsynth.start_process(bad_config)
  """
  @spec start_process(Config.t()) :: {:ok, port(), reference()} | {:error, term()}
  def start_process(%Config{} = config) do
    case validate_executable(config.executable) do
      :ok -> open_port(config)
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Gracefully stops a running `scsynth` process.

  Demonitors the port and closes it if still active. This function is safe
  to call multiple times or with invalid port/monitor references.

  ## Parameters

  - `port` - The port reference for the running process
  - `monitor` - The monitor reference for the process

  ## Returns

  - `:ok` - Process stopped successfully

  ## Examples

      {:ok, port, monitor} = Scsynth.start_process(config)
      :ok = Scsynth.stop_process(port, monitor)

      # Safe to call multiple times
      :ok = Scsynth.stop_process(port, monitor)
  """
  @spec stop_process(port() | nil, reference() | nil) :: :ok
  def stop_process(port, monitor) do
    if is_reference(monitor) do
      Port.demonitor(monitor, [:flush])
    end

    if is_port(port) and Port.info(port) != nil do
      Port.close(port)
    end

    :ok
  end

  @doc """
  Converts process exit status codes to error terms.

  ## Parameters

  - `code` - The exit status code from the process

  ## Returns

  - `nil` - Process exited normally (code 0)
  - `{:exit, code}` - Process exited with error code

  ## Examples

      nil = Scsynth.handle_exit_status(0)
      {:exit, 1} = Scsynth.handle_exit_status(1)
  """
  @spec handle_exit_status(integer()) :: nil | {:exit, integer()}
  def handle_exit_status(0), do: nil
  def handle_exit_status(code), do: {:exit, code}

  @doc """
  Converts port down reasons to error terms.

  ## Parameters

  - `reason` - The reason the port went down

  ## Returns

  - `{:exit, reason}` - Wrapped error term

  ## Examples

      {:exit, :normal} = Scsynth.handle_port_down(:normal)
      {:exit, :killed} = Scsynth.handle_port_down(:killed)
  """
  @spec handle_port_down(term()) :: {:exit, term()}
  def handle_port_down(reason), do: {:exit, reason}

  @doc """
  Parses `scsynth` stderr output to identify common error conditions.

  Analyzes error messages from `scsynth` and returns structured error terms
  for known failure modes. Unknown errors are ignored.

  ## Parameters

  - `data` - Binary data from scsynth stderr or any other term

  ## Returns

  - `:ok` - No recognized errors found
  - `{:error, :scsynth_port_in_use}` - Configured port is already in use
  - `{:error, :scsynth_invalid_args}` - Invalid command-line arguments

  ## Examples

      :ok = Scsynth.parse_scsynth_error("Starting server...")
      {:error, :scsynth_port_in_use} = Scsynth.parse_scsynth_error("ERROR: address in use")
      {:error, :scsynth_invalid_args} = Scsynth.parse_scsynth_error("ERROR: Invalid option -x")
      :ok = Scsynth.parse_scsynth_error(123)  # Non-binary data
  """
  @spec parse_scsynth_error(term()) :: :ok | {:error, atom()}
  def parse_scsynth_error(data) when is_binary(data) do
    cond do
      data =~ ~r/ERROR.*address in use/ -> {:error, :scsynth_port_in_use}
      data =~ ~r/ERROR.*(There must be a -u|Invalid option)/ -> {:error, :scsynth_invalid_args}
      true -> :ok
    end
  end

  def parse_scsynth_error(_), do: :ok

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

  defp open_port(config) do
    args = Config.command_line_args(config)

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

    {:ok, port, monitor}
  end

  @doc """
  Closes a port and cleans up its monitor.

  This is a public wrapper around the port cleanup logic, returning `nil`
  to indicate the port is no longer valid.

  ## Parameters

  - `port` - The port to close
  - `monitor` - The monitor reference to clean up

  ## Returns

  - `nil` - Port closed and cleaned up

  ## Examples

      {:ok, port, monitor} = Scsynth.start_process(config)
      nil = Scsynth.close_port(port, monitor)
  """
  @spec close_port(port() | nil, reference() | nil) :: nil
  def close_port(port, monitor) do
    if is_reference(monitor), do: Port.demonitor(monitor, [:flush])

    if is_port(port) and Port.info(port) != nil do
      Port.close(port)
    end

    nil
  end
end
