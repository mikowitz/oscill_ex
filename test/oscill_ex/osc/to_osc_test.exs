defmodule OscillEx.Osc.ToOscTest do
  use ExUnit.Case, async: true

  alias OscillEx.Osc.ToOsc

  describe "to_osc/1" do
    test "integer" do
      assert ToOsc.to_osc(1) == {?i, <<0, 0, 0, 1>>}
      assert ToOsc.to_osc(-1) == {?i, <<255, 255, 255, 255>>}
    end

    test "float" do
      assert ToOsc.to_osc(39.917) == {?f, <<66, 31, 171, 2>>}
      assert ToOsc.to_osc(-1.0) == {?f, <<191, 128, 0, 0>>}
    end

    test "string" do
      assert ToOsc.to_osc("michael") == {?s, <<?m, ?i, ?c, ?h, ?a, ?e, ?l, 0>>}
    end

    test "blob" do
      assert ToOsc.to_osc(<<1, 2, 3, 4>>) == {?b, <<0, 0, 0, 4, 1, 2, 3, 4>>}
      assert ToOsc.to_osc(<<1, 2, 3>>) == {?b, <<0, 0, 0, 3, 1, 2, 3, 0>>}
    end
  end
end
