defmodule OscillEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :oscill_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {OscillEx.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7.12", only: [:test], runtime: false},
      {:ex_doc, "~> 0.38.2"},
      {:mix_test_watch, "~> 1.2.0", only: [:test], runtime: false},
      {:mox, "~> 1.2.0", only: [:test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
