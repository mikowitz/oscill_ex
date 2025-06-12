defmodule OscillEx.TestHelpers do
  @moduledoc false
  import Mox

  def stub_missing_executable do
    stub(OscillEx.MockPortHelper, :find_executable, fn _ -> nil end)
  end

  def stub_erroring_executable do
    stub(OscillEx.MockPortHelper, :info, fn _name -> nil end)
  end

  def setup_mock_port_helper(_setup) do
    stub(OscillEx.MockPortHelper, :find_executable, &Function.identity/1)

    stub(OscillEx.MockPortHelper, :open, fn _name, _opts ->
      Port.open({:spawn_executable, "./bin/scsynth_wrapper"}, [
        :binary,
        args: ["./bin/dummy_scsynth"]
      ])
    end)

    stub(OscillEx.MockPortHelper, :info, fn _port -> [] end)

    :ok
  end
end
