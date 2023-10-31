import { csvDownloader } from "Helpers/util";

export const FORM_EDITABLE_STATES = [0, 2, 3];
export const CSV_TEMPLATE_SAMPLE = {
  shortAnswer: "Some Text",
  number: 25,
  radio: "Option A",
  checkbox: '"Option A;Option C"',
};

export const handleDownloadCSV = (form) => {
  const csvFilename = form.title.replaceAll(" ", "-") + ".csv";
  let formCSV = formToCSV(form);
  csvDownloader(formCSV, csvFilename);
};

export const formEntryString = (entry) =>
  Object.values(entry).reduce((acc, val) => {
    let str = "";
    if (Array.isArray(val)) str = `(${val.join(",")})`;
    else str = val;
    if (str) acc += `${acc ? ", " : ""}${str}`;
    return acc;
  }, "");

export const validateFormInput = (formFields, formValues) => {
  let invalidFills = formFields
    .map((question) => {
      let val = formValues[question.id];
      if (
        question.required &&
        (val === null || val === "" || val === undefined)
      )
        return question.id;
      // checking if numeric field value is a number or not
      switch (question.type) {
        case "checkbox":
          if (question.required && val.length === 0) {
            return question.id;
          }
          break;
        case "date":
          if (question.required && val === undefined) {
            return question.id;
          }
          break;
        case "number":
          if (question.required && question.is_numeric && isNaN(val))
            return question.id;
          break;
        default:
          if (
            question.required &&
            (val === undefined || val.trim().length < 1)
          ) {
            return question.id;
          }
      }

      if (!question.is_multiple) {
        if ((val === null || val == "") && question.required) {
          return question.id;
        }
        return;
      }

      if (question.required && val?.length === 0) return question.id;

      return;
    })
    .filter((id) => id !== undefined);
  return invalidFills.length === 0 ? true : false;
};

export const formToCSV = (form) => {
  const { has_repeat_entries, entries: formEntries, formFields } = form;
  const entries = has_repeat_entries
    ? formEntries
    : [
        formFields.reduce((acc, field) => {
          acc[field.id] = field.is_multiple ? field.values : field.value;
          return acc;
        }, {}),
      ];
  let header_row = formFields.reduce((acc, field) => {
    if (field.type == "instruction") return acc;
    if (acc == "") acc = `"${field.title}"`;
    else acc += `,"${field.title}"`;
    return acc;
  }, "");
  header_row += "\n";
  let rows = entries.reduce((acc, entry) => {
    let row_string = formFields.reduce((acc, field) => {
      if (field.type == "instruction") return acc;
      const val = entry[field.id];
      const csvVal =
        val == undefined
          ? `""`
          : field.is_numeric
          ? `${val}`
          : field.is_multiple
          ? `"${val.join("; ")}"`
          : `"${val}"`;

      if (acc == "") acc = csvVal;
      else acc += `,${csvVal}`;

      return acc;
    }, "");

    row_string += "\n";
    acc += row_string;
    return acc;
  }, "");
  const formCSV = header_row + rows;
  return formCSV;
};

export const returnFormSubmission = async (params) => {
  const body = JSON.stringify({
    form_submission_id: params.formSubmissionId,
    return_comments: params.return_comments,
  });

  let res = await fetch("/n/api/v1/form-submission/return", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  let reply = await res.json();

  // {}: returns id and msg == "returned"
  return reply;
};

export const acceptFormSubmission = async (params) => {
  const body = JSON.stringify({
    form_submission_id: params.formSubmissionId,
  });

  let res = await fetch("/n/api/v1/form-submission/accept", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  let reply = await res.json();

  // {}: returns id and msg == "accepted"
  return reply;
};

export const createForm = async (formCreationData) => {
  const body = JSON.stringify(formCreationData);

  let res = await fetch("/n/api/v1/form", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  let reply = await res.json();

  // {}: returns form
  return reply;
};

export const createFormSubmission = async (submissionData) => {
  const body = JSON.stringify(submissionData);

  let res = await fetch("/n/api/v1/form-submission", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  let reply = await res.json();

  // {}: returns id-> form_id, msg -> inserted/updated
  return reply;
};

export const getFormSubmission = async (assignmentId, formId) => {
  let res = await fetch(`/n/api/v1/form-submission/${assignmentId}/${formId}`, {
    credentials: "include",
  });

  let reply = await res.json();

  // {}: returns formSubmssion
  return reply;
};

export const unsendForm = async (assignmentId, formId) => {
  let res = await fetch(`/n/api/v1/form/unsend/${assignmentId}/${formId}`, {
    credentials: "include",
    method: "POST",
  });

  let reply = await res.json();

  // {}: msg, form_id
  return reply;
};

export const deleteFormSubmission = async (id) => {
  const body = JSON.stringify({
    form_submission_id: id,
  });

  let res = await fetch("/n/api/v1/form-submission", {
    method: "DELETE",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  let reply = await res.json();

  // {}: returns id and msg == "accepted"
  return reply;
};

export const formSubmitPrefill = async (contentsId, form) => {
  let request = await fetch(`/n/api/v1/form/${form.id}/${contentsId}/prefill`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(form),
  });

  if (!request.ok) {
    throw new Error("Failed to update the form, your changes may not be saved");
  }

  return request;
};

export async function updateContentsAsync(contents) {
  let raw_contents = {
    id: contents.id,
    title: contents.title,
    description: contents.description,
    documents: contents.documents.map((x) => x.id),
    requests: contents.requests.map((x) => x.id),
    forms: contents.forms.map((f) => f.id),
  };

  let request = await fetch(`/n/api/v1/contents/${contents.id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(raw_contents),
  });

  if (!request.ok) {
    throw new Error(
      "Failed to update the contents, your changes may not be saved"
    );
  }
}

export const formCreateShadow = async (questions, iacFieldId) => {
  let request = await fetch(`/n/api/v1/iac/field/${iacFieldId}/shadowform`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ form: questions }),
  });

  return request;
};

export const formUpdateShadow = async (questions, iacFieldId) => {
  let request = await fetch(`/n/api/v1/iac/field/${iacFieldId}/shadowform`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ form: questions }),
  });

  return request;
};

export const getFormById = async (form_id) => {
  let request = await fetch(`/n/api/v1/form/${form_id}`, {
    credentials: "include",
  });

  return request;
};
