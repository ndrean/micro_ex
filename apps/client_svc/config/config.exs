# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :client_svc,
  port: 4000,
  user_svc_base_url: "http://localhost:8081",
  user_endpoints: %{
    create: "/user_svc/CreateUser",
    convert_image: "/user_svc/ConvertImage"
  }

config :logger, :default_handler,
  formatter:
    {LoggerJSON.Formatters.Basic,
     metadata: [
       :request_id,
       :service,
       :trace_id,
       :span_id,
       :user_id,
       :duration
     ]}

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]

import_config "#{config_env()}.exs"
