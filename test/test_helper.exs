Mox.defmock(OscillEx.MockPortHelper, for: OscillEx.PortHelper)
Application.put_env(:oscill_ex, :port_helper, OscillEx.MockPortHelper)
ExUnit.start()
