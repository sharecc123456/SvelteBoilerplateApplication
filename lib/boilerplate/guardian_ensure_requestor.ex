defmodule BoilerPlate.Guardian.EnsureRequestorAccess do
  def init(opts), do: opts

  def call(conn, opts) do
    conn
    |> Guardian.Plug.current_resource()
    |> verify(conn, opts)
    |> respond()
  end

  defp respond({:ok, conn, _opts}), do: conn

  defp respond({{:error, reason}, conn, opts}) do
    conn
    |> Guardian.Plug.Pipeline.fetch_error_handler!(opts)
    |> apply(:auth_error, [conn, {:not_a_requestor, reason}, opts])
    |> Plug.Conn.halt()
  end

  defp valid_requestor?(_user, conn) do
    claims = Guardian.Plug.current_claims(conn)

    claims["blptreq"] || false
  end

  defp verify(nil, conn, opts) do
    {{:error, :no_user}, conn, opts}
  end

  defp verify(user, conn, opts) do
    if valid_requestor?(user, conn) do
      {:ok, conn, opts}
    else
      {{:error, user}, conn, opts}
    end
  end
end
