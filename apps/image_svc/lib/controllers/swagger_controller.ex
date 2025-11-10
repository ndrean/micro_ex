defmodule SwaggerController do
  @moduledoc """
  Swagger UI endpoint for interactive API documentation.
  """

  use ImageSvcWeb, :controller

  def ui(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Image Service API</title>
      <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script>
        SwaggerUIBundle({
          url: '/api/openapi',
          dom_id: '#swagger-ui',
          deepLinking: true,
          presets: [
            SwaggerUIBundle.presets.apis,
            SwaggerUIBundle.SwaggerUIStandalonePreset
          ]
        })
      </script>
    </body>
    </html>
    """)
  end
end
