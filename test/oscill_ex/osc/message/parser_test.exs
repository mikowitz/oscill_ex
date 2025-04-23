defmodule OscillEx.Osc.Message.ParserTest do
  use ExUnit.Case, async: true

  alias EarmarkParser.Message
  alias EarmarkParser.Message
  alias OscillEx.Osc.Message
  alias OscillEx.Osc.Message.Parser

  describe "parse/1 with 0 parameters" do
    test "parsing a message" do
      message = <<47, 105, 110, 102, 111, 0, 0, 0>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/info", parameters: []}}
    end

    test "parsing a message with 4-byte padding on the address" do
      message = <<47, 109, 105, 99, 104, 97, 101, 108, 0, 0, 0, 0>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/michael", parameters: []}}
    end
  end

  describe "parse/1 with integer parameters" do
    test "with 1 integer parameter" do
      message = <<47, 105, 0, 0, 44, 105, 0, 0, 0, 0, 0, 8>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/i", parameters: [8]}}
    end

    test "with multiple integer parameters" do
      message =
        <<47, 105, 0, 0, 44, 105, 105, 105, 0, 0, 0, 0, 0, 0, 0, 8, 0, 0, 100, 10, 255, 255, 255,
          255>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/i", parameters: [8, 25_610, -1]}}
    end
  end

  describe "parse/1 with float parameters" do
    test "with 1 float parameter" do
      message = <<47, 102, 0, 0, 44, 102, 0, 0, 75, 0, 0, 1>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/f", parameters: [8_388_609.0]}}
    end

    test "with multiple float parameters" do
      message = <<47, 102, 0, 0, 44, 102, 102, 0, 75, 0, 0, 1, 200, 100, 2, 1>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/f", parameters: [8_388_609.0, -233_480.015625]}}
    end
  end

  describe "parse/1 with string parameters" do
    test "with 1 string parameter" do
      message =
        <<47, 115, 116, 114, 0, 0, 0, 0, 44, 115, 0, 0, 116, 101, 115, 116, 105, 110, 103, 0>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/str", parameters: ["testing"]}}
    end

    test "with multiple string parameters" do
      message =
        <<47, 110, 97, 109, 101, 0, 0, 0, 44, 115, 115, 0, 109, 105, 99, 104, 97, 101, 108, 0, 98,
          101, 114, 107, 111, 119, 105, 116, 122, 0, 0, 0>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/name", parameters: ["michael", "berkowitz"]}}
    end
  end

  describe "parse/1 with blob parameters" do
    test "with 1 blob parameter" do
      message = <<47, 98, 108, 111, 98, 0, 0, 0, 44, 98, 0, 0, 0, 0, 0, 3, 255, 254, 253, 0>>

      assert Parser.parse(message) ==
               {:ok, %Message{address: "/blob", parameters: [<<255, 254, 253>>]}}
    end

    test "with multiple blob parameters" do
      message =
        <<47, 98, 108, 111, 98, 0, 0, 0, 44, 98, 98, 0, 0, 0, 0, 3, 255, 254, 253, 0, 0, 0, 0, 5,
          1, 2, 3, 4, 5, 0, 0, 0>>

      assert Parser.parse(message) ==
               {:ok,
                %Message{address: "/blob", parameters: [<<255, 254, 253>>, <<1, 2, 3, 4, 5>>]}}
    end
  end

  describe "parse/1 with mixed parameters" do
    message =
      <<47, 116, 101, 115, 116, 0, 0, 0, 44, 105, 105, 102, 115, 98, 115, 105, 0, 0, 0, 0, 0, 0,
        0, 1, 0, 0, 0, 2, 80, 1, 1, 2, 45, 54, 0, 0, 0, 0, 0, 3, 7, 8, 9, 0, 49, 48, 46, 49, 49,
        0, 0, 0, 0, 0, 0, 12>>

    assert Parser.parse(message) ==
             {:ok,
              %Message{
                address: "/test",
                parameters: [1, 2, 8_657_307_648.0, "-6", <<7, 8, 9>>, "10.11", 12]
              }}
  end

  describe "parse/1 error handling" do
    test "with an address with invalid padding" do
      message = <<47, 116, 101, 115, 116, 0>>

      assert Parser.parse(message) == {:error, :invalid_osc_message}
    end

    test "without defined parameters" do
      message = <<47, 116, 101, 115, 116, 0, 0, 0, ",i", 0, 0>>

      assert Parser.parse(message) == {:error, :invalid_osc_message}
    end

    test "without incorrectly sized parameters" do
      message = <<47, 116, 101, 115, 116, 0, 0, 0, ",i", 0, 0, 0, 0, 3>>

      assert Parser.parse(message) == {:error, :invalid_osc_message}
    end
  end
end
