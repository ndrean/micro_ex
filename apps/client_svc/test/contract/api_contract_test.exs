defmodule UserService.Contract.APIContractTest do
  use ExUnit.Case

  @moduletag :contract
  @spec_path "../../openapi/user_svc.yaml"

  setup_all do
    # Load OpenAPI spec once for all tests
    {:ok, spec} = YamlElixir.read_from_file(@spec_path)
    {:ok, spec: spec}
  end

  test "POST /user_svc/CreateUser works as documented", %{spec: spec} do
    # Build protobuf request
    request = %Mcsv.UserRequest{
      id: "1",
      name: "PB User 1",
      email: "pbuser1@example.com",
      type: :EMAIL_TYPE_WELCOME
    }

    request_binary = Mcsv.UserRequest.encode(request)

    # Make request
    {:ok, response} =
      Req.post(
        "http://localhost:8081/user_svc/CreateUser",
        body: request_binary,
        headers: [{"content-type", "application/x-protobuf"}]
      )

    # Validate against OpenAPI spec
    assert response.status == 200, "Expected 200 OK as per OpenAPI spec"

    dbg(spec["paths"])

    path_spec = spec["paths"]["/user_svc/CreateUser"]
    expected_status = path_spec["post"]["responses"]["200"] |> dbg()

    response_data = Mcsv.UserResponse.decode(response.body)
    %Mcsv.UserResponse{} = response_data

    assert response_data.ok == true

    assert response.status == 200

    schema = expected_status["content"]["application/x-protobuf"]["schema"]
    required_fields = schema["required"] || []
  end

  test "GET /health returns 200", %{spec: spec} do
    {:ok, response} = Req.get("http://localhost:8081/health")

    # Verify matches OpenAPI spec
    assert response.status == 200
    assert response.body == "OK"
  end
end
