defmodule OscillEx.ServerTest do
  use ExUnit.Case, async: false

  alias OscillEx.Server

  import Mox
  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    stub(OscillEx.MockPortHelper, :find_executable, &Function.identity/1)
    :ok
  end

  describe "start/1" do
    test "reads the executable path from passed-in options" do
      {:ok, pid} = Server.start(scsynth_executable: "/my/custom/executable")

      assert pid == Process.whereis(Server)

      state = :sys.get_state(Server)

      assert state.scsynth_executable == "/my/custom/executable"
    end

    test "falls back to reading executable path from config" do
      Application.put_env(:oscill_ex, :scsynth_executable, "/my/config/executable")
      {:ok, pid} = Server.start()

      assert pid == Process.whereis(Server)

      state = :sys.get_state(Server)

      assert state.scsynth_executable == "/my/config/executable"

      on_exit(fn ->
        Application.delete_env(:oscill_ex, :scsynth_executable)
      end)
    end

    test "falls back to `scsynth` for the executable path" do
      {:ok, pid} = Server.start()

      assert pid == Process.whereis(Server)

      state = :sys.get_state(Server)

      assert state.scsynth_executable == "scsynth"
    end

    test "server fails to start when executable cannot be found" do
      stub(OscillEx.MockPortHelper, :find_executable, fn _ -> nil end)
      Process.flag(:trap_exit, true)
      assert {:error, :missing_scsynth_executable} = Server.start()

      on_exit(fn ->
        Process.flag(:trap_exit, false)
      end)
    end
  end
end
