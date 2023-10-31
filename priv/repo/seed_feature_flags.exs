defmodule BoilerPlate.FeatureFlagsSeed do
  def run() do
    FunWithFlags.disable(:email_sending)

    FunWithFlags.enable(:two_factor_auth)
    FunWithFlags.enable(:new_ui)
    FunWithFlags.enable(:internal_development)
    FunWithFlags.enable(:requestor_allow_checklist_edit)
    FunWithFlags.enable(:requestor_allow_checklist_creation)
    FunWithFlags.enable(:requestor_allow_template_edit)
    FunWithFlags.enable(:requestor_allow_template_creation)
    FunWithFlags.enable(:requestor_review_all)
    FunWithFlags.enable(:retention_testing)
    FunWithFlags.enable(:audit_trail_v2)
    FunWithFlags.enable(:d2d_form_generation)
  end
end

BoilerPlate.FeatureFlagsSeed.run()
