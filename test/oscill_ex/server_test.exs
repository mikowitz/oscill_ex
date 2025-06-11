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
      stub(OscillEx.MockPortHelper, :find_executable, fn _ -> nil end)

      assert capture_log(fn ->
               Process.flag(:trap_exit, true)
               assert Server.start_link() == {:error, :missing_scsynth_executable}
             end) =~ "Could not find executable `scsynth`"

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end

    test "logs the running executable" do
      assert capture_log(fn ->
               {:ok, _} = Server.start_link()
             end) =~ ~r/Server started with.*scsynth -u 57110/
    end

    test "server exits when the scsynth executable cannot be started" do
      assert capture_log(fn ->
               stub(OscillEx.MockPortHelper, :info, fn _name -> nil end)

               Process.flag(:trap_exit, true)

               assert {:error, :could_not_start_scsynth} = Server.start_link()
             end) =~ "Could not start server with `scsynth -u 57110`"

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end
  end
end
