defmodule BoilerPlateWeb.UserSSOView do
  use BoilerPlateWeb, :view

  def render("user_sso.json", %{user_sso: sso}) do
    %{
      type: sso.type
    }
  end
end
