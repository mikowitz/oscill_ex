defmodule OscillEx.ServerTest do
  use ExUnit.Case, async: true

  alias OscillEx.Server
  alias OscillEx.Server.Config

  import OscillEx.Test.Support.Assertions
  import OscillEx.Test.Support.ExecutableHelpers

  describe "start_link/1" do
    test "starts in :stopped state" do
      {:ok, pid} = Server.start_link()

      assert_status(pid, :stopped)
    end

    test "starts with default configuration" do
      {:ok, pid} = Server.start_link()

      config = :sys.get_state(pid).config
      assert is_struct(config, Config)
      assert config.executable == "scsynth"
      assert config.port == 57110
      assert config.protocol == :udp
      refute config.publish_to_rendezvous
      assert config.max_logins == 1
    end

    test "config can be passed as a config struct" do
      {:ok, pid} =
        Server.start_link(Config.new(executable: "/my/scsynth", port: 57111, max_logins: 17))

      config = :sys.get_state(pid).config
      assert is_struct(config, Config)
      assert config.executable == "/my/scsynth"
      assert config.port == 57111
      assert config.max_logins == 17
    end

    test "config can be passed as a map" do
      {:ok, pid} = Server.start_link(%{executable: "/map/scsynth", port: 57222})
      config = :sys.get_state(pid).config
      assert is_struct(config, Config)
      assert config.executable == "/map/scsynth"
      assert config.port == 57222
    end

    test "config can be passed as a keyword list" do
      {:ok, pid} = Server.start_link(executable: "/keyword/scsynth", port: 57333)
      config = :sys.get_state(pid).config
      assert is_struct(config, Config)
      assert config.executable == "/keyword/scsynth"
      assert config.port == 57333
    end
  end

  describe "boot with errors" do
    test "when the executable doesn't exist" do
      config = Config.new(executable: "/this/doesnt/exist")
      {:ok, pid} = Server.start_link(config)

      assert {:error, {:file_not_found, "/this/doesnt/exist"}} == Server.boot(pid)
      assert_status(pid, :error)
      assert_error(pid, {:file_not_found, "/this/doesnt/exist"})
    end

    test "when the executable isn't a regular file" do
      :ok = File.mkdir("this-is-a-dir")
      error = {:not_executable, "this-is-a-dir is a directory, not an executable file"}

      {:ok, pid} = Server.start_link(Config.new(executable: "this-is-a-dir"))

      assert {:error, error} == Server.boot(pid)
      assert_status(pid, :error)
      assert_error(pid, error)

      on_exit(fn ->
        :ok = File.rmdir("this-is-a-dir")
      end)
    end

    test "when the user doesn't have permission to run the executable" do
      :ok = File.touch("non-executable")
      File.chmod("non-executable", 0644)
      error = {:permission_denied, "non-executable"}

      {:ok, pid} = Server.start_link(Config.new(executable: "non-executable"))

      assert {:error, error} == Server.boot(pid)
      assert_status(pid, :error)
      assert_error(pid, error)

      on_exit(fn ->
        :ok = File.rm("non-executable")
      end)
    end
  end

  describe "handling exit states" do
    test "when the executable exits normally" do
      with_test_server(:exit_normal, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :stopped)
        assert_error(pid, nil)
      end)
    end

    test "when the executable exits abnormally" do
      with_test_server(:crash, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :crashed)
        assert_error(pid, {:exit, 1})
      end)
    end

    test "when the executable crashes" do
      with_test_server(fn pid ->
        :ok = Server.boot(pid)

        port = :sys.get_state(pid).port

        Port.close(port)

        assert_status(pid, :crashed)
        assert_error(pid, {:exit, :normal})
        assert_no_port(pid)
      end)
    end
  end

  describe "boot/1" do
    test "when the process runs" do
      with_test_server(fn pid ->
        :ok = Server.boot(pid)

        assert_status(pid, :running)
        assert_error(pid, nil)
        assert_has_open_port(pid)
      end)
    end

    test "when the process is already running" do
      with_test_server(fn pid ->
        :ok = Server.boot(pid)

        assert {:error, :already_running} = Server.boot(pid)

        assert_status(pid, :running)
        assert_error(pid, nil)
        assert_has_open_port(pid)
      end)
    end
  end

  describe "quit/1" do
    test "does nothing when the process is not running" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.quit(pid)

        assert_status(pid, :stopped)
      end)
    end

    test "exits correctly when the process is running" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)
        :ok = Server.quit(pid)

        assert_status(pid, :stopped)
        assert_no_port(pid)
      end)
    end
  end

  describe "argument handling" do
    test "passes provided arguments to process" do
      with_test_server(:capture_args, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(1000)

        wait_for_condition(
          fn -> :sys.get_state(pid).status == :stopped end,
          5000,
          "Expected status: :stopped"
        )

        assert_status(pid, :stopped)

        assert File.read!("args_output") == "-u 57110 -R 0 -l 1"

        on_exit(fn -> :ok = File.rm("args_output") end)
      end)
    end
  end

  describe "scsynth-like behaviour" do
    test "booting successfully" do
      with_test_server(:scsynth_success, fn pid ->
        :ok = Server.boot(pid)

        assert_status(pid, :running)
        assert_has_open_port(pid)
      end)
    end

    test "when the port is already in use" do
      with_test_server(:scsynth_port_in_use, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :crashed)
        assert_error(pid, {:exit, :scsynth_port_in_use})
        assert_no_port(pid)
      end)
    end

    test "with invalid arguments" do
      with_test_server(:scsynth_invalid_arg, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :crashed)
        assert_error(pid, {:exit, :scsynth_invalid_args})
        assert_no_port(pid)
      end)
    end

    test "with missing required arguments" do
      with_test_server(:scsynth_no_port, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :crashed)
        assert_error(pid, {:exit, :scsynth_invalid_args})
        assert_no_port(pid)
      end)
    end
  end

  describe "send_osc_message/2" do
    test "returns error when server not running" do
      {:ok, pid} = Server.start_link()

      # Throw a dummy value into the state so we skip to the next function head
      :sys.replace_state(pid, fn state -> %{state | udp: :dummy_udp} end)

      assert {:error, :not_running} = Server.send_osc_message(pid, <<1, 2, 3>>)
    end

    test "returns error when UDP socket not available" do
      config = Config.new(executable: "/this/doesnt/exist")
      {:ok, pid} = Server.start_link(config)

      # Try to boot with invalid executable, which should fail and leave UDP nil
      assert {:error, _} = Server.boot(pid)
      assert {:error, :no_udp_socket} = Server.send_osc_message(pid, <<1, 2, 3>>)
    end

    test "returns ok when message sent successfully" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)

        # This should currently pass since the function always returns :ok
        # But after implementing error handling, it should return :ok for successful sends
        assert :ok = Server.send_osc_message(pid, <<1, 2, 3>>)
      end)
    end
  end

  describe "GenServer termination" do
    test "closes the port and UDP socket when the port is open" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)
        assert_has_open_port(pid)
        assert_has_udp_socket(pid)

        port = :sys.get_state(pid).port
        udp_socket = :sys.get_state(pid).udp.socket

        GenServer.stop(pid)
        :timer.sleep(100)

        assert Port.info(port) == nil
        assert Port.info(udp_socket) == nil
      end)
    end

    test "does nothing when no process is running" do
      {:ok, pid} = Server.start_link()

      GenServer.stop(pid)
    end
  end

  describe "udp transport layer" do
    test "server starts with no open connection" do
      {:ok, pid} = Server.start_link()

      assert assert_no_udp_socket(pid)
    end

    test "is opened when the server boots" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)

        assert_status(pid, :running)
        assert_has_udp_socket(pid)
      end)
    end

    test "is cleared when the server quits" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)
        :ok = Server.quit(pid)

        assert_status(pid, :stopped)
        assert_no_udp_socket(pid)
      end)
    end

    test "is cleared when the server crashes" do
      with_test_server(:crash, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :crashed)
        assert_no_udp_socket(pid)
      end)
    end

    test "stays clear when the scsynth server doesn't start" do
      with_test_server(:scsynth_port_in_use, fn pid ->
        :ok = Server.boot(pid)

        :timer.sleep(500)

        assert_status(pid, :crashed)
        assert_no_udp_socket(pid)
      end)
    end

    test "is cleared when the executable crashes" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)

        port = :sys.get_state(pid).port

        Port.close(port)

        assert_status(pid, :crashed)
        assert_no_udp_socket(pid)
      end)
    end

    test "restarts if it closes, and the server keeps running" do
      with_test_server(:long_running, fn pid ->
        :ok = Server.boot(pid)

        udp_socket = :sys.get_state(pid).udp.socket

        Port.close(udp_socket)

        assert_status(pid, :running)
        assert_has_udp_socket(pid)
      end)
    end
  end
end
