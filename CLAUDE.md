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
- GenServer that manages a configurable `scsynth` process
- Handles process lifecycle (boot, quit, crash recovery)
- Manages UDP socket for OSC communication
- State machine with statuses: `:stopped`, `:booting`, `:running`, `:error`, `:crashed`

**OscillEx.Server.Config** (`lib/oscill_ex/server/config.ex`)
- Configuration struct for `scsynth` server parameters
- Generates command-line arguments for the `scsynth` executable
- Supports both UDP and TCP protocols
- Extensive configuration options for audio settings, buffers, and network parameters

### Key Patterns

**Port Management**
- Uses Erlang ports to spawn and monitor external `scsynth` processes
- Implements proper cleanup on process termination
- Handles various exit scenarios and error conditions

**UDP Transport Layer**
- Opens dynamic UDP socket on boot for OSC message communication
- Automatically restarts UDP socket if it crashes while server is running
- Monitors both the main process port and UDP socket independently

**Error Handling**
- Validates executable existence and permissions before starting
- Parses `scsynth` error messages to provide specific error reasons
- Graceful handling of port conflicts and invalid arguments

**Configuration**
- Flexible configuration accepting structs, maps, or keyword lists
- Command-line argument generation with smart defaults
- Type-safe configuration with comprehensive @type specifications

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