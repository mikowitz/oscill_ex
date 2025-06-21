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
            # -u / - v
            port: 57110,
            protocol: :udp,
            # -B
            ip_address: "127.0.0.1",
            # -c
            control_bus_channel_count: 16_384,
            # -a
            audio_bus_channel_count: 1024,
            # -i
            input_bus_channel_count: 8,
            # -o
            output_bus_channel_count: 8,
            # -z
            block_size: 64,
            # -Z
            hardware_buffer_size: 0,
            # -S
            hardware_sample_rate: 0,
            # -b
            sample_buffer_count: 1024,
            # -n
            node_max_count: 1024,
            # -d
            synthdef_max_count: 1024,
            # -m
            realtime_memory_size: 8192,
            # - w
            wire_buffer_count: 64,
            # -r
            random_seed_count: 64,
            # -D
            load_synthdefs: true,
            # -R
            publish_to_rendezvous: false,
            # -l
            max_logins: 1,
            # -p
            password: nil,
            # -s
            safety_clip: nil,
            # -I
            input_streams_enabled: "",
            # -O
            output_streams_enabled: "",
            # -V
            verbosity: 0,
            # -U
            ugens_plugin_path: nil,
            # -P
            restricted_path: nil

  def new(config \\ []) do
    struct(__MODULE__, config)
  end

  @blank [nil, ""]
  def command_line_args(%__MODULE__{} = config) do
    [
      config.executable,
      port(config),
      if_not_default(config.ip_address, "-B", "127.0.0.1"),
      if_not_default(config.control_bus_channel_count, "-c", 16_384),
      if_not_default(config.audio_bus_channel_count, "-a", 1024),
      if_not_default(config.input_bus_channel_count, "-i", 8),
      if_not_default(config.output_bus_channel_count, "-o", 8),
      if_not_default(config.block_size, "-z", 64),
      if_not_default(config.hardware_buffer_size, "-Z", 0),
      if_not_default(config.hardware_sample_rate, "-S", 0),
      if_not_default(config.sample_buffer_count, "-b", 1024),
      if_not_default(config.node_max_count, "-n", 1024),
      if_not_default(config.synthdef_max_count, "-d", 1024),
      if_not_default(config.realtime_memory_size, "-m", 8192),
      if_not_default(config.wire_buffer_count, "-w", 64),
      if_not_default(config.random_seed_count, "-r", 64),
      if_not_default(config.load_synthdefs, "-D", [1, true], &boolean_as_int/1),
      if_not_default(config.publish_to_rendezvous, "-R", [1, true], &boolean_as_int/1),
      if_not_default(config.max_logins, "-l", 64),
      if_not_default(config.password, "-p", @blank),
      if_not_default(config.safety_clip, "-s", nil),
      if_not_default(config.input_streams_enabled, "-I", @blank),
      if_not_default(config.output_streams_enabled, "-O", @blank),
      if_not_default(config.verbosity, "-V", 0),
      if_not_default(config.ugens_plugin_path, "-U", @blank),
      if_not_default(config.restricted_path, "-P", @blank)
    ]
    |> List.flatten()
  end

  defp port(%__MODULE__{protocol: :udp, port: port}), do: ["-u", to_string(port)]
  defp port(%__MODULE__{protocol: :tcp, port: port}), do: ["-t", to_string(port)]

  defp if_not_default(value, flag, defaults, formatting_func \\ &to_string/1)

  defp if_not_default(value, flag, defaults, formatting_func)
       when is_list(defaults) do
    if value in defaults, do: [], else: [flag, formatting_func.(value)]
  end

  defp if_not_default(default, _, default, _), do: []
  defp if_not_default(value, flag, _, formatting_func), do: [flag, formatting_func.(value)]

  defp boolean_as_int(b) do
    case b do
      b when b in [0, nil, false, "0"] -> "0"
      b when b in [1, true, "1"] -> "1"
    end
  end
end
