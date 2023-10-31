defmodule BoilerPlateWeb.PageController do
  use BoilerPlateWeb, :controller
  require Logger

  def index(conn, _params) do
    redirect(conn, to: "/login")
  end

  def pricing(conn, _params) do
    redirect(conn, to: "/")
  end

  def termsofservice(conn, _params) do
    render(conn, "terms.html")
  end
end
