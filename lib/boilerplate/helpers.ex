alias BoilerPlateWeb.FormController

defmodule BoilerPlate.Helpers do
  def file_validator?(file_name, allowed_extensions) do
    file_ext = Path.extname(file_name)

    allow_upload =
      allowed_extensions
      |> Enum.map(fn ext ->
        file_ext == ext
      end)
      |> Enum.any?()

    allow_upload
  end

  def get_param(params, key, default_value) do
    (params[key] != "" && params[key]) || default_value
  end

  def stringContains?(str1, keyword) do
    String.downcase(str1 || "") |> String.contains?(keyword)
  end

  def findInDocuments?(documents, str) do
    Enum.any?(documents, fn doc ->
      (doc.description != nil and
         stringContains?(doc.description, str)) ||
        (doc.name != nil and stringContains?(doc.name, str))
    end)
  end

  def findInChecklist?(checklist, str) do
    %{
      name: name,
      description: description,
      file_requests: file_requests,
      documents: document_requests,
      forms: forms
    } = checklist

    inFileRequests = findInDocuments?(file_requests, str)
    inDocumentRequests = findInDocuments?(document_requests, str)
    inForms = FormController.findInForms?(forms, str)

    stringContains?(name, str) ||
      stringContains?(description, str) ||
      inFileRequests ||
      inDocumentRequests ||
      inForms
  end

  def findInRecipient?(recipient, str) do
    %{company: company, name: name, email: email} = recipient
    stringContains?(name, str) || stringContains?(email, str) || stringContains?(company, str)
  end

  def get_status_text(state, params) do
    return_reason = params["return_reason"] || ""
    missing_reason = params["missing_reason"] || ""
    is_manually_submitted = params["is_manually_submitted"] || false

    case state.status do
      0 ->
        "Open"

      1 ->
        "In Progress"

      2 ->
        "Ready for review"

      3 ->
        if return_reason == "",
          do: "Returned for updates",
          else: "Returned for updates " <> return_reason

      4 ->
        if is_manually_submitted, do: "Added manually", else: "Completed"

      5 ->
        ""

      6 ->
        if missing_reason == "", do: missing_reason, else: "Missing"

      7 ->
        "Partially Completed"

      9 ->
        "Auto Removed"

      10 ->
        "Manually Removed"

      _ ->
        "UNKNOWN"
    end
  end

  def typeof(a) do
    cond do
      is_float(a) -> "float"
      is_number(a) -> "number"
      is_atom(a) -> "atom"
      is_boolean(a) -> "boolean"
      is_binary(a) -> "binary"
      is_function(a) -> "function"
      is_list(a) -> "list"
      is_tuple(a) -> "tuple"
      true -> "idunno"
    end
  end

  def parse_number(str) do
    if typeof(str) == "number" do
      str
    else
      case str |> Integer.parse() do
        # not a string but a float
        {num, leftover} ->
          if leftover == "" do
            num
          else
            case str |> Float.parse() do
              {num, _} -> num
              :error -> str
            end
          end

        :error ->
          str
      end
    end
  end

  def get_utc_date(date) do
    if date == nil do
    else
      {:ok, date_time, 0} = DateTime.from_iso8601(date)
      date_time |> DateTime.truncate(:second)
    end
  end

  def atom_keys_to_string(map) do
    for {k, v} <- map, into: %{}, do: {to_string(k), v}
  end
end
