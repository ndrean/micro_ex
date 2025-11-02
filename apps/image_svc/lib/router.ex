defmodule ImageSvc.Router do
  use Plug.Router
  require Logger

  plug(:match)
  plug(Plug.Parsers,
    parsers: [:json],
    json_decoder: Jason,
    pass: ["application/protobuf"]
  )
  plug(:dispatch)

  # RPC-style protobuf endpoint
  # ImageService.ConvertImage - Convert image to PDF
  post "/image_svc/ConvertImage" do
    ImageSvc.ConversionController.convert(conn)
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
