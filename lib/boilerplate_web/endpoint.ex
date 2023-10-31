defmodule BoilerPlateWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :boilerplate

  socket "/socket", BoilerPlateWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :boilerplate,
    gzip: false,
    only:
      ~w(css fonts images js .well-known favicon.ico robots.txt android-icon-144x144.png android-icon-192x192.png android-icon-36x36.png android-icon-48x48.png android-icon-72x72.png android-icon-96x96.png apple-icon-114x114.png apple-icon-120x120.png apple-icon-144x144.png apple-icon-152x152.png apple-icon-180x180.png apple-icon-57x57.png apple-icon-60x60.png apple-icon-72x72.png apple-icon-76x76.png apple-icon-precomposed.png apple-icon.png browserconfig.xml favicon-16x16.png favicon-32x32.png favicon-96x96.png favicon.ico manifest.json ms-icon-144x144.png ms-icon-150x150.png ms-icon-310x310.png ms-icon-70x70.png)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library(),
    length: 100_000_000

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_boilerplate_key",
    signing_salt: "82pMxIL7"

  plug RemoteIp
  plug BoilerPlateWeb.Router
end
