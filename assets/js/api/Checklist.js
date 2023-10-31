export const SHOW_DELETED_CHECKLIST_KEY = "SHOW_DELETED_CHECKLIST_KEY";

async function getChecklists() {
  let request = await fetch("/n/api/v1/checklists");
  let assignments = await request.json();
  return assignments;
}

async function getChecklist(id) {
  let request = await fetch(`/n/api/v1/checklist/${id}`);
  let assignments = await request.json();
  return assignments;
}

async function deleteChecklist(id) {
  let reply = await fetch(`/n/api/v1/checklist/${id}`, {
    method: "DELETE",
    credentials: "include",
  });

  return reply;
}

async function archiveChecklist(id) {
  let reply = await fetch(`/n/api/v1/checklist/archive/${id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
}

async function duplicateChecklist(id) {
  let data = {
    duplicate: true,
    checklistId: id,
  };

  let request = await fetch("/n/api/v1/checklist", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

async function createIntakeLink(id) {
  let data = {
    intakeLink: true,
    checklistId: id,
  };

  let request = await fetch("/n/api/v1/checklist", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

async function createSecureIntakeLink(data) {
  let request = await fetch("/n/api/v1/checklist", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

export async function remindNowV2(pid, rid, msg) {
  let data = {
    checklistId: pid,
    recipientId: rid,
    remindMessage: msg,
  };

  let reply = await fetch(`/n/api/v1/checklist/remind/`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });
  return reply;
}

async function checklistRescindRequest(rid, cid, _type, tid) {
  /* First grab the contents as it is */
  let contentsReply = await fetch(`/n/api/v1/contents/${cid}`);
  let contentsJson = await contentsReply.json();

  let requestIds = contentsJson.requests.map((x) => x.id);
  let newIds = requestIds.filter((x) => x != tid);

  /* Now create the final contents object */
  let finalObj = {
    documents: contentsJson.documents.map((x) => x.id),
    requests: newIds,
    title: contentsJson.title,
    forms: contentsJson.forms.map((form) => form.id),
    description: contentsJson.description,
  };

  /* POST it to the API */
  return await fetch(`/n/api/v1/contents/${cid}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(finalObj),
  });
}

async function checklistRescindTemplate(rid, cid, _type, tid) {
  /* First grab the contents as it is */
  let contentsReply = await fetch(`/n/api/v1/contents/${cid}`);
  let contentsJson = await contentsReply.json();

  let requestIds = contentsJson.documents.map((x) => x.id);
  let newIds = requestIds.filter((x) => x != tid);

  /* Now create the final contents object */
  let finalObj = {
    documents: newIds,
    requests: contentsJson.requests.map((x) => x.id),
    title: contentsJson.title,
    forms: contentsJson.forms.map((form) => form.id),
    description: contentsJson.description,
  };

  /* POST it to the API */
  return await fetch(`/n/api/v1/contents/${cid}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(finalObj),
  });
}

async function recipientChecklistCreate(checklistContents, uniqueIdentifier) {
  return await fetch("/n/api/v1/assignment/checklist/create", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      requestorId: checklistContents["sender"].user_id,
      packageId: checklistContents.package_id,
      assignmentId: checklistContents.id,
      contentsId: checklistContents.contents_id,
      recipientDescription: uniqueIdentifier,
      docRequests: checklistContents.document_requests,
    }),
  });
}

async function createNewChecklist(checklist) {
  console.log(`Submitting checklist...`);

  let reply = await fetch("/n/api/v1/checklist", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(checklist),
  });

  return reply;
}

async function setupRSDDocument(rawDocId, recipientId) {
  let reply = await fetch(
    `/n/api/v1/setup/rsd/document/${rawDocId}/recipient/${recipientId}`,
    {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
    }
  );

  return reply;
}

async function editSendChecklist(id, checklistName) {
  return await fetch(`/n/api/v1/checklist/edit/${id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      checklist_name: checklistName,
    }),
  });
}

export {
  checklistRescindRequest,
  checklistRescindTemplate,
  getChecklists,
  archiveChecklist,
  getChecklist,
  deleteChecklist,
  duplicateChecklist,
  createIntakeLink,
  createSecureIntakeLink,
  recipientChecklistCreate,
  createNewChecklist,
  setupRSDDocument,
  editSendChecklist,
};
