defmodule OscillEx.Osc.MessageTest do
  use ExUnit.Case, async: true

  alias EarmarkParser.Message
  alias OscillEx.Osc.Message

  describe "to_osc/1" do
    test "with 0 parameters" do
      message = Message.new("/status")

      assert Message.to_osc(message) == <<"/status", 0>>
    end

    test "with a single integer parameter" do
      message = Message.new("/one_integer", [17])

      assert Message.to_osc(message) ==
               <<"/one_integer", 0, 0, 0, 0, ",i", 0, 0, 0, 0, 0, 17>>
    end

    test "with a single string parameter" do
      message = Message.new("/one_string", ["-4.5"])

      assert Message.to_osc(message) ==
               <<"/one_string", 0, ",s", 0, 0, "-4.5", 0, 0, 0, 0>>
    end

    test "with a single float parameter" do
      message = Message.new("/one_float", [-:math.pi()])

      assert Message.to_osc(message) ==
               <<"/one_float", 0, 0, ",f", 0, 0, 192, 73, 15, 219>>
    end

    test "with a single blob parameter" do
      message = Message.new("/one_blob", [<<1, 2, 3, 4, 5>>])

      assert Message.to_osc(message) ==
               <<"/one_blob", 0, 0, 0, ",b", 0, 0, 0, 0, 0, 5, 1, 2, 3, 4, 5, 0, 0, 0>>
    end

    test "with multiple parameters" do
      message = Message.new("/hello", [17, "-4.5", -4.5, <<17, 18, 19>>])

      assert Message.to_osc(message) ==
               <<"/hello", 0, 0, ",isfb", 0, 0, 0, 0, 0, 0, 17, 45, 52, 46, 53, 0, 0, 0, 0, 192,
                 144, 0, 0, 0, 0, 0, 3, 17, 18, 19, 0>>
    end
  end
end
