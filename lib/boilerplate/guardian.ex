alias BoilerPlate.Repo
alias BoilerPlate.User

defmodule BoilerPlate.Guardian do
  use Guardian, otp_app: :boilerplate

  def subject_for_token(resource, _claim) do
    if resource == nil do
      {:error, :invalid_access_code}
    else
      sub = to_string(resource.id)
      {:ok, sub}
    end
  end

  def resource_from_claims(claims) do
    id = claims["sub"]
    Logger.metadata(user_id: id)
    resource = Repo.get(User, id)
    {:ok, resource}
  end
end
