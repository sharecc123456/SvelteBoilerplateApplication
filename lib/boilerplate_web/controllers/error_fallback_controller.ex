defmodule BoilerPlateWeb.ErrorFallbackController do
  use BoilerPlateWeb, :controller
  require Logger

  def call(conn, _params) do
    Logger.info "CRASHED!"

    text conn, "Bye"
  end

end
