import Config

# Configure your database
config :boilerplate, BoilerPlate.Repo,
  username: "postgres",
  password: "postgres",
  database: "boilerplate_test#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :boilerplate, BoilerPlate.Guardian,
  issuer: "boilerplate",
  secret_key: "ZJaL9G9ZojkPKZHcRKAo+5lLPoEG4I4uq48hY/8ZV74/JdjhU/x/M7EwhgSytVUI"

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :boilerplate, BoilerPlateWeb.Endpoint,
  http: [port: 4002],
  secret_key_base: "EOajKBnCo0sk2WeJCrrak7D511p2M+qiIkXxjbTVwCkdwHxEQ9lbkqq1P78sQl+B",
  server: false

# Print only warnings and errors during test
config :logger, level: :info

config :boilerplate,
  version: "boilerplate-test",
  storage_backend: StorageLocalImpl,
  boilerplate_environment: :test,
  iac_python_runcmd: "python3",
  iac_python_runcmd_wrapper: &"nix-shell --run \"#{&1}\"",
  boilerplate_domain: "http://localtet.boilerplate.co"

config :arc,
  storage: Arc.Storage.Local

if System.get_env("GITHUB_ACTIONS") do
  config :boilerplate,
    iac_python_runcmd_wrapper: &"#{&1}"
end
