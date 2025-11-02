defmodule EmailRouter do
    use Plug.Router

  plug(:match)
  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    pass: ["application/protobuf"]  # Skip parsing protobuf, let us handle it manually
  )
  plug(:dispatch)

  # RPC-style protobuf endpoints (matches services.proto)

  # EmailService.SendEmail - Send email via SMTP
  post "/email_svc/SendEmail" do
    DeliveryController.send(conn)
  end
end
