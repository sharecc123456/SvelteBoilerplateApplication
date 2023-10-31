alias BoilerPlate.User

defmodule BoilerPlate.Guardian.Ensure2FA do
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
    |> apply(:auth_error, [conn, {:two_factor_auth_failure, reason}, opts])
    |> Plug.Conn.halt()
  end

  defp need_2fa?(user, conn) do
    claims = Guardian.Plug.current_claims(conn)
    tfa = claims["two_factor_approved"] || false

    cond do
      FunWithFlags.enabled?(:two_factor_auth) == false ->
        false

      User.two_factor_state?(user) != :setup and User.two_factor_state?(user) != :app_setup ->
        false

      not tfa ->
        true

      true ->
        false
    end
  end

  defp verify(nil, conn, opts) do
    {{:error, :no_user}, conn, opts}
  end

  defp verify(user, conn, opts) do
    if need_2fa?(user, conn) do
      {{:error, user}, conn, opts}
    else
      {:ok, conn, opts}
    end
  end
end
