defmodule OscillEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :oscill_ex,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7.12", only: [:test]},
      {:ex_doc, "~> 0.37.3"},
      {:mix_test_watch, "~> 1.2.0", only: [:test]}
    ]
  end
end
