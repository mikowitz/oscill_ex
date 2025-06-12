defmodule OscillEx.ServerTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  import OscillEx.TestHelpers

  alias OscillEx.Server

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!
  setup :setup_mock_port_helper

  describe "start/1" do
    test "server fails to start when executable cannot be found" do
      stub_missing_executable()

      assert capture_log(fn ->
               Process.flag(:trap_exit, true)
               assert Server.start_link() == {:error, :missing_scsynth_executable}
             end) =~ "Could not find executable `scsynth`"

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end

    test "server exits when the scsynth executable cannot be started" do
      capture_log(fn ->
        stub_erroring_executable()
        Process.flag(:trap_exit, true)
        assert {:error, :could_not_start_scsynth} = Server.start_link()
      end)

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end
  end

  describe "send_message/2" do
    test "sends an OSC-encoded message via the configured transport layer" do
      Server.start_link(transport: OscillEx.MockTransport)

      Server.send_message("/hello", ["in", 1, "out", 7.5])

      :timer.sleep(10)

      assert {57110,
              <<"/hello", 0, 0, ",sisf", 0, 0, 0, "in", 0, 0, 0, 0, 0, 1, "out", 0, 64, 240, 0,
                0>>} in OscillEx.MockTransport.get_messages()
    end
  end

  describe "send/1" do
    test "sends a message via the configured transport layer" do
      Server.start_link(transport: OscillEx.MockTransport)

      Server.send("hello")

      :timer.sleep(10)

      assert {57110, "hello"} in OscillEx.MockTransport.get_messages()
    end
  end
end
