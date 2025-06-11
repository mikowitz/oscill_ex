defmodule OscillEx.ScsynthProcessTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  import OscillEx.TestHelpers

  alias OscillEx.ScsynthProcess
  alias OscillEx.Server.Config

  import Mox
  setup :verify_on_exit!
  setup :setup_mock_port_helper

  describe "start/1" do
    test "when the port starts" do
      logs =
        capture_log(fn ->
          {:ok, config} = Config.build(executable: "myexec", port: 3510)
          {:ok, port, monitor} = ScsynthProcess.start(config)

          assert is_port(port)
          assert is_reference(monitor)
        end)

      assert logs =~ "Server starting with"
      assert logs =~ "Server started with `myexec"
    end

    test "when the port fails to start" do
      stub(OscillEx.MockPortHelper, :info, fn _ -> nil end)

      logs =
        capture_log(fn ->
          {:ok, config} = Config.build(executable: "myexec", port: 3510)

          assert ScsynthProcess.start(config) == {:error, :could_not_start_scsynth}
        end)

      assert logs =~ "Server starting with"
      assert logs =~ "Could not start server with `myexec"
    end
  end

  describe "restart/2" do
    test "restarts with a new monitor" do
      capture_log(fn ->
        {:ok, config} = Config.build(executable: "myexec", port: 3510)
        {:ok, port, monitor} = ScsynthProcess.start(config)

        {:ok, new_port, new_monitor} = ScsynthProcess.restart(config, monitor)

        refute new_monitor == monitor
        refute new_port == port
      end)
    end
  end
end
