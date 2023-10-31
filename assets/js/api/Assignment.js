export const SORT_FIELDS = {
  LAST_ACTIVITY_DATE: "last_activity_date",
  RECIPIENT_NAME: "recipient_name",
  RECIPIENT_EMAIL: "recipient_email",
  RECIPIENT_ORG: "recipient_organization",
  STATUS: "status",
  NEXT_STATUS: "next_status",
};

/* Mark all existing customizations as stale */
async function resetCustomization(contentsId, templateId) {
  let reply = await fetch(`/n/api/v1/contents/${contentsId}/customize`, {
    method: "DELETE",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contentsId: contentsId,
      templateId: templateId,
    }),
  });

  return reply;
}

// expects {id, assignment_id, type}
// id -> item id, type -> item type
async function deleteCompleteItem(params) {
  const body = JSON.stringify(params);
  let reply = await fetch(`/n/api/v1/complete/item`, {
    method: "DELETE",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  return reply;
}

/* customize RSD @document in @contents to be the file @file */
async function customizeDocument(contents, document, file) {
  let fd = new FormData();
  fd.append("documentId", document.id);
  fd.append("file", file);

  let reply = await fetch(`/n/api/v1/contents/${contents.id}/customize`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

/* commit RSD placeholders as the "actual" copy */
async function commitRSDocuments(contents, documents) {
  let reply = await fetch(`/n/api/v1/contents/${contents.id}/commit`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      documentIds: documents.map((x) => x.id),
    }),
  });

  return reply;
}

/* Sends the Contents to the server for finalizing the assignment */
async function assignContents(contents, append_note = "") {
  let reply = await fetch(`/n/api/v1/assignment`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contentsId: contents.id,
      enforceDueDate: contents.enforce_due_date,
      dueDays: contents.due_days,
      checklistIdentifier: contents.requestorUniqueIdentifier,
      append_note: append_note,
    }),
  });

  return reply;
}

async function archiveAssignment(assignmentId) {
  let reply = await fetch(`/n/api/v1/assignment/archive`, {
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

async function unArchiveAssignment(assignmentId) {
  let reply = await fetch(`/n/api/v1/assignment/${assignmentId}/unarchive`, {
    method: "PUT",
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

async function unsendAssignment(assignmentId) {
  let reply = await fetch(`/n/api/v1/assignment/unsend`, {
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

/**
 * @description Unsend all the assignments for the recipient
 * @param {Number} recipientId
 * @returns {Object} response Object
 */
async function unsendRecipientAssignments(recipientId) {
  let reply = await fetch(
    `/n/api/v1/recipient/${recipientId}/assignments/unsend`,
    {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
    }
  );

  if (reply.ok) {
    return reply;
  }

  throw `${reply.status} ${reply.statusText}`;
}

async function getArchivedAssignments(recipientId) {
  let request = await fetch(
    `/n/api/v1/assignment/archive?recipientId=${recipientId}`
  );
  let assignments = await request.json();
  return assignments;
}

/* Recipient Portal stuff */
async function getAssignments() {
  let request = await fetch("/n/api/v1/assignments");
  let assignments = await request.json();
  return assignments;
}

async function getAssignmentWithId(id) {
  let request = await fetch("/n/api/v1/assignments/" + id);
  let data = await request.json();
  return data;
}
/**
 * @description Removes the draft contents
 * @param {number} contents_id
 * @returns {Object}
 */
async function deleteDraftContents(contents_id) {
  let reply = await fetch(`/n/api/v1/contents/${contents_id}`, {
    method: "DELETE",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
}

export {
  customizeDocument,
  commitRSDocuments,
  assignContents,
  getAssignments,
  archiveAssignment,
  unsendAssignment,
  getArchivedAssignments,
  resetCustomization,
  deleteDraftContents,
  unsendRecipientAssignments,
  unArchiveAssignment,
  getAssignmentWithId,
  deleteCompleteItem,
};
