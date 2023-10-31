defmodule BoilerPlateWeb.Helpers do
  import Ecto.Query

  @moduledoc """
    This is a helper function
  """

  def get_supported_image_type(), do: [".png", ".gif", ".jpg", ".jpeg", ".hevc", ".heic", ".heif"]

  def get_mergerable_file_types() do
    get_supported_image_type() ++ [".pdf"]
  end

  @doc """
    Checks the claims in Plug.Conn and figures out the current recipient
  """
  def get_current_recipient(conn) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)

    if us_user == nil do
      nil
    else
      query =
        from r in BoilerPlate.Recipient,
          where: r.status == 0 and r.user_id == ^us_user.id,
          select: r

      count = BoilerPlate.Repo.aggregate(query, :count, :id)

      cond do
        count == 0 ->
          nil

        count == 1 ->
          BoilerPlate.Repo.one(query)

        count > 1 ->
          claims = BoilerPlate.Guardian.Plug.current_claims(conn)
          recipient_id = claims["recipient_id"]

          if recipient_id == nil do
            nil
          else
            BoilerPlate.Repo.get(BoilerPlate.Recipient, recipient_id)
          end
      end
    end
  end

  @doc """
    Checks the claims in Plug.Conn and figures out the current requestor
  """
  def get_current_requestor(conn, opts \\ []) do
    us_user = BoilerPlate.Guardian.Plug.current_resource(conn)
    defaults = [as: :requestor]
    %{as: as_what} = Keyword.merge(defaults, opts) |> Enum.into(%{})

    requestor =
      if us_user == nil do
        nil
      else
        query =
          from r in BoilerPlate.Requestor,
            where: r.status == 0 and r.user_id == ^us_user.id,
            select: r

        count = BoilerPlate.Repo.aggregate(query, :count, :id)

        cond do
          count == 0 ->
            nil

          count == 1 ->
            BoilerPlate.Repo.one(query)

          count > 1 ->
            claims = BoilerPlate.Guardian.Plug.current_claims(conn)
            requestor_id = claims["requestor_id"]

            if requestor_id == nil do
              nil
            else
              BoilerPlate.Repo.get(BoilerPlate.Requestor, requestor_id)
            end
        end
      end

    if requestor != nil do
      case as_what do
        :requestor ->
          requestor

        :company ->
          BoilerPlate.Repo.get(BoilerPlate.Company, requestor.company_id)

        _ ->
          raise ArgumentError, message: "Invalid as_what passed to get_current_requestor/2"
      end
    else
      nil
    end
  end
end
