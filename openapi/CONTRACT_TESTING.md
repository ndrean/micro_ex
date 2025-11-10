# OpenAPI Contract Testing

Automated testing to ensure your services match their OpenAPI specifications.

## Overview

Contract testing validates that:
1. **Requests** sent by clients match the OpenAPI spec
2. **Responses** from servers match the OpenAPI spec
3. **Breaking changes** are caught before deployment

## Quick Start

### 1. Validate All Specs
```bash
cd openapi
make validate
```

### 2. Install Testing Tools

Add to your service's `mix.exs`:
```elixir
defp deps do
  [
    # OpenAPI validation
    {:open_api_spex, "~> 3.18"},
    {:yaml_elixir, "~> 2.9"},

    # HTTP client (already in your project)
    {:req, "~> 0.5"},

    # HTTP testing
    {:bypass, "~> 2.1", only: :test}
  ]
end
```

## Testing Approach

### Option 1: Runtime Validation (Recommended)

Add OpenAPI validation to your router:

```elixir
# lib/router.ex
defmodule UserRouter do
  use Plug.Router
  use OpenApiSpex.Plug

  # Load OpenAPI spec
  plug OpenApiSpex.Plug.PutApiSpec,
    module: UserService.OpenAPISpec

  # Validate requests/responses
  plug OpenApiSpex.Plug.CastAndValidate

  # Your routes
  post "/user_svc/CreateUser" do
    UserController.create(conn)
  end
end

# lib/openapi_spec.ex
defmodule UserService.OpenAPISpec do
  alias OpenApiSpex.{OpenApi, Info, Server, Paths}

  def spec do
    %OpenApi{
      info: %Info{
        title: "User Service API",
        version: "1.0.0"
      },
      servers: [
        %Server{url: "http://localhost:8081"}
      ],
      paths: Paths.from_router(UserRouter)
    }
  end
end
```

### Option 2: Test-Time Validation

Validate against YAML specs in tests:

```elixir
# test/contract/openapi_contract_test.exs
defmodule Contract.OpenAPIContractTest do
  use ExUnit.Case
  alias OpenApiSpex.OpenApi

  @spec_file "../../openapi/user_svc.yaml"

  setup_all do
    # Load and parse OpenAPI spec
    {:ok, spec_map} = YamlElixir.read_from_file(@spec_file)
    spec = OpenApi.Decode.decode(spec_map)

    {:ok, spec: spec}
  end

  describe "POST /user_svc/CreateUser" do
    test "request matches OpenAPI spec", %{spec: spec} do
      # Create request body
      request_body = %{
        "user_id" => "1",
        "name" => "Test User",
        "email" => "test@example.com"
      }

      # Validate against spec
      operation = get_operation(spec, "/user_svc/CreateUser", :post)
      assert valid_request?(operation, request_body)
    end

    test "response matches OpenAPI spec", %{spec: spec} do
      # Make actual request using Req
      {:ok, response} = Req.post(
        "http://localhost:8081/user_svc/CreateUser",
        body: encode_protobuf(request),
        headers: [{"content-type", "application/x-protobuf"}]
      )

      # Validate response
      operation = get_operation(spec, "/user_svc/CreateUser", :post)
      assert valid_response?(operation, response, 200)
    end
  end

  # Helper functions
  defp get_operation(spec, path, method) do
    spec.paths[path][method]
  end

  defp valid_request?(operation, body) do
    # Implement validation logic
    true
  end

  defp valid_response?(operation, response, status_code) do
    # Implement validation logic
    response.status == status_code
  end
end
```

### Option 3: CLI Validation

Use openapi-generator CLI for validation:

```bash
# Validate request/response examples in spec
openapi-generator validate -i user_svc.yaml

# Generate validators
openapi-generator generate \
  -i user_svc.yaml \
  -g openapi-yaml-unresolved \
  -o validated/
```

## Integration Test Pattern

```elixir
# test/integration/contract_test.exs
defmodule Integration.ContractTest do
  use ExUnit.Case

  @moduletag :integration

  setup_all do
    # Ensure services are running
    ensure_services_running()
    :ok
  end

  test "end-to-end user creation flow matches contracts" do
    # 1. Create user (user_svc contract)
    user_request = build_user_request()
    {:ok, user_response} = call_user_svc(user_request)

    validate_against_spec("user_svc", "/user_svc/CreateUser", :post,
      request: user_request,
      response: user_response
    )

    # 2. Email job enqueued (job_svc contract)
    email_job = build_email_job(user_response)
    {:ok, job_response} = call_job_svc(email_job)

    validate_against_spec("job_svc", "/job_svc/EnqueueEmail", :post,
      request: email_job,
      response: job_response
    )

    # 3. Email sent (email_svc contract)
    # Wait for async job
    :timer.sleep(2000)

    # Verify contract compliance throughout
    assert_no_contract_violations()
  end

  defp validate_against_spec(service, path, method, opts) do
    spec = load_spec("openapi/#{service}.yaml")
    operation = get_operation(spec, path, method)

    if opts[:request] do
      assert request_matches_spec?(operation, opts[:request])
    end

    if opts[:response] do
      assert response_matches_spec?(operation, opts[:response])
    end
  end
end
```

