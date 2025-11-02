defmodule JobRouter do
  use Plug.Router

  plug(:match)

  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    # Skip parsing protobuf, let us handle it manually
    pass: ["application/protobuf"]
  )

  plug(:dispatch)

  # RPC-style protobuf endpoints (matches services.proto)

  # JobService.EnqueueEmail - Enqueue email job in Oban
  post "/job_svc/EnqueueEmail" do
    EmailSenderController.enqueue(conn)
  end

  # JobService.NotifyEmailDelivery - Receive delivery status from email_svc
  post "/job_svc/NotifyEmailDelivery" do
    EmailNotificationController.notify(conn)
  end

  # JobService.ConvertImage - Enqueue image conversion job
  post "/job_svc/ConvertImage" do
    ImageController.convert(conn)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
