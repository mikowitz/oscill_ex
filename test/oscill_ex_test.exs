defmodule OscillExTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog

  doctest OscillEx

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    stub(OscillEx.MockPortHelper, :find_executable, &Function.identity/1)

    stub(OscillEx.MockPortHelper, :open, &Port.open/2)

    stub(OscillEx.MockPortHelper, :info, &Port.info/1)

    :ok
  end

  describe "start_server/1" do
    test "starts the scsynth server and adds it to the supervision tree" do
      capture_log(fn ->
        assert Supervisor.which_children(OscillEx.Supervisor) == []

        OscillEx.start_server(
          scsynth_executable: "./bin/dummy_scsynth",
          server_name: IntegrationTest
        )

        server_pid = Process.whereis(IntegrationTest)
        [{_, pid, _, _}] = Supervisor.which_children(OscillEx.Supervisor)
        assert pid == server_pid

        %{scsynth_port: port} = :sys.get_state(server_pid)

        assert is_port(port)
        refute is_nil(Port.info(port))

        GenServer.stop(IntegrationTest)
      end)
    end
  end
end
