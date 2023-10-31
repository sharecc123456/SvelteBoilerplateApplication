defmodule BoilerPlate.Guardian.EnsureInternalOnly do
  def instance_admins do
    [
      "lk@cetlie.hu",
      "lev@boilerplate.co",
      "brian@boilerplate.co",
      "bmagrann@gmail.com",
      "basic1@cetlie.hu",
      "tripp@boilerplate.co",
      "rishi@boilerplate.co",
      "saiful@boilerplate.co",
      "umair@boilerplate.co",
      "prem@boilerplate.co",
      "nandi@boilerplate.co"
    ]
  end

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
    |> apply(:auth_error, [conn, {:not_internal, reason}, opts])
    |> Plug.Conn.halt()
  end

  defp verify(nil, conn, opts) do
    {{:error, :no_user}, conn, opts}
  end

  defp verify(user, conn, opts) do
    if user.email in instance_admins() do
      {:ok, conn, opts}
    else
      {{:error, :not_internal}, conn, opts}
    end
  end
end
