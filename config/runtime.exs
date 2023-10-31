import Config

if config_env() != :test do
  # Stuff
  stripe_secret_key = System.get_env("STRIPE_SECRET_KEY") || "stripe_secret_key_not_supplied"
  stripe_public_key = System.get_env("STRIPE_PUBLIC_KEY") || "stripe_public_key_not_supplied"
  boilerplate_domain = System.get_env("BOILERPLATE_DOMAIN") || "https://localhost"
  twilio_service = System.get_env("TWILIO_SERVICE") || "twilio_service_not_supplied"
  twilio_account_sid = System.get_env("TWILIO_ACCOUNT_SID") || "twilio_account_sid_not_supplied"
  twilio_auth_token = System.get_env("TWILIO_AUTH_TOKEN") || "twilio_auth_token_not_supplied"
  s3_access_key = System.get_env("S3_ACCESS_KEY") || "s3_access_key_not_supplied"
  s3_secret_key = System.get_env("S3_SECRET_KEY") || "s3_secret_key_not_supplied"
  iac_python_runcmd = System.get_env("IAC_PYTHON_RUNCMD") || "/usr/local/bin/python3 -mpoetry run"
  iac_node_runcmd = System.get_env("IAC_NODE_RUNCMD") || "/Users/lkurusa/.volta/bin/node"
  iac_pdftk_runcmd = System.get_env("IAC_PDFTK_RUNCMD") || "pdftk"
  iac_convert_image_runcmd = System.get_env("IAC_CONVERT_IMAGE_RUNCMD") || "convert"
  iac_merge_files = System.get_env("IAC_MERGE_FILES") || "convert"
  use_reverse_proxy = System.get_env("DISABLE_HTTPS") == "1" || false

  s3_bucket = System.get_env("S3_BUCKET") || "bp-aws-docs-dev"

  hcaptcha_public_key =
    System.get_env("HCAPTCHA_PUBLIC_KEY") || "hcaptcha_public_key_not_supplied"

  hcaptcha_private_key =
    System.get_env("HCAPTCHA_PRIVATE_KEY") || "hcaptcha_private_key_not_supplied"

  iac_profile = System.get_env("BOILERPLATE_IAC_PROFILE") || "SANDBOX"

  database_url =
    System.get_env("DATABASE_URL") || "ecto://postgres:postgres@localhost/boilerplate_dev"

  secret_key_base = System.get_env("SECRET_KEY_BASE") || "abc"

  doppler_env = System.get_env("DOPPLER_CONFIG") || "unknown"
  totp_secret = System.get_env("TOTP_IMPERSONATE_SECRET") || "unknown"

  # Runner
  boilerplate_environment = System.get_env("BOILERPLATE_ENV") || "dev"
  rollbar_environment = System.get_env("ROLLBAR_ENV") || "dev"
  boilerplate_hostname = System.get_env("BOILERPLATE_HOSTNAME") || "app.boilerplate.co"
  http_port = String.to_integer(System.get_env("HTTP_PORT") || "4000")
  https_port = String.to_integer(System.get_env("HTTPS_PORT") || "5000")
  redis_host = System.get_env("REDIS_HOST") || "localhost"
  redis_port = String.to_integer(System.get_env("REDIS_PORT") || "6379")
  is_prod = boilerplate_environment == "prod"
  rollbar_enabled = is_prod
  fullstory_enabled = System.get_env("FULLSTORY_ENABLED") == "1"

  logger_level =
    if System.get_env("SHOW_SQL_QUERIES") == "1" do
      :debug
    else
      :info
    end

  # SSL
  ssl_keyfile = System.get_env("BOILERPLATE_SSL_KEY_PATH") || "priv/cert/selfsigned_key.pem"
  ssl_cacertfile = System.get_env("BOILERPLATE_SSL_CACERT_PATH") || ""
  ssl_certfile = System.get_env("BOILERPLATE_SSL_CERT_PATH") || "priv/cert/selfsigned.pem"

  ssl_ca =
    System.get_env("ROOT_CA_LOCATION") ||
      "/usr/local/share/ca-certificates/Boilerplate-RootCA.crt"

  # Database
  config :boilerplate,
    namespace: BoilerPlate,
    version: "boilerplate-42",
    ecto_repos: [BoilerPlate.Repo]

  config :boilerplate, BoilerPlate.Repo,
    url: database_url,
    show_sensitive_data_on_connection_error: true,
    start_apps_before_migration: [:logger],
    pool_size: 10

  config :ex_aws,
    access_key_id: s3_access_key,
    secret_access_key: s3_secret_key,
    region: "us-east-2"

  config :boilerplate,
    stripe_secret_key: stripe_secret_key,
    stripe_public_key: stripe_public_key,
    boilerplate_domain: boilerplate_domain,
    boilerplate_environment: boilerplate_environment,
    rollbar_environment: rollbar_environment,
    twilio_service: twilio_service,
    twilio_account_sid: twilio_account_sid,
    twilio_auth_token: twilio_auth_token,
    s3_bucket: s3_bucket,
    stripe_enabled: :new,
    redmine_enabled: true,
    iac_profile: iac_profile,
    doppler_env: doppler_env,
    boilerplate_hostname: boilerplate_hostname,
    segment_write_key: "yB6Dq8fmWhIjLa9HnsX0CMKRfLobkOZV",
    iac_python_runcmd: iac_python_runcmd,
    iac_node_runcmd: iac_node_runcmd,
    iac_pdftk_runcmd: iac_pdftk_runcmd,
    iac_convert_image_runcmd: iac_convert_image_runcmd,
    iac_merge_files: iac_merge_files,
    totp_impersonate_secret: totp_secret,
    ssl_ca: ssl_ca,
    rollbar_enabled: rollbar_enabled,
    fullstory_enabled: fullstory_enabled,
    redis_host: redis_host,
    redis_port: redis_port,
    storage_backend: StorageAwsImpl

  config :stripity_stripe,
    api_key: stripe_secret_key

  config :hcaptcha,
    public_key: hcaptcha_public_key,
    secret: hcaptcha_private_key

  https_config =
    cond do
      use_reverse_proxy ->
        false

      ssl_cacertfile != "" ->
        [
          port: https_port,
          otp_app: :boilerplate,
          cipher_suite: :strong,
          keyfile: ssl_keyfile,
          cacertfile: ssl_cacertfile,
          certfile: ssl_certfile
        ]

      True ->
        [
          port: https_port,
          otp_app: :boilerplate,
          cipher_suite: :strong,
          keyfile: ssl_keyfile,
          certfile: ssl_certfile
        ]
    end

  config :boilerplate, BoilerPlateWeb.Endpoint,
    url: [host: boilerplate_hostname],
    http: [port: http_port],
    https: https_config,
    debug_errors: true,
    check_origin: is_prod,
    render_errors: [view: BoilerPlateWeb.ErrorView, accepts: ~w(html json)],
    secret_key_base: secret_key_base,
    pubsub_server: BoilerPlate.PubSub,
    server: true

  if is_prod do
    config :boilerplate, BoilerPlateWeb.Endpoint,
      cache_static_manifest: "priv/static/cache_manifest.json"
  end

  config :logger, :console,
    format: "$time $metadata[$level] $message\n",
    level: logger_level,
    metadata: [:request_id, :user_id]

  # Use Jason for JSON parsing in Phoenix
  config :phoenix, :json_library, Jason

  config :arc,
    storage: Arc.Storage.S3,
    bucket: "bp-aws-docs"

  config :boilerplate, BoilerPlate.Guardian,
    issuer: "boilerplate",
    secret_key: "uq4k7zvlwMb9KI7KUCzZ2MtnomLuKuyk4NjHreX91niQHqroP0AcStaqXpSETE/e"

  # Configure Email delivery via Bamboo via Mailgun
  config :boilerplate, BoilerPlate.Mailer,
    adapter: Bamboo.MailgunAdapter,
    api_key: "2d03374de931869bbc28e47740c21d93-73ae490d-ecfa8da2",
    domain: "mg.boilerplate.co",
    base_uri: "https://api.mailgun.net/v3"

  config :segment,
    sender_impl: Segment.Analytics.Batcher

  config :fun_with_flags, :cache,
    enabled: true,
    ttl: 900

  config :fun_with_flags, :persistence, adapter: FunWithFlags.Store.Persistent.Redis

  config :fun_with_flags, :cache_bust_notifications,
    enabled: true,
    adapter: FunWithFlags.Notifications.Redis

  config :fun_with_flags, :redis,
    host: redis_host,
    port: redis_port,
    database: 0

  config :boilerplate, BoilerPlate.QuantumScheduler,
    jobs: [
      [
        name: :auto_submission_pending_requests,
        schedule: "*/30 * * * * *",
        task: {BoilerplateCronjobs.RequestSubmission, :work, []}
      ],
      [
        name: :weekly_digest,
        schedule: "0 22 * * 0",
        task: {BoilerPlate.WeeklyStatusChecker, :call_from_cron, []}
      ]
    ]

  config :oauth2, debug: true
end
