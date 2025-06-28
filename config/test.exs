import Config

config :mix_test_watch,
  tasks: [
    "format",
    "credo --strict --all",
    "test"
  ]
