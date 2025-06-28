defmodule OscillEx.Server.Config do
  @moduledoc """
  Struct for managing `scsynth` server configuration
  """

  @type t :: %__MODULE__{
          port: pos_integer(),
          protocol: :udp | :tcp,
          ip_address: String.t(),
          control_bus_channel_count: non_neg_integer(),
          audio_bus_channel_count: non_neg_integer(),
          input_bus_channel_count: non_neg_integer(),
          output_bus_channel_count: non_neg_integer(),
          block_size: pos_integer(),
          hardware_buffer_size: non_neg_integer(),
          hardware_sample_rate: non_neg_integer(),
          sample_buffer_count: non_neg_integer(),
          node_max_count: non_neg_integer(),
          synthdef_max_count: non_neg_integer(),
          realtime_memory_size: non_neg_integer(),
          wire_buffer_count: non_neg_integer(),
          random_seed_count: non_neg_integer(),
          load_synthdefs: boolean(),
          publish_to_rendezvous: boolean(),
          max_logins: pos_integer(),
          password: String.t() | nil,
          safety_clip: integer() | nil,
          input_streams_enabled: String.t(),
          output_streams_enabled: String.t(),
          verbosity: non_neg_integer(),
          ugens_plugin_path: String.t() | nil,
          restricted_path: String.t() | nil
        }

  defstruct executable: "scsynth",
            port: 57110,
            protocol: :udp,
            ip_address: "127.0.0.1",
            control_bus_channel_count: 16_384,
            audio_bus_channel_count: 1024,
            input_bus_channel_count: 8,
            output_bus_channel_count: 8,
            block_size: 64,
            hardware_buffer_size: 0,
            hardware_sample_rate: 0,
            sample_buffer_count: 1024,
            node_max_count: 1024,
            synthdef_max_count: 1024,
            realtime_memory_size: 8192,
            wire_buffer_count: 64,
            random_seed_count: 64,
            load_synthdefs: true,
            publish_to_rendezvous: false,
            max_logins: 1,
            password: nil,
            safety_clip: nil,
            input_streams_enabled: "",
            output_streams_enabled: "",
            verbosity: 0,
            ugens_plugin_path: nil,
            restricted_path: nil

  def new(config \\ []) do
    struct(__MODULE__, config)
  end

  @blank [nil, ""]
  def command_line_args(%__MODULE__{} = config) do
    base_args = [config.executable, port_args(config)]

    config
    |> arg_specifications()
    |> Enum.reduce(base_args, &maybe_add_arg/2)
    |> List.flatten()
  end

  defp maybe_add_arg([value, defaults, flag, formatter], args) do
    new_args = if value in defaults, do: [], else: [flag, formatter.(value)]

    args ++ new_args
  end

  defp arg_specifications(%__MODULE__{} = config) do
    [
      [config.ip_address, "127.0.0.1", "-B"],
      [config.control_bus_channel_count, 16_384, "-c"],
      [config.audio_bus_channel_count, 1024, "-a"],
      [config.input_bus_channel_count, 8, "-i"],
      [config.output_bus_channel_count, 8, "-o"],
      [config.block_size, 64, "-z"],
      [config.hardware_buffer_size, 0, "-Z"],
      [config.hardware_sample_rate, 0, "-S"],
      [config.sample_buffer_count, 1024, "-b"],
      [config.node_max_count, 1024, "-n"],
      [config.synthdef_max_count, 1024, "-d"],
      [config.realtime_memory_size, 8192, "-m"],
      [config.wire_buffer_count, 64, "-w"],
      [config.random_seed_count, 64, "-r"],
      [config.load_synthdefs, [1, true], "-D", &boolean_as_int/1],
      [config.publish_to_rendezvous, [1, true], "-R", &boolean_as_int/1],
      [config.max_logins, 64, "-l"],
      [config.password, @blank, "-p"],
      [config.safety_clip, [nil, false], "-s"],
      [config.input_streams_enabled, @blank, "-I"],
      [config.output_streams_enabled, @blank, "-O"],
      [config.verbosity, 0, "-V"],
      [config.ugens_plugin_path, @blank, "-U"],
      [config.restricted_path, @blank, "-P"]
    ]
    |> Enum.map(fn
      [v, d, f] -> [v, List.wrap(d), f, &to_string/1]
      [v, d, f, fmt] -> [v, List.wrap(d), f, fmt]
    end)
  end

  defp port_args(%__MODULE__{protocol: :udp, port: port}), do: ["-u", to_string(port)]
  defp port_args(%__MODULE__{protocol: :tcp, port: port}), do: ["-t", to_string(port)]

  defp boolean_as_int(b) do
    case b do
      b when b in [0, nil, false, "0"] -> "0"
      b when b in [1, true, "1"] -> "1"
    end
  end
end
