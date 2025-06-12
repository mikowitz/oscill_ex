defmodule OscillEx.OSCTest do
  use ExUnit.Case, async: true

  alias OscillEx.OSC

  describe "encode_message/2" do
    test "a basic message with no arguments" do
      assert OSC.encode_message("/status", []) == <<"/status", 0>>
    end

    test "a message with a single integer argument" do
      assert OSC.encode_message("/int", [1]) == <<"/int", 0, 0, 0, 0, ",i", 0, 0, 0, 0, 0, 1>>
    end

    test "a message with float arguments" do
      assert OSC.encode_message("/floats", [912.1875, 1600.3125]) ==
               <<"/floats", 0, ",ff", 0, 68, 100, 12, 0, 68, 200, 10, 0>>
    end

    test "a message with mixed arguments" do
      assert OSC.encode_message("/grab_bag", ["sine", 0, 1, "foo", 7.25]) ==
               <<"/grab_bag", 0, 0, 0, ",siisf", 0, 0, "sine", 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
                 "foo", 0, 64, 232, 0, 0>>
    end
  end
end
