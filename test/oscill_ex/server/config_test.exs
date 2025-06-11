defmodule OscillEx.Server.ConfigTest do
  use ExUnit.Case, async: true

  alias OscillEx.Server.Config

  import Mox
  setup :verify_on_exit!

  setup do
    stub(OscillEx.MockPortHelper, :find_executable, &Function.identity/1)

    :ok
  end

  describe "build/1" do
    test "builds from explicitly passed in configuration" do
      {:ok, config} = Config.build(executable: "/my/custom/scsynth", port: 75234)

      assert config.executable == "/my/custom/scsynth"
      assert config.port == 75234
      assert config.protocol == :udp
    end

    test "falls back to Application env" do
      Application.put_env(:oscill_ex, :protocol, :tcp)
      Application.put_env(:oscill_ex, :executable, "/my/env/scsynth")
      Application.put_env(:oscill_ex, :port, 10222)

      {:ok, config} = Config.build()

      assert config.executable == "/my/env/scsynth"
      assert config.port == 10222
      assert config.protocol == :tcp

      on_exit(fn ->
        Application.delete_env(:oscill_ex, :protocol)
        Application.delete_env(:oscill_ex, :executable)
        Application.delete_env(:oscill_ex, :port)
      end)
    end

    test "falls back to provided defaults" do
      {:ok, config} = Config.build()

      assert config.executable == "scsynth"
      assert config.port == 57110
      assert config.protocol == :udp
    end
  end

  describe "command_list/1" do
    test "returns the generated command based on the configured parameters" do
      {:ok, config} = Config.build(executable: "/my/custom/scsynth", port: 75234)

      assert Config.command_list(config) == ["/my/custom/scsynth", "-u", "75234"]
    end
  end
end
