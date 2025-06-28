defmodule OscillEx.Test.Support.ExecutableHelpers do
  @moduledoc false

  alias OscillEx.Server
  alias OscillEx.Server.Config

  def with_test_server(mode \\ :long_running, test_func) do
    test_exec = create_executable(mode)
    {:ok, pid} = Server.start_link(Config.new(executable: test_exec))

    try do
      test_func.(pid)
    after
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end
  end

  def create_executable(role) do
    case role do
      :exit_normal ->
        do_create_executable("exit 0")

      :crash ->
        do_create_executable("exit 1")

      :long_running ->
        do_create_executable("sleep 300")

      :capture_args ->
        do_create_executable("echo \"$@\\c\" > args_output")

      :scsynth_success ->
        do_create_executable("echo \"SuperCollider 3 server ready.\nsleep 100\nexit 0")

      :scsynth_invalid_arg ->
        do_create_executable("echo \"ERROR: Invalid option --z\"")

      :scsynth_no_port ->
        do_create_executable(
          "echo \"ERROR: There must be a -u and/or a -t options, or -N for nonrealtime.\""
        )

      :scsynth_port_in_use ->
        do_create_executable("echo \"*** ERROR: failed to open socket: address in use.\"")
    end
  end

  def do_create_executable(contents) do
    test_dir = Path.join(System.tmp_dir!(), "server_test_#{:rand.uniform(1_000_000)}")
    :ok = File.mkdir_p(test_dir)
    name = "scsynth_#{:rand.uniform(1_000_000)}"
    test_exec = Path.join(test_dir, name)
    :ok = File.write(test_exec, "#!/bin/sh\n#{contents}")
    :ok = File.chmod(test_exec, 0o744)

    ExUnit.Callbacks.on_exit(fn -> {:ok, _} = File.rm_rf(test_dir) end)

    test_exec
  end
end
