import Config

config :mix_test_watch,
  tasks: [
    "credo --strict --all",
    "test"
  ]
