defmodule OscillEx.ServerTest do
  use ExUnit.Case, async: true

  alias OscillEx.Server

  describe "start_link/1" do
    test "starts in :stopped state" do
      {:ok, pid} = Server.start_link()

      assert has_status(pid, :stopped)
    end

    test "starts with default configuration" do
      {:ok, pid} = Server.start_link()

      assert has_config(pid, %{executable: "scsynth", args: ["-u", "57110", "-R", "0", "-l", "1"]})
    end

    test "config can be passed in as a map" do
      config = %{executable: "/my/scsynth", args: ["-u", "57111", "-l", "1"]}
      {:ok, pid} = Server.start_link(config)

      assert has_config(pid, config)
    end

    test "config can be passed as a keyword list" do
      config = [executable: "/my/scsynth", args: ["-u", "57111", "-l", "1"]]
      {:ok, pid} = Server.start_link(config)

      assert has_config(pid, %{executable: "/my/scsynth", args: ["-u", "57111", "-l", "1"]})
    end
  end

  describe "boot with errors" do
    test "when the executable doesn't exist" do
      {:ok, pid} = Server.start_link(executable: "/this/doesnt/exist")

      assert {:error, {:file_not_found, "/this/doesnt/exist"}} == Server.boot(pid)
      assert has_status(pid, :error)
      assert has_error(pid, {:file_not_found, "/this/doesnt/exist"})
    end

    test "when the executable isn't a regular file" do
      :ok = File.mkdir("this-is-a-dir")
      error = {:not_executable, "this-is-a-dir is a directory, not an executable file"}

      {:ok, pid} = Server.start_link(executable: "this-is-a-dir")

      assert {:error, error} == Server.boot(pid)
      assert has_status(pid, :error)
      assert has_error(pid, error)

      on_exit(fn ->
        :ok = File.rmdir("this-is-a-dir")
      end)
    end

    test "when the user doesn't have permission to run the executable" do
      :ok = File.touch("non-executable")
      File.chmod("non-executable", 0644)
      error = {:permission_denied, "non-executable"}

      {:ok, pid} = Server.start_link(executable: "non-executable")

      assert {:error, error} == Server.boot(pid)
      assert has_status(pid, :error)
      assert has_error(pid, error)

      on_exit(fn ->
        :ok = File.rm("non-executable")
      end)
    end
  end

  describe "handling exit states" do
    test "when the executable exits normally" do
      test_exec = create_executable("normal", "exit 0")

      {:ok, pid} = Server.start_link(executable: test_exec)
      :ok = Server.boot(pid)

      :timer.sleep(500)

      assert has_status(pid, :stopped)
      assert has_error(pid, nil)
    end

    test "when the executable exits abnormally" do
      test_exec = create_executable("crash", "exit 1")

      {:ok, pid} = Server.start_link(executable: test_exec)
      :ok = Server.boot(pid)

      :timer.sleep(500)

      assert has_status(pid, :crashed)
      assert has_error(pid, {:exit, 1})
    end

    test "when the executable crashes" do
      test_exec = create_executable("long_running", "sleep 300")

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      port = :sys.get_state(pid).port

      Port.close(port)

      assert has_status(pid, :crashed)
      assert has_error(pid, {:exit, :normal})
      assert no_port(pid)
    end
  end

  describe "boot/1" do
    test "when the process runs" do
      test_exec = create_executable("long_running", "sleep 300")

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      assert has_status(pid, :booting)
      assert has_error(pid, nil)
      assert has_open_port(pid)
    end

    test "when the process is already running" do
      test_exec = create_executable("long_running", "sleep 300")

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      assert {:error, :already_running} = Server.boot(pid)

      assert has_status(pid, :booting)
      assert has_error(pid, nil)
      assert has_open_port(pid)
    end
  end

  describe "quit/1" do
    test "does nothing when the process is not running" do
      test_exec = create_executable("long_running", "sleep 300")

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.quit(pid)

      assert has_status(pid, :stopped)
    end

    test "exits correctly when the process is running" do
      test_exec = create_executable("long_running", "sleep 300")
      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)
      :ok = Server.quit(pid)

      assert has_status(pid, :stopped)
      assert no_port(pid)
    end
  end

  describe "argument handling" do
    test "passes provided arguments to process" do
      test_exec = create_executable("long_running", "echo \"$@\\c\" > args_output")

      {:ok, pid} = Server.start_link(executable: test_exec, args: ["abc", "def", "ghi"])

      :ok = Server.boot(pid)

      :timer.sleep(500)

      assert has_status(pid, :stopped)

      assert File.read!("args_output") == "abc def ghi"

      on_exit(fn ->
        :ok = File.rm("args_output")
      end)
    end
  end

  describe "scsynth-like behaviour" do
    test "booting successfully" do
      test_exec =
        create_executable("scsynth", "echo \"SuperCollider 3 server ready.\nsleep 100\nexit 0")

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      assert has_status(pid, :booting)
      assert has_open_port(pid)
    end

    test "when the port is already in use" do
      test_exec =
        create_executable(
          "scsynth-port-conflict",
          "echo \"*** ERROR: failed to open socket: address in use.\""
        )

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      :timer.sleep(500)

      assert has_status(pid, :crashed)
      assert has_error(pid, {:exit, :scsynth_port_in_use})
      assert no_port(pid)
    end

    test "with invalid arguments" do
      test_exec =
        create_executable(
          "scsynth-arg-conflict",
          "echo \"ERROR: Invalid option --z\""
        )

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      :timer.sleep(500)

      assert has_status(pid, :crashed)
      assert has_error(pid, {:exit, :scsynth_invalid_args})
      assert no_port(pid)
    end

    test "with missing required arguments" do
      test_exec =
        create_executable(
          "scsynth-arg-conflict",
          "echo \"ERROR: There must be a -u and/or a -t options, or -N for nonrealtime.\""
        )

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)

      :timer.sleep(500)

      assert has_status(pid, :crashed)
      assert has_error(pid, {:exit, :scsynth_invalid_args})
      assert no_port(pid)
    end
  end

  describe "GenServer termination" do
    test "closes the port when the port is open" do
      test_exec = create_executable("long_running", "sleep 300")

      {:ok, pid} = Server.start_link(executable: test_exec)

      :ok = Server.boot(pid)
      assert has_open_port(pid)

      port = :sys.get_state(pid).port

      GenServer.stop(pid)
      :timer.sleep(100)

      assert Port.info(port) == nil
    end

    test "does nothing when no process is running" do
      {:ok, pid} = Server.start_link()

      GenServer.stop(pid)
    end
  end

  defp has_status(pid, status) do
    assert :sys.get_state(pid).status == status
  end

  defp has_config(pid, config) do
    assert :sys.get_state(pid).config == config
  end

  defp has_error(pid, error) do
    assert :sys.get_state(pid).error == error
  end

  defp has_open_port(pid) do
    port = :sys.get_state(pid).port
    assert is_port(port)
    assert is_list(Port.info(port))
  end

  defp no_port(pid) do
    state = :sys.get_state(pid)
    assert is_nil(state.port)
    assert is_nil(state.monitor)
  end

  defp create_executable(name, contents) do
    test_dir = Path.join(System.tmp_dir!(), "server_test_#{:rand.uniform(1_000_000)}")
    :ok = File.mkdir_p(test_dir)
    test_exec = Path.join(test_dir, name)
    :ok = File.write(test_exec, "#!/bin/sh\n#{contents}")
    :ok = File.chmod(test_exec, 0o744)

    ExUnit.Callbacks.on_exit(fn ->
      {:ok, _} = File.rm_rf(test_dir)
    end)

    test_exec
  end
end
