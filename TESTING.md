# Testing Guide

Fast testing workflow for local development.

## Quick Start

```bash
# 1. Start infrastructure
./dev.sh infra

# 2. Run all tests
./dev.sh test

# 3. Run tests for specific service
./dev.sh test user_svc

# 4. Run with coverage
cd apps/user_svc
mix test --cover
```

## Testing Strategy

### 1. Unit Tests
Test individual functions and modules in isolation.

```elixir
# test/clients/job_svc_client_test.exs
defmodule JobService.Clients.JobSvcClientTest do
  use ExUnit.Case

  test "encodes email request correctly" do
    request = %{
      "id" => "1",
      "name" => "Test User",
      "email" => "test@example.com",
      "type" => "welcome"
    }

    encoded = Mcsv.EmailRequest.encode(request)
    assert is_binary(encoded)
  end
end
```

### 2. Integration Tests
Test service interactions (requires services running).

```elixir
# test/integration/email_flow_test.exs
defmodule Integration.EmailFlowTest do
  use ExUnit.Case

  @tag :integration
  test "complete email workflow" do
    # Create user via user_svc
    {:ok, response} = Client.create(1)
    assert response.status == 200

    # Wait for email job to process
    :timer.sleep(2000)

    # Verify job completed
    # Check logs or query job_svc
  end
end
```

Run integration tests:
```bash
# Start all services first
./dev.sh start user_svc  # Terminal 1
./dev.sh start job_svc   # Terminal 2
./dev.sh start email_svc # Terminal 3

# Run integration tests
cd apps/user_svc
mix test --only integration
```

### 3. Contract Testing (OpenAPI)
Validate that services match their OpenAPI specs.

#### Validate Specs
```bash
cd openapi
make validate
```

#### Add to Test Suite
```elixir
# test/contract/openapi_test.exs
defmodule Contract.OpenAPITest do
  use ExUnit.Case

  @spec_path "../../openapi/user_svc.yaml"

  test "GET /health matches OpenAPI spec" do
    {:ok, spec} = YamlElixir.read_from_file(@spec_path)

    # Make request using Req
    {:ok, response} = Req.get("http://localhost:8081/health")

    # Validate response matches spec
    assert response.status == 200
    # Add schema validation here
  end
end
```

## Test Organization

```
apps/user_svc/
├── test/
│   ├── unit/              # Unit tests (fast, no deps)
│   │   ├── clients/
│   │   └── controllers/
│   ├── integration/       # Integration tests (require services)
│   │   └── email_flow_test.exs
│   ├── contract/          # OpenAPI contract tests
│   │   └── openapi_test.exs
│   └── test_helper.exs
```

## Running Tests

### All Tests
```bash
./dev.sh test              # All services
./dev.sh test user_svc     # Single service
```

### By Tag
```elixir
# Tag tests
@tag :integration
@tag :slow
@tag :contract

# Run specific tags
mix test --only integration
mix test --exclude slow
```

### Watch Mode
```bash
# Install mix-test.watch
mix archive.install hex mix_test_watch

# Run in watch mode
mix test.watch
```

### With Coverage
```bash
mix test --cover
open cover/excoveralls.html
```

## Mocking External Services

For unit tests, mock external HTTP calls:

```elixir
# Use Mox for mocking
defmodule JobService.Clients.EmailSvcClientMock do
  @behaviour JobService.Clients.EmailSvcClient

  def send_email(_args) do
    {:ok, %{status: 200, body: "mocked"}}
  end
end

# In test
setup do
  # Configure to use mock
  Application.put_env(:job_svc, :email_client, EmailSvcClientMock)

  on_exit(fn ->
    # Restore real client
    Application.put_env(:job_svc, :email_client, EmailSvcClient)
  end)
end
```

## Testing Workers (Oban)

Test Oban workers directly without enqueueing:

```elixir
test "EmailWorker processes welcome email" do
  args = %{
    "id" => "1",
    "name" => "Test",
    "email" => "test@example.com",
    "type" => "welcome"
  }

  # Mock the HTTP client
  # ...

  # Call worker directly
  assert :ok = EmailWorker.perform(%Oban.Job{args: args})
end
```

## Testing with Database

For services with Ecto (user_svc, job_svc):

```elixir
# Use sandbox mode
setup do
  :ok = Ecto.Adapters.SQL.Sandbox.checkout(JobService.Repo)
end

test "creates job in database" do
  job = insert(:job)
  assert JobService.Repo.get(Job, job.id)
end
```

## Common Test Patterns

### Testing Protobuf Serialization
```elixir
test "encodes and decodes protobuf message" do
  original = %Mcsv.EmailRequest{
    user_id: "1",
    user_name: "Test",
    user_email: "test@example.com",
    email_type: "welcome"
  }

  encoded = Mcsv.EmailRequest.encode(original)
  decoded = Mcsv.EmailRequest.decode(encoded)

  assert decoded.user_id == original.user_id
end
```

### Testing OpenTelemetry Tracing
```elixir
test "propagates trace context" do
  # Start a span
  :otel_tracer.start_span("test_span")

  # Make request
  {:ok, response} = Client.create(1)

  # Verify trace headers were sent
  assert response.request_headers["traceparent"]
end
```

## Test Data Fixtures

Create test helpers for consistent data:

```elixir
# test/support/fixtures.ex
defmodule TestFixtures do
  def user_attrs(overrides \\ %{}) do
    Map.merge(%{
      "id" => "test-#{System.unique_integer()}",
      "name" => "Test User",
      "email" => "test@example.com",
      "bio" => "Test bio"
    }, overrides)
  end

  def email_job_args(user) do
    Map.merge(user, %{"type" => "welcome"})
  end
end
```

Usage:
```elixir
test "creates user with custom email" do
  attrs = user_attrs(%{"email" => "custom@example.com"})
  {:ok, response} = Client.create_user(attrs)
  assert response.body["email"] == "custom@example.com"
end
```

## Performance Testing

### Benchmarking
```elixir
# Use Benchee
defmodule PerformanceTest do
  use ExUnit.Case

  test "benchmark protobuf encoding" do
    request = %Mcsv.EmailRequest{...}

    Benchee.run(%{
      "encode" => fn -> Mcsv.EmailRequest.encode(request) end,
      "decode" => fn -> Mcsv.EmailRequest.decode(encoded) end
    })
  end
end
```

### Load Testing
```bash
# Use k6 for HTTP load testing
k6 run test/load/user_creation.js
```

## Debugging Tests

### IEx in Tests
```bash
# Run single test with IEx
iex -S mix test test/email_worker_test.exs
```

### Debug Output
```elixir
test "debug example" do
  result = some_function()
  IO.inspect(result, label: "DEBUG")
  assert result == expected
end
```

### Async vs Sync
```elixir
# Run tests in parallel (default)
use ExUnit.Case, async: true

# Run tests synchronously (for shared resources)
use ExUnit.Case, async: false
```

## Continuous Testing

### Git Hooks
```bash
# .git/hooks/pre-commit
#!/bin/bash
mix format --check-formatted
mix test --exclude integration
```

### GitHub Actions
```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
      - run: mix deps.get
      - run: mix test
```

## Next Steps

1. Add OpenAPI validation library: `open_api_spex`
2. Set up ExCoveralls for coverage reports
3. Create integration test suite
4. Add property-based testing with StreamData
