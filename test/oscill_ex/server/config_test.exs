defmodule OscillEx.Server.ConfigTest do
  use ExUnit.Case, async: true
  import OscillEx.TestHelpers

  alias OscillEx.Server.Config

  import Mox
  setup :verify_on_exit!
  setup :setup_mock_port_helper

  def stub_env_var(key, value) do
    config = Application.get_env(:oscill_ex, :server_config, [])
    config = Keyword.put(config, key, value)
    Application.put_env(:oscill_ex, :server_config, config)

    on_exit(fn ->
      Application.delete_env(:oscill_ex, :server_config)
    end)
  end

  describe "build/1" do
    test "builds from explicitly passed in configuration" do
      {:ok, config} = Config.build(executable: "/my/custom/scsynth", port: 75234)

      assert config.executable == "/my/custom/scsynth"
      assert config.port == 75234
      assert config.protocol == :udp
    end

    test "falls back to Application env" do
      stub_env_var(:protocol, :tcp)
      stub_env_var(:executable, "/my/env/scsynth")
      stub_env_var(:port, 10222)

      {:ok, config} = Config.build()

      assert config.executable == "/my/env/scsynth"
      assert config.port == 10222
      assert config.protocol == :tcp
    end

    test "falls back to provided defaults" do
      {:ok, config} = Config.build()

      assert config.executable == "scsynth"
      assert config.port == 57110
      assert config.protocol == :udp
    end

    test "logs and returns an error if the executable cannot be found" do
      stub_missing_executable()

      assert {:error, :missing_scsynth_executable} == Config.build()
    end
  end

  describe "command_list/1" do
    test "returns the generated command based on the configured parameters" do
      {:ok, config} = Config.build(executable: "/my/custom/scsynth", port: 75234)

      assert Config.command_list(config) == ["/my/custom/scsynth", "-u", "75234"]
    end
  end
end
