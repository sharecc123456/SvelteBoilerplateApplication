defmodule BoilerPlateWeb.CompanyIntegrationView do
  use BoilerPlateWeb, :view

  def render("company_integration.json", %{company_integration: ci}) do
    %{
      type: ci.type
    }
  end

  def render("storage_provider.json", %{storage_provider: sp}) do
    %{
      type: sp.backend,
      auto_export: sp.auto_export,
      path_template: sp.path_template
    }
  end
end
