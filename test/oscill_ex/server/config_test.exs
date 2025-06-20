defmodule OscillEx.Server.ConfigTest do
  use ExUnit.Case, async: true

  alias OscillEx.Server.Config

  describe "command_line_args/1" do
    test "with all default arguments" do
      config = Config.new()

      assert Config.command_line_args(config) ==
               [
                 "scsynth",
                 "-u",
                 "57110",
                 "-R",
                 "0",
                 "-l",
                 "1"
               ]
    end

    test "with a bunch of config specified" do
      config =
        Config.new(
          executable: "/path/to/scsynth",
          # credo:disable-for-next-line
          port: 10345,
          protocol: :tcp,
          ip_address: "0.0.0.0",
          control_bus_channel_count: 3,
          audio_bus_channel_count: 100,
          input_bus_channel_count: 0,
          output_bus_channel_count: 75,
          output_streams_enabled: "11010011",
          publish_to_rendezvous: true,
          max_logins: 7,
          password: "CHANGEME",
          verbosity: 2,
          block_size: 10,
          hardware_buffer_size: 10,
          hardware_sample_rate: 41_100,
          ugens_plugin_path: "/my/ugens"
        )

      assert Config.command_line_args(config) == [
               "/path/to/scsynth",
               "-t",
               "10345",
               "-B",
               "0.0.0.0",
               "-c",
               "3",
               "-a",
               "100",
               "-i",
               "0",
               "-o",
               "75",
               "-z",
               "10",
               "-Z",
               "10",
               "-S",
               "41100",
               "-l",
               "7",
               "-p",
               "CHANGEME",
               "-O",
               "11010011",
               "-V",
               "2",
               "-U",
               "/my/ugens"
             ]
    end
  end
end
