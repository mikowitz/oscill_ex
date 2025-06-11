Mox.defmock(OscillEx.MockPortHelper, for: OscillEx.PortHelper)
Application.put_env(:oscill_ex, :port_helper, OscillEx.MockPortHelper)

defmodule OscillEx.TestHelpers do
  import Mox

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

ExUnit.start()
