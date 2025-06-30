defmodule OscillEx.ScsynthTest do
  use ExUnit.Case, async: true

  alias OscillEx.Scsynth
  alias OscillEx.Server.Config

  import OscillEx.Test.Support.ExecutableHelpers

  describe "start_process/1" do
    test "successfully starts a process with valid executable" do
      with_test_config(fn config ->
        assert {:ok, port, monitor} = Scsynth.start_process(config)
        assert is_port(port)
        assert is_reference(monitor)
        assert Port.info(port) != nil

        # Cleanup
        Port.demonitor(monitor, [:flush])
        Port.close(port)
      end)
    end

    test "returns error when executable doesn't exist" do
      config = Config.new(executable: "/this/file/does/not/exist")

      assert {:error, {:file_not_found, "/this/file/does/not/exist"}} =
               Scsynth.start_process(config)
    end

    test "returns error when executable isn't a regular file" do
      :ok = File.mkdir("test-directory")
      config = Config.new(executable: "test-directory")

      expected_error = {:not_executable, "test-directory is a directory, not an executable file"}
      assert {:error, ^expected_error} = Scsynth.start_process(config)

      on_exit(fn -> File.rmdir("test-directory") end)
    end

    test "returns error when user lacks permission to execute file" do
      :ok = File.touch("non-executable-file")
      File.chmod("non-executable-file", 0o644)
      config = Config.new(executable: "non-executable-file")

      assert {:error, {:permission_denied, "non-executable-file"}} =
               Scsynth.start_process(config)

      on_exit(fn -> File.rm("non-executable-file") end)
    end

    test "passes correct arguments to the process" do
      with_test_config(:capture_args, fn config ->
        {:ok, port, monitor} = Scsynth.start_process(config)

        wait_for_condition(
          fn -> Port.info(port) == nil end,
          5000,
          "Expected port to have closed"
        )

        assert Port.info(port) == nil

        assert File.read!("args_output") == "-u 57110 -R 0 -l 1"

        # Cleanup
        Port.demonitor(monitor, [:flush])
        on_exit(fn -> File.rm("args_output") end)
      end)
    end
  end

  describe "stop_process/2" do
    test "closes port and demonitors when port is alive" do
      with_test_config(fn config ->
        {:ok, port, monitor} = Scsynth.start_process(config)

        assert is_port(port)
        assert is_reference(monitor)
        assert Port.info(port) != nil

        :ok = Scsynth.stop_process(port, monitor)

        assert Port.info(port) == nil
      end)
    end

    test "handles already closed port gracefully" do
      with_test_config(fn config ->
        {:ok, port, monitor} = Scsynth.start_process(config)

        Port.close(port)

        # Should not raise error even if port is already closed
        assert :ok = Scsynth.stop_process(port, monitor)
      end)
    end

    test "handles nil port and monitor gracefully" do
      assert :ok = Scsynth.stop_process(nil, nil)
    end

    test "handles only nil port gracefully" do
      with_test_config(fn config ->
        {:ok, _port, monitor} = Scsynth.start_process(config)

        assert :ok = Scsynth.stop_process(nil, monitor)
      end)
    end

    test "handles only nil monitor gracefully" do
      with_test_config(fn config ->
        {:ok, port, _monitor} = Scsynth.start_process(config)

        assert :ok = Scsynth.stop_process(port, nil)
        # Ensure port is still closed
        assert Port.info(port) == nil
      end)
    end
  end

  describe "handle_exit_status/1" do
    test "returns nil for exit code 0" do
      assert Scsynth.handle_exit_status(0) == nil
    end

    test "returns error tuple for non-zero exit codes" do
      assert Scsynth.handle_exit_status(1) == {:exit, 1}
      assert Scsynth.handle_exit_status(127) == {:exit, 127}
      assert Scsynth.handle_exit_status(255) == {:exit, 255}
    end
  end

  describe "handle_port_down/1" do
    test "returns error tuple with reason" do
      assert {:exit, :normal} = Scsynth.handle_port_down(:normal)
      assert {:exit, :killed} = Scsynth.handle_port_down(:killed)
      assert {:exit, {:error, :some_reason}} = Scsynth.handle_port_down({:error, :some_reason})
    end
  end

  describe "parse_scsynth_error/1" do
    test "detects port in use error" do
      error_data = "*** ERROR: failed to open socket: address in use."
      assert {:error, :scsynth_port_in_use} = Scsynth.parse_scsynth_error(error_data)
    end

    test "detects invalid arguments error" do
      error_data = "ERROR: Invalid option --z"
      assert {:error, :scsynth_invalid_args} = Scsynth.parse_scsynth_error(error_data)
    end

    test "detects missing required arguments error" do
      error_data = "ERROR: There must be a -u and/or a -t options"
      assert {:error, :scsynth_invalid_args} = Scsynth.parse_scsynth_error(error_data)
    end

    test "returns :ok for normal output" do
      normal_data = "SuperCollider 3 server ready."
      assert :ok = Scsynth.parse_scsynth_error(normal_data)
    end

    test "returns :ok for empty data" do
      assert :ok = Scsynth.parse_scsynth_error("")
    end

    test "returns :ok for unrecognized error messages" do
      unknown_error = "Some other kind of message"
      assert :ok = Scsynth.parse_scsynth_error(unknown_error)
    end
  end

  describe "integration tests" do
    test "full lifecycle with successful process" do
      executable = create_executable(:scsynth_success)
      config = Config.new(executable: executable)

      # Start process
      {:ok, port, monitor} = Scsynth.start_process(config)
      assert is_port(port)
      assert is_reference(monitor)

      # Simulate receiving data
      test_data = "SuperCollider 3 server ready."
      assert :ok = Scsynth.parse_scsynth_error(test_data)

      # Stop process
      :ok = Scsynth.stop_process(port, monitor)
      assert Port.info(port) == nil
    end

    test "full lifecycle with process that has port conflicts" do
      executable = create_executable(:scsynth_port_in_use)
      config = Config.new(executable: executable)

      {:ok, port, monitor} = Scsynth.start_process(config)

      # Wait for process to output error and exit
      :timer.sleep(500)

      # Simulate receiving the error data that would come from the port
      error_data = "*** ERROR: failed to open socket: address in use."
      assert {:error, :scsynth_port_in_use} = Scsynth.parse_scsynth_error(error_data)

      # Cleanup
      Scsynth.stop_process(port, monitor)
    end

    test "full lifecycle with invalid arguments" do
      executable = create_executable(:scsynth_invalid_arg)
      config = Config.new(executable: executable)

      {:ok, port, monitor} = Scsynth.start_process(config)

      # Wait for process to output error
      :timer.sleep(500)

      error_data = "ERROR: Invalid option --z"
      assert {:error, :scsynth_invalid_args} = Scsynth.parse_scsynth_error(error_data)

      Scsynth.stop_process(port, monitor)
    end
  end

  describe "edge cases" do
    test "handles very long executable paths" do
      # Create a deeply nested directory structure
      long_path_parts = for i <- 1..50, do: "dir#{i}"
      long_path = Enum.join(long_path_parts, "/")

      config = Config.new(executable: long_path)
      assert {:error, {:file_not_found, ^long_path}} = Scsynth.start_process(config)
    end

    test "handles executable paths with special characters" do
      special_chars_path = "path with spaces & symbols!@#$%^&*()"
      config = Config.new(executable: special_chars_path)

      assert {:error, {:file_not_found, ^special_chars_path}} = Scsynth.start_process(config)
    end

    test "handles multiple rapid start/stop cycles" do
      executable = create_executable(:exit_normal)
      config = Config.new(executable: executable)

      # Perform multiple rapid start/stop cycles
      for _i <- 1..5 do
        {:ok, port, monitor} = Scsynth.start_process(config)
        :ok = Scsynth.stop_process(port, monitor)
      end
    end

    test "handles port monitoring edge cases" do
      executable = create_executable(:long_running)
      config = Config.new(executable: executable)
      {:ok, port, monitor} = Scsynth.start_process(config)

      # Manually close the port to simulate unexpected termination
      Port.close(port)

      # The monitor should still be valid even after port is closed
      assert is_reference(monitor)

      # Cleanup should handle this gracefully
      :ok = Scsynth.stop_process(port, monitor)
    end

    test "handles concurrent process starts" do
      with_test_config(fn config ->
        tasks =
          for _i <- 1..3 do
            Task.async(fn -> Scsynth.start_process(config) end)
          end

        results = Task.await_many(tasks, 5000)

        # All should succeed
        for {:ok, port, monitor} <- results do
          assert is_port(port)
          assert is_reference(monitor)
          Scsynth.stop_process(port, monitor)
        end
      end)

      # Start multiple processes concurrently
    end

    test "handles malformed scsynth error messages" do
      malformed_errors = [
        "ERROR but not matching our patterns",
        "address in use but not the full pattern",
        "Invalid option but missing context",
        nil,
        123,
        []
      ]

      for error_data <- malformed_errors do
        # Should not crash and should return :ok for unrecognized patterns
        result = Scsynth.parse_scsynth_error(error_data)
        assert result == :ok
      end
    end
  end
end
