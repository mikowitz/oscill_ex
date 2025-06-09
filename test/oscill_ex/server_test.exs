defmodule OscillEx.ServerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  alias OscillEx.Server

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    stub(OscillEx.MockPortHelper, :find_executable, &Function.identity/1)

    stub(OscillEx.MockPortHelper, :open, fn _name, _opts ->
      Port.open({:spawn_executable, "./bin/scsynth_wrapper"}, [
        :binary,
        args: ["./bin/dummy_scsynth"]
      ])
    end)

    stub(OscillEx.MockPortHelper, :info, fn _port -> [] end)

    :ok
  end

  describe "start/1" do
    test "reads the executable path from passed-in options" do
      capture_log(fn ->
        {:ok, pid} = Server.start_link(scsynth_executable: "/my/custom/executable")

        assert pid == Process.whereis(Server)

        state = :sys.get_state(Server)

        assert state.scsynth_executable == "/my/custom/executable"
      end)
    end

    test "falls back to reading executable path from config" do
      Application.put_env(:oscill_ex, :scsynth_executable, "/my/config/executable")

      capture_log(fn ->
        {:ok, pid} = Server.start_link()

        assert pid == Process.whereis(Server)

        state = :sys.get_state(Server)

        assert state.scsynth_executable == "/my/config/executable"
      end)

      on_exit(fn ->
        Application.delete_env(:oscill_ex, :scsynth_executable)
      end)
    end

    test "falls back to `scsynth` for the executable path" do
      capture_log(fn ->
        {:ok, pid} = Server.start_link()

        assert pid == Process.whereis(Server)

        state = :sys.get_state(Server)

        assert state.scsynth_executable == "scsynth"
      end)
    end

    test "server fails to start when executable cannot be found" do
      stub(OscillEx.MockPortHelper, :find_executable, fn _ -> nil end)
      Process.flag(:trap_exit, true)
      assert {:error, :missing_scsynth_executable} = Server.start_link()

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end

    test "opens a port running the scsynth executable" do
      capture_log(fn ->
        {:ok, _} = Server.start_link()

        state = :sys.get_state(Server)

        assert is_port(state.scsynth_port)
        assert is_reference(state.scsynth_port_monitor)
        refute is_nil(Port.info(state.scsynth_port))
      end)
    end

    test "logs the running executable" do
      assert capture_log(fn ->
               {:ok, _} = Server.start_link()
             end) =~ ~r/Server started with.*scsynth -u 57110/
    end

    test "can specify the port to run the server on" do
      assert capture_log(fn ->
               {:ok, _} = Server.start_link(server_config: [port: 57123])
               state = :sys.get_state(Server)
               assert state.server_config[:port] == 57123
             end) =~ ~r/Server started with.*scsynth -u 57123/
    end

    test "server exits when the scsynth executable cannot be started" do
      stub(OscillEx.MockPortHelper, :info, fn _name -> nil end)

      Process.flag(:trap_exit, true)

      assert {:error, :could_not_start_scsynth} = Server.start_link()

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end
  end
end
