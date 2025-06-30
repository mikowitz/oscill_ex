defmodule OscillEx.Test.Support.Assertions do
  @moduledoc false

  import ExUnit.Assertions

  def assert_status(pid, status) do
    assert :sys.get_state(pid).status == status
  end

  def assert_error(pid, error) do
    assert :sys.get_state(pid).error == error
  end

  def assert_has_open_port(pid) do
    port = :sys.get_state(pid).port
    assert is_port(port)
    assert is_list(Port.info(port))
  end

  def assert_no_port(pid) do
    state = :sys.get_state(pid)
    assert is_nil(state.port)
    assert is_nil(state.monitor)
  end

  def assert_has_udp_socket(pid) do
    state = :sys.get_state(pid)
    assert is_map(state.udp)
    assert is_port(state.udp.socket)
    assert is_integer(state.udp.port)
    assert is_reference(state.udp.monitor)
  end

  def assert_no_udp_socket(pid) do
    state = :sys.get_state(pid)
    assert is_nil(state.udp)
  end
end
