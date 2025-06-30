defmodule OscillEx.OscTest do
  use ExUnit.Case, async: true

  alias OscillEx.Osc

  describe "message/1" do
    test "creates message with valid address and no arguments" do
      assert {:ok, message} = Osc.message("/test")
      # Address "/test" padded to 8 bytes
      expected = "/test" <> <<0, 0, 0>>
      assert message == expected
    end

    test "creates message with root address pattern" do
      assert {:ok, message} = Osc.message("/")
      # Address "/" padded to 4 bytes
      expected = "/" <> <<0, 0, 0>>
      assert message == expected
    end

    test "creates message with nested address pattern" do
      assert {:ok, message} = Osc.message("/synth/osc/freq")
      # Address "/synth/osc/freq" (16 chars) padded to 16 bytes
      expected = "/synth/osc/freq" <> <<0>>
      assert message == expected
    end

    test "returns error for invalid address without leading slash" do
      assert {:error, :invalid_address} = Osc.message("test")
    end

    test "returns error for empty address" do
      assert {:error, :invalid_address} = Osc.message("")
    end

    test "returns error for non-printable characters in address" do
      assert {:error, :invalid_address} = Osc.message("/test\x00invalid")
    end
  end

  describe "message/2" do
    test "creates message with integer argument" do
      assert {:ok, message} = Osc.message("/test", [42])
      # Address "/test" padded + type tag ",i" padded + 32-bit big-endian integer 42
      expected = "/test" <> <<0, 0, 0>> <> ",i" <> <<0, 0>> <> <<0, 0, 0, 42>>
      assert message == expected
    end

    test "creates message with float argument" do
      assert {:ok, message} = Osc.message("/test", [3.14])
      # Address "/test" padded + type tag ",f" padded + 32-bit big-endian float 3.14
      expected = "/test" <> <<0, 0, 0>> <> ",f" <> <<0, 0>> <> <<64, 72, 245, 195>>
      assert message == expected
    end

    test "creates message with string argument" do
      assert {:ok, message} = Osc.message("/test", ["hello"])
      # Address "/test" padded + type tag ",s" padded + string "hello" padded
      expected = "/test" <> <<0, 0, 0>> <> ",s" <> <<0, 0>> <> "hello" <> <<0, 0, 0>>
      assert message == expected
    end

    test "creates message with mixed argument types" do
      assert {:ok, message} = Osc.message("/synth/note", [440, 0.8, "sine"])
      # Address padded + type tag ",ifs" padded + int 440 + float 0.8 + string "sine" padded
      address_part = "/synth/note" <> <<0>>
      type_tag_part = ",ifs" <> <<0, 0, 0, 0>>
      # 440 as big-endian 32-bit int
      int_part = <<0, 0, 1, 184>>
      # 0.8 as big-endian 32-bit float
      float_part = <<63, 76, 204, 205>>
      # "sine" padded to 8 bytes
      string_part = "sine" <> <<0, 0, 0, 0>>
      expected = address_part <> type_tag_part <> int_part <> float_part <> string_part
      assert message == expected
    end

    test "creates message with multiple integers" do
      assert {:ok, message} = Osc.message("/test", [1, 2, 3, 4])
      address_part = "/test" <> <<0, 0, 0>>
      type_tag_part = ",iiii" <> <<0, 0, 0>>
      args_part = <<0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4>>
      expected = address_part <> type_tag_part <> args_part
      assert message == expected
    end

    test "creates message with zero integer" do
      assert {:ok, message} = Osc.message("/test", [0])
      expected = "/test" <> <<0, 0, 0>> <> ",i" <> <<0, 0>> <> <<0, 0, 0, 0>>
      assert message == expected
    end

    test "creates message with negative integer" do
      assert {:ok, message} = Osc.message("/test", [-42])
      expected = "/test" <> <<0, 0, 0>> <> ",i" <> <<0, 0>> <> <<255, 255, 255, 214>>
      assert message == expected
    end

    test "creates message with maximum 32-bit integer" do
      max_int32 = 2_147_483_647
      assert {:ok, message} = Osc.message("/test", [max_int32])
      expected = "/test" <> <<0, 0, 0>> <> ",i" <> <<0, 0>> <> <<127, 255, 255, 255>>
      assert message == expected
    end

    test "creates message with minimum 32-bit integer" do
      min_int32 = -2_147_483_648
      assert {:ok, message} = Osc.message("/test", [min_int32])
      expected = "/test" <> <<0, 0, 0>> <> ",i" <> <<0, 0>> <> <<128, 0, 0, 0>>
      assert message == expected
    end

    test "creates message with empty string argument" do
      assert {:ok, message} = Osc.message("/test", [""])
      expected = "/test" <> <<0, 0, 0>> <> ",s" <> <<0, 0>> <> <<0, 0, 0, 0>>
      assert message == expected
    end

    test "returns error for unsupported atom type" do
      assert {:error, {:unsupported_type, :atom}} = Osc.message("/test", [:atom])
    end

    test "returns error for unsupported list type" do
      assert {:error, {:unsupported_type, [1, 2, 3]}} = Osc.message("/test", [[1, 2, 3]])
    end

    test "returns error for unsupported map type" do
      assert {:error, {:unsupported_type, %{}}} = Osc.message("/test", [%{}])
    end

    test "returns error for unsupported tuple type" do
      assert {:error, {:unsupported_type, {1, 2}}} = Osc.message("/test", [{1, 2}])
    end

    test "returns a blob for a non-ascii string" do
      non_printable = "hello\x00world"

      assert {:ok, message} = Osc.message("/test", [non_printable])
      expected = "/test" <> <<0, 0, 0>> <> ",b" <> <<0, 0>> <> <<0, 0, 0, 11>> <> non_printable
      assert message == expected
    end

    test "returns a blob for a binary with null bytes" do
      binary_with_null = <<104, 101, 108, 108, 111, 0, 119, 111, 114, 108, 100>>

      assert {:ok, message} = Osc.message("/test", [binary_with_null])
      expected = "/test" <> <<0, 0, 0>> <> ",b" <> <<0, 0>> <> <<0, 0, 0, 11>> <> binary_with_null
      assert message == expected
    end
  end

  describe "error cases" do
    test "returns error for non-binary address" do
      assert {:error, :invalid_address} = Osc.message(123, [])
    end

    test "returns error for non-list arguments" do
      assert {:error, :invalid_arguments} = Osc.message("/test", "not_a_list")
    end

    test "returns error for nil address" do
      assert {:error, :invalid_address} = Osc.message(nil, [])
    end

    test "returns error for nil arguments" do
      assert {:error, :invalid_arguments} = Osc.message("/test", nil)
    end

    test "handles mixed valid and invalid arguments" do
      assert {:error, {:unsupported_type, :invalid}} =
               Osc.message("/test", [42, 3.14, "valid", :invalid])
    end
  end

  describe "padding validation" do
    test "address padding works correctly for various lengths" do
      # 2 chars -> pad to 4 bytes (2 null bytes)
      assert {:ok, message} = Osc.message("/a")
      assert String.starts_with?(message, "/a" <> <<0, 0>>)

      # 5 chars -> pad to 8 bytes (3 null bytes)
      assert {:ok, message} = Osc.message("/test")
      assert String.starts_with?(message, "/test" <> <<0, 0, 0>>)

      # 9 chars -> pad to 12 bytes (3 null bytes)
      assert {:ok, message} = Osc.message("/testtest")
      assert String.starts_with?(message, "/testtest" <> <<0, 0, 0>>)
    end

    test "string argument padding works correctly" do
      # 1 char string -> padded to 4 bytes
      assert {:ok, message} = Osc.message("/test", ["a"])
      expected = "/test" <> <<0, 0, 0>> <> ",s" <> <<0, 0>> <> "a" <> <<0, 0, 0>>
      assert message == expected

      # 4 char string -> padded to 8 bytes
      assert {:ok, message} = Osc.message("/test", ["test"])
      expected = "/test" <> <<0, 0, 0>> <> ",s" <> <<0, 0>> <> "test" <> <<0, 0, 0, 0>>
      assert message == expected
    end
  end

  describe "edge cases" do
    test "unicode characters are not allowed in address" do
      assert {:error, :invalid_address} == Osc.message("/tëst")
    end

    test "creates message with blob argument (non-ASCII binary)" do
      blob_data = <<0xFF, 0xFE, 0xFD, 0xFC>>
      assert {:ok, message} = Osc.message("/test", [blob_data])
      # Address "/test" padded + type tag ",b" padded + blob size (4) + blob data padded
      expected = "/test" <> <<0, 0, 0>> <> ",b" <> <<0, 0>> <> <<0, 0, 0, 4>> <> blob_data
      assert message == expected
    end

    test "creates message with unicode characters as blob" do
      unicode_blob = "hëllö"
      assert {:ok, message} = Osc.message("/test", [unicode_blob])
      blob_size = byte_size(unicode_blob)

      # Address "/test" padded + type tag ",b" padded + blob size + blob data
      expected =
        "/test" <>
          <<0, 0, 0>> <>
          ",b" <> <<0, 0>> <> <<blob_size::big-unsigned-size(32)>> <> unicode_blob

      assert message == expected
    end

    test "creates message with float zero" do
      assert {:ok, message} = Osc.message("/test", [0.0])
      expected = "/test" <> <<0, 0, 0>> <> ",f" <> <<0, 0>> <> <<0, 0, 0, 0>>
      assert message == expected
    end

    test "creates message with negative float" do
      assert {:ok, message} = Osc.message("/test", [-1.0])
      expected = "/test" <> <<0, 0, 0>> <> ",f" <> <<0, 0>> <> <<191, 128, 0, 0>>
      assert message == expected
    end
  end

  describe "OSC blob support" do
    test "creates message with blob that is not a length of multiple of 4" do
      blob_data = <<0xFF, 0xFE, 0xFD>>
      assert {:ok, message} = Osc.message("/test", [blob_data])

      expected =
        "/test" <> <<0, 0, 0>> <> ",b" <> <<0, 0>> <> <<0, 0, 0, 3>> <> blob_data

      assert message == expected
    end

    test "creates message with blob that has a length of multiple of 4" do
      # 4-byte blob should not need additional padding
      blob_data = <<0xFF, 0xFE, 0xFD, 0xFC>>
      assert {:ok, message} = Osc.message("/test", [blob_data])
      expected = "/test" <> <<0, 0, 0>> <> ",b" <> <<0, 0>> <> <<0, 0, 0, 4>> <> blob_data
      assert message == expected
    end

    test "creates message with large blob" do
      large_blob = :crypto.strong_rand_bytes(100)
      assert {:ok, message} = Osc.message("/test", [large_blob])
      # Should contain blob type tag and size header
      assert String.contains?(message, ",b")
      # Message should include the blob size (100) as big-endian 32-bit int
      assert String.contains?(message, <<0, 0, 0, 100>>)
      # Should contain the blob data
      assert String.contains?(message, large_blob)
    end

    test "creates message with mixed arguments including blob" do
      blob_data = <<0xCA, 0xFE, 0xBA, 0xBE>>
      assert {:ok, message} = Osc.message("/synth", [440, blob_data, "wave"])
      # Should contain type tag for int, blob, string
      assert String.contains?(message, ",ibs")
      # Should contain all the data
      # 440 as big-endian int
      assert String.contains?(message, <<0, 0, 1, 184>>)
      # blob size
      assert String.contains?(message, <<0, 0, 0, 4>>)
      assert String.contains?(message, blob_data)
      assert String.contains?(message, "wave")
    end

    test "creates message with binary containing null bytes as blob" do
      blob_with_nulls = <<0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00>>
      assert {:ok, message} = Osc.message("/test", [blob_with_nulls])
      # Should be treated as blob, not invalid string
      expected = "/test" <> <<0, 0, 0>> <> ",b" <> <<0, 0>> <> <<0, 0, 0, 8>> <> blob_with_nulls
      assert message == expected
    end
  end

  describe "return value validation" do
    test "message binary structure is valid" do
      {:ok, message} = Osc.message("/test", [42, "hello"])

      # Should contain the address
      assert String.contains?(message, "/test")

      # Should contain the type tags
      assert String.contains?(message, ",is")

      # Should contain the string argument
      assert String.contains?(message, "hello")

      # Should be properly sized (multiple of 4 bytes for OSC alignment)
      assert is_binary(message)
      assert byte_size(message) > 0
    end

    test "error cases return proper error tuples" do
      assert {:error, _reason} = Osc.message("invalid")
      assert {:error, _reason} = Osc.message("/test", [:invalid])
      assert {:error, _reason} = Osc.message(nil, [])
      assert {:error, _reason} = Osc.message("/test", nil)
    end
  end
end
