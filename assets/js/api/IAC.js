const iacFieldTypes = [1, 2, 3];
const iacSetupFields = [
  {
    field_type: 1,
    name: "text",
    label: "Text Field",
    icon: "font-case",
  },
  {
    field_type: 2,
    name: "checkbox",
    label: "Checkbox",
    icon: "check-square",
  },
  {
    field_type: 3,
    name: "signature",
    label: "Signature",
    icon: "signature",
  },
  {
    field_type: 4,
    name: "table",
    label: "Repeat Entry Table (export only)",
    icon: "rectangle-list",
  },
];

async function getIacDocumentId(type, base_id) {
  return await fetch(`/n/api/v1/iac?type=${type}&id=${base_id}`);
}

async function getIacDocument(id) {
  let request = await fetch(`/n/api/v1/iac/${id}`);
  let reply = await request.json();
  return reply;
}

async function setupIac(id) {
  let reply = await fetch(`/n/api/v1/iac/${id}/setup`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      id: id,
    }),
  });

  return reply;
}

async function iacAddField(
  iacDocId,
  fieldType,
  bX,
  bY,
  fX,
  fY,
  pageNo,
  fill_type
) {
  let reply = await fetch(`/n/api/v1/iac/${iacDocId}/field`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fieldType: fieldType,
      baseX: bX,
      baseY: bY,
      finalX: fX,
      finalY: fY,
      pageNumber: pageNo,
      fill_type,
    }),
  });

  return reply;
}

async function iacUpdateField(iacDocId, fieldId, data) {
  let reply = await fetch(`/n/api/v1/iac/${iacDocId}/field/${fieldId}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return reply;
}

async function iacRemoveField(iacDocId, fieldId) {
  let reply = await fetch(`/n/api/v1/iac/${iacDocId}/field/${fieldId}`, {
    method: "DELETE",
    credentials: "include",
  });

  return reply;
}

async function iacSendEsignConsent(recipient, consent, userType) {
  let reply = await fetch(`/n/api/v1/esign/consent`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      consented: consent,
      recipientId: recipient,
      userType: userType,
    }),
  });

  return reply;
}

async function iacDelEsign(iacDocId, fieldIds, fillType) {
  let reply = await fetch(`/n/api/v1/iac/signatures`, {
    method: "DELETE",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      fieldIds,
      iacDocId,
      fillType
    }),
  });

  return reply;
}

async function iacGetEsignConsent(recipientId, userType) {
  let request = await fetch(
    `/n/api/v1/esign/consent/${recipientId}?userType=${userType}`
  );
  let reply = await request.json();
  return reply;
}

async function iacApplySignature(fieldId, signature_data) {
  let reply = await fetch(`/n/api/v1/iac/${fieldId}/signature`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(signature_data),
  });

  return reply;
}

export async function iacSaveForm(submission_data) {
  let reply = await fetch(`/n/api/v1/iac/${submission_data.iacDocId}/save`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(submission_data),
  });

  return reply;
}

export async function iacSubmitForm(assignmentId, iacDocId) {
  let reply = await fetch(`/n/api/v1/iac/${iacDocId}/submit`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      assignmentId: assignmentId,
    }),
  });

  return reply;
}

export async function iacGetAssignedFields(
  iacDocId,
  assignmentId,
  _recipientId
) {
  return await fetch(`/n/api/v1/iac/${iacDocId}/fields?assign=${assignmentId}`);
}

export async function iacGetAssignedFieldsRequestor(
  iacDocId,
  contentsId,
  recipientId
) {
  return await fetch(
    `/n/api/v1/iac/${iacDocId}/requestor_fields?cid=${contentsId}&rid=${recipientId}`
  );
}

export async function getRSDsIACPrefilled(contentsId, recipientId) {
  return await fetch(
    `/n/api/v1/iac/prefilled?cid=${contentsId}&rid=${recipientId}`
  );
}

// Get a dproxy filename for a PDF preview of the final IAC document
async function iacGetPreviewPDF(iacDocId, contentsId, tcId) {
  let reply = await fetch(`/n/api/v1/iac/${iacDocId}/genpdf`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contentsId: contentsId,
      trueContentsId: tcId,
    }),
  });

  return reply;
}

export async function postIACSESFill(data) {
  let res = await fetch(`/n/api/v1/iac/ses/fill`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
  return res;
}

export async function iacSESGetTargets(checklist_id) {
  return await fetch(`/n/api/v1/iac/ses/targets/${checklist_id}`);
}

export async function iacCommitLabels(iacDocId) {
  let res = await fetch(`/n/api/v1/iac/labels`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      iacDocId: iacDocId,
    }),
  });
  return res;
}

export async function iacGetLabelQuestion(label) {
  let request = await fetch(`/n/api/v1/iac/label?value=${label}`);
  if (request.ok) {
    let reply = await request.json();
    return reply;
  } else {
    return "";
  }
}

export async function iacSESCreateForm(rawDocTemplateId, form) {
  let reply = await fetch(`/n/api/v1/iac/ses/form`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      template_id: rawDocTemplateId,
      form: form,
    }),
  });

  return reply;
}

export async function iacGetLabelsAPI() {
  let r = await fetch("/n/api/v1/iac/labels");
  if (r.status != 200) {
    console.error(`Error fetching IAC labels: ${r.status}`);
    return [];
  } else {
    return await r.json();
  }
}

export {
  getIacDocumentId,
  getIacDocument,
  setupIac,
  iacAddField,
  iacRemoveField,
  iacUpdateField,
  iacSendEsignConsent,
  iacGetEsignConsent,
  iacApplySignature,
  iacDelEsign,
  iacGetPreviewPDF,
  iacSetupFields,
  iacFieldTypes,
};
