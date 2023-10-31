async function uploadFileRequest(fr, recipientId, assignmentId, file) {
  let fd = new FormData();
  fd.append("file", file);
  fd.append("recipientId", recipientId);
  fd.append("assignmentId", assignmentId);

  let reply = await fetch(`/n/api/v1/filerequest/${fr.id}`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function uploadMultipleFileRequest(fr, recipientId, assignmentId, files) {
  let fd = new FormData();

  files.forEach((file) => {
    fd.append("file[]", file);
  });
  fd.append("recipientId", recipientId);
  fd.append("assignmentId", assignmentId);

  let reply = await fetch(`/n/api/v1/filerequest/${fr.id}/save`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function uploadRequestAsSeparateFileRequests(
  fr,
  recipientId,
  assignmentId,
  files
) {
  let fd = new FormData();

  files.forEach((file) => {
    fd.append("file[]", file);
  });
  fd.append("recipientId", recipientId);
  fd.append("assignmentId", assignmentId);

  let reply = await fetch(`/n/api/v1/mutiple/requests/${fr.id}`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function sendUploadedAdditionalFiles(
  reqId,
  recipientId,
  assignmentId,
  name,
  files
) {
  let fd = new FormData();

  files.forEach((file) => {
    fd.append("file[]", file);
  });
  fd.append("recipientId", recipientId);
  fd.append("assignmentId", assignmentId);
  fd.append("requestName", name);

  let reply = await fetch(`/n/api/v1/extra/requests/${reqId}`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function editFileRequest(cid, files) {
  let fd = new FormData();

  files.forEach((file) => {
    fd.append("file[]", file);
  });

  let reply = await fetch(`/n/api/v1/filerequest/${cid}/edit`, {
    method: "PUT",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function submitFileRequest(completionId, reqId) {
  let reply = await fetch(
    `/n/api/v1/filerequest/${reqId}/uploaded/${completionId}/submit`,
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

async function requestExpirationInfo(reqId, { type, value }) {
  let reply = await fetch(`/n/api/v1/filerequest/${reqId}/track/expiration`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ expirationInfo: { type, value } }),
  });

  return reply;
}

async function deleteFileRequest(completionId) {
  let reply = await fetch(`/n/api/v1/filerequest/${completionId}`, {
    method: "DELETE",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
}

async function markFileRequestMissing(
  assign,
  fr,
  missing_reason,
  force = false
) {
  let reply = await fetch(`/n/api/v1/filerequest/${fr.id}/missing`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      assignmentId: assign.id,
      missing_reason: missing_reason,
      force: force,
    }),
  });
  return reply;
}

async function uploadFilledRequest(fr, recipientId, assignmentId, text) {
  let fd = new FormData();
  fd.append("text", text);
  fd.append("recipientId", recipientId);
  fd.append("assignmentId", assignmentId);

  let reply = await fetch(`/n/api/v1/datarequest/${fr.id}`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function uploadDocument(doc, recipientId, assignmentId, files) {
  let fd = new FormData();
  files.forEach((file) => {
    fd.append("file[]", file);
  });
  fd.append("recipientId", recipientId);
  fd.append("assignmentId", assignmentId);

  let reply = await fetch(`/n/api/v1/document/${doc.id}`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function markInfoAsRead(docId, assignmentId) {
  let data = {
    templateId: docId,
    assignmentId: assignmentId,
  };

  let request = await fetch("/n/api/v1/template/read", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

async function getDocumentCompletion(type, aid, did) {
  let request = await fetch(`/n/api/v1/completion/${did}?type=${type}`);
  let reply = await request.json();
  return reply;
}

/**
 * @description provides file information of customized document.
 * @param {Number} customizationId
 * @returns {Object}
 */
async function getIacSendDocument(customizationId, assignmentId) {
  let request = await fetch(
    `/n/api/v1/requestor/customized/doc/${customizationId}?assignmentId=${assignmentId}`
  );
  let reply = await request.json();
  return reply;
}

async function getWhitelabeling(type) {
  let request = await fetch(`/n/api/v1/whitelabel?user_type=${type}`);
  try {
    let reply = await request.json();
    return reply;
  } catch (e) {
    return { enabled: false };
  }
}

async function markAsDone(assignment, fr) {
  let data = {
    recipientId: assignment.recipient_id,
    assignmentId: assignment.id,
    taskId: fr.id,
  };

  let reply = await fetch("/n/api/v1/taskrequest/", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return reply;
}

async function submitConfirmationAndMarkTaskDone(
  fileCompletionId,
  FileReqId,
  assignmentId,
  recipientId,
  taskId
) {
  const confirmationFileSubmissionReply = await submitFileRequest(
    fileCompletionId,
    FileReqId
  );

  const taskCompletionReply = await markAsDone(
    { id: assignmentId, recipient_id: recipientId },
    { id: taskId }
  );
  if (confirmationFileSubmissionReply.ok && taskCompletionReply.ok) {
    return true;
  }
  return false;
}

async function uploadTaskConfirmationDocument(doc, assignmentId, file) {
  let fd = new FormData();
  fd.append("file", file[0]);
  fd.append("assignmentId", assignmentId);

  let reply = await fetch(
    `/n/api/v1/task/${doc.id}/confirmation/${assignmentId}`,
    {
      method: "POST",
      credentials: "include",
      body: fd,
    }
  );

  if (reply.ok) {
    return await reply.json();
  } else {
    return {};
  }
}

export {
  markFileRequestMissing,
  uploadFileRequest,
  uploadMultipleFileRequest,
  uploadDocument,
  uploadFilledRequest,
  getDocumentCompletion,
  getWhitelabeling,
  markInfoAsRead,
  markAsDone,
  submitFileRequest,
  requestExpirationInfo,
  editFileRequest,
  deleteFileRequest,
  sendUploadedAdditionalFiles,
  uploadRequestAsSeparateFileRequests,
  getIacSendDocument,
  uploadTaskConfirmationDocument,
  submitConfirmationAndMarkTaskDone,
};
