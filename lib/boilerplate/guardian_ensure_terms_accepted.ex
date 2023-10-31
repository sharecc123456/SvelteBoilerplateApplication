defmodule BoilerPlate.Guardian.EnsureTermsAccepted do
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
    |> apply(:auth_error, [conn, {:terms_notaccepted, reason}, opts])
    |> Plug.Conn.halt()
  end

  defp verify(nil, conn, opts) do
    {{:error, :no_user}, conn, opts}
  end

  defp verify(user, conn, opts) do
    if user.terms_accepted do
      {:ok, conn, opts}
    else
      {{:error, :terms_notaccepted}, conn, opts}
    end
  end
end
