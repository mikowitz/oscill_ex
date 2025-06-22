alias OscillEx.Server

scsynth = "/Applications/SuperCollider.app/Contents/Resources/scsynth"

{:ok, server} = Server.start_link(executable: scsynth, input_bus_channel_count: 0)

