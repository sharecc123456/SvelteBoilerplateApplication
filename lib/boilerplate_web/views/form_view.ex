defmodule BoilerPlateWeb.FormView do
  use BoilerPlateWeb, :view

  def render("form_field.json", %{form_field: ff}) do
    %{
      id: ff.id,
      title: ff.title,
      label: ff.label,
      description: ff.description,
      type: ff.type,
      is_multiple: ff.is_multiple,
      is_numeric: ff.is_numeric,
      options: ff.options,
      required: ff.required,
      order_id: ff.order_id,
      default_value: ff.default_value
    }
  end

  def render("form.json", params = %{form: f}) do
    fields = params.fields || []

    base_form = %{
      id: f.id,
      title: f.title,
      description: f.description,
      has_repeat_entries: f.has_repeat_entries,
      has_repeat_vertical: f.has_repeat_vertical,
      repeat_entry_default_value: f.repeat_entry_default_value,
      repeat_label: f.repeat_label
    }

    if fields == [] do
      base_form
    else
      rendered_fields =
        render_many(fields, BoilerPlateWeb.FormView, "form_field.json", as: :form_field)

      Map.put(base_form, :formFields, rendered_fields)
    end
  end

  def render("form_submission.json", %{form_submission: _fs}) do
    raise ArgumentError, "form_submission.json is TODO"
  end
end
