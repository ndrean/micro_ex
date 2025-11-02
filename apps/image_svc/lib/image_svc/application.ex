defmodule ImageSvc.Application do
  @moduledoc """
  Image Service Application

  Responsible for image processing operations (PNG to PDF conversion, etc.)
  Receives requests via HTTP and processes them using ImageMagick.
  """

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:image_svc, :port, 8084)
    IO.puts("Starting image_svc on port #{port}")

    children = [
      {Bandit, plug: ImageSvc.Router, port: port}
    ]

    opts = [strategy: :one_for_one, name: ImageSvc.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
