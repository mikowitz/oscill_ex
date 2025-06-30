# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- Run tests: `MIX_ENV=test mix test`
- Run tests with file watching: `MIX_ENV=test mix test.watch`
- Run a specific test file: `MIX_ENV=test mix test test/path/to/test_file.exs`

### Code Quality
- Code formatting: `mix format`
- Linting with Credo: `mix credo`
- Strict linting: `mix credo --strict`

### Build and Dependencies
- Compile project: `mix compile`
- Install dependencies: `mix deps.get`
- Update dependencies: `mix deps.update --all`
- Clean build artifacts: `mix clean`

### Interactive Development
- Start IEx with project loaded: `iex -S mix`

## Project Architecture

### Core Components

**OscillEx.Server** (`lib/oscill_ex/server.ex`)
- GenServer that manages a configurable `scsynth` process with complete lifecycle management
- Handles process lifecycle (boot, quit, crash recovery) with proper state transitions
- Manages UDP socket for OSC communication with automatic recovery
- State machine with statuses: `:stopped`, `:running`, `:error`, `:crashed`
- Provides public API: `start_link/1`, `boot/1`, `quit/1`, `send_osc_message/2`
- Comprehensive documentation with usage examples and error handling patterns

**OscillEx.Server.Config** (`lib/oscill_ex/server/config.ex`)
- Configuration struct for `scsynth` server parameters with extensive options
- Generates command-line arguments for the `scsynth` executable with smart defaults
- Supports both UDP and TCP protocols with type-safe configuration
- Comprehensive configuration categories: Network, Audio, Resource Limits, Security & Access
- Public API: `new/1`, `default/0`, `command_line_args/1`
- Full documentation of all configuration options and their defaults

**OscillEx.Scsynth** (`lib/oscill_ex/scsynth.ex`)
- Low-level process management for external `scsynth` processes
- Handles executable validation, spawning, monitoring, and cleanup
- Provides structured error handling for common failure scenarios
- Parses `scsynth` stderr output for meaningful error identification
- Public API: `start_process/1`, `stop_process/2`, `close_port/2`, error handling functions
- Uses wrapper script (`./bin/wrapper`) for consistent process spawning

**OscillEx.UdpSocket** (`lib/oscill_ex/udp_socket.ex`)
- UDP socket management for OSC (Open Sound Control) communication
- Handles socket lifecycle with automatic monitoring and cleanup
- Provides simple interface for OSC message transmission
- Socket represented as map with `socket`, `port`, and `monitor` fields
- Public API: `open/0`, `close/1`, `send_message/4`
- Active mode sockets for real-time message reception

### Key Patterns

**Layered Architecture**
- High-level GenServer (`OscillEx.Server`) for user-facing API and state management
- Mid-level process management (`OscillEx.Scsynth`) for `scsynth` lifecycle
- Low-level transport (`OscillEx.UdpSocket`) for OSC communication
- Configuration layer (`OscillEx.Server.Config`) with comprehensive options

**Port Management**
- Uses Erlang ports to spawn and monitor external `scsynth` processes via wrapper script
- Implements proper cleanup on process termination with demonitor and port closure
- Handles various exit scenarios and error conditions with structured error terms
- Separates concerns between process spawning and socket management

**UDP Transport Layer**
- Opens dynamic UDP socket on boot for OSC message communication
- Automatically restarts UDP socket if it crashes while server is running
- Monitors both the main process port and UDP socket independently
- Active mode sockets for real-time bidirectional communication

**Error Handling**
- Multi-level error handling from executable validation to runtime errors
- Validates executable existence, type, and permissions before starting
- Parses `scsynth` stderr output to provide specific, actionable error reasons
- Graceful handling of port conflicts, invalid arguments, and process crashes
- Structured error terms for consistent error propagation

**Configuration Management**
- Flexible configuration accepting structs, maps, or keyword lists
- Command-line argument generation with smart defaults (omits default values)
- Type-safe configuration with comprehensive `@type` specifications
- Categorized options: Network, Audio, Resource Limits, Security & Access
- Development-friendly defaults via `Config.default/0`

**Documentation Standards**
- Comprehensive `@moduledoc` with usage examples and architecture explanations
- Complete `@spec` type specifications for all public functions
- Detailed function documentation with parameters, returns, and examples
- Error case documentation with specific error terms and scenarios

## Code Style Guidelines

**Function Design**
- Prefer multi-clause functions with guards over conditional logic within function bodies
- When conditional clauses can be restructured into pattern matching with guards, always choose the multi-clause approach for better readability and idiomatic Elixir code

## Testing Notes

- Uses ExUnit with async tests where possible
- Comprehensive test coverage including edge cases and error conditions
- Creates temporary executable files for testing process management
- Tests UDP socket lifecycle and recovery scenarios
- Uses helper functions for state inspection and assertions

## Interaction Guidelines

**Edit Approval Workflow**
- Never activate auto-accept edits mode without asking me first
- Even after approving a plan, each individual edit must be reviewed and approved separately
- Always ask for explicit permission before switching to any auto-accept mode

**Testing**
- Do not run `mix test` - the user has `mix test.watch` running in another terminal to monitor test failures automatically