## Continuous Validation

### Pre-Commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Validating OpenAPI specs..."
cd openapi && make validate

if [ $? -ne 0 ]; then
  echo "❌ OpenAPI validation failed"
  exit 1
fi

echo "✅ OpenAPI specs valid"
```

### CI/CD Pipeline

```yaml
# .github/workflows/contract-tests.yml
name: Contract Tests

on: [push, pull_request]

jobs:
  validate-specs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Validate OpenAPI Specs
        run: |
          cd openapi
          make validate

  contract-tests:
    runs-on: ubuntu-latest
    needs: validate-specs
    steps:
      - uses: actions/checkout@v2

      - name: Start Infrastructure
        run: docker compose up -d

      - name: Run Contract Tests
        run: |
          ./dev.sh compile
          ./dev.sh test --only contract
```

## Spec-Driven Development

### 1. Design API First
Write OpenAPI spec before code:

```yaml
# openapi/new_feature.yaml
paths:
  /user_svc/UpdateProfile:
    put:
      summary: Update user profile
      requestBody:
        content:
          application/x-protobuf:
            schema:
              $ref: '#/components/schemas/UpdateProfileRequest'
      responses:
        '200':
          description: Profile updated
```

### 2. Generate Tests
```bash
# Generate test stubs from spec
make generate-tests
```

### 3. Implement Feature
Write code to pass the contract tests.

### 4. Validate
```bash
# Ensure implementation matches spec
mix test test/contract/
```

## Breaking Change Detection

Compare specs before deployment:

```bash
#!/bin/bash
# scripts/check-breaking-changes.sh

# Compare current spec with main branch
git show main:openapi/user_svc.yaml > /tmp/old-spec.yaml

# Use openapi-diff
docker run --rm -v $(pwd):/specs \
  openapitools/openapi-diff:latest \
  /specs/openapi/user_svc.yaml \
  /tmp/old-spec.yaml

if [ $? -ne 0 ]; then
  echo "⚠️  Breaking changes detected!"
  exit 1
fi
```

## Best Practices

1. **Keep Specs Updated**: Update OpenAPI spec when changing APIs
2. **Version Your APIs**: Use semantic versioning in specs
3. **Test Examples**: Add request/response examples to specs
4. **Automate Validation**: Run in CI/CD pipeline
5. **Share Specs**: Use specs as documentation for consumers

## Tools & Libraries

### Elixir
- `open_api_spex` - OpenAPI validation in Elixir
- `ex_json_schema` - JSON Schema validation

### CLI Tools
- `openapi-generator-cli` - Generate clients/validators
- `spectral` - Advanced linting
- `swagger-cli` - Validation and bundling

### Online Tools
- Swagger Editor: https://editor.swagger.io
- Stoplight Studio: https://stoplight.io/studio

## Example: Full Contract Test

```elixir
defmodule FullContractTest do
  use ExUnit.Case

  @tag :contract
  test "complete workflow respects all contracts" do
    # Load all specs
    specs = %{
      user_svc: load_spec("user_svc.yaml"),
      job_svc: load_spec("job_svc.yaml"),
      email_svc: load_spec("email_svc.yaml")
    }

    # Step 1: User creation
    user_req = build_user_request()
    assert request_valid?(specs.user_svc, "/user_svc/CreateUser", :post, user_req)

    {:ok, user_resp} = Req.post("http://localhost:8081/user_svc/CreateUser", ...)
    assert response_valid?(specs.user_svc, "/user_svc/CreateUser", :post, user_resp)

    # Step 2: Email job
    email_req = extract_email_data(user_resp)
    assert request_valid?(specs.job_svc, "/job_svc/EnqueueEmail", :post, email_req)

    {:ok, job_resp} = Req.post("http://localhost:8082/job_svc/EnqueueEmail", ...)
    assert response_valid?(specs.job_svc, "/job_svc/EnqueueEmail", :post, job_resp)

    # Step 3: Email delivery
    :timer.sleep(2000) # Wait for async processing

    # Verify all steps followed contracts
    assert workflow_contract_compliant?(trace_id)
  end
end
```

## Troubleshooting

### Spec Validation Fails
```bash
# Get detailed validation errors
cd openapi
docker run --rm -v $(pwd):/local \
  openapitools/openapi-generator-cli validate \
  -i /local/user_svc.yaml \
  --recommend
```

### Request/Response Mismatch
- Check content-type headers
- Verify protobuf encoding
- Compare actual vs expected with `IO.inspect`

### Performance
- Cache loaded specs in test setup
- Use async tests when possible
- Mock external services for unit tests
