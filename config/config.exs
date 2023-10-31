# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :boilerplate, ecto_repos: [BoilerPlate.Repo]

# Configures the endpoint
# Configures Elixir's Logger
# Application Configuration
# Moved to config/runtime.exs

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
#
import_config "#{Mix.env()}.exs"
