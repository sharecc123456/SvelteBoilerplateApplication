async function getTemplates() {
  let request = await fetch("/n/api/v1/templates");
  let assignments = await request.json();
  return assignments;
}

/* Update the template's metadata */
async function updateTemplate(templateId, raw) {
  let reply = await fetch(`/n/api/v1/template/${templateId}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(raw),
  });

  return reply;
}

/* Update raw template name */
async function updateTemplateName(templateId, name) {
  let reply = await fetch(`/n/api/v1/template-raw/${templateId}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ name }),
  });

  return reply;
}

async function replaceActiveTemplateUpload(templateId, file) {
  let fd = new FormData();
  fd.append("file", file);

  let reply = await fetch(`/n/api/v1/template/${templateId}/substitute/file`, {
    method: "PUT",
    credentials: "include",
    body: fd,
  });

  if (reply.ok) {
    const { id } = await reply.json();
    return id;
  }
}

async function resetTemplate(templateId, flag) {
  let reply = await fetch(`/n/api/v1/template/${templateId}/reset`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ flag }),
  });

  if (reply.ok) {
    const { id } = await reply.json();
    return id;
  }
}

/* Get the template by its id */
async function getTemplate(id, usertype = "requestor") {
  let request = await fetch(`/n/api/v1/template/${id}?type=${usertype}`);
  if (request.status != 200) {
    console.error("Error while getting template");
    console.error(request.statusText);
    return {};
  }
  let assignments = await request.json();
  return assignments;
}

async function deleteTemplate(id) {
  let reply = await fetch(`/n/api/v1/template/${id}`, {
    method: "DELETE",
    credentials: "include",
  });

  return reply;
}

async function archiveTemplate(id) {
  let reply = await fetch(`/n/api/v1/template/archive/${id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
}

async function templateManualUpload(assignId, documentId, file) {
  let fd = new FormData();
  fd.append("file", file);
  fd.append("assignId", assignId);

  let reply = await fetch(`/n/api/v1/template/${documentId}/manual`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function directSendTemplates(name, files, recipientId) {
  let fd = new FormData();

  files.forEach((file) => {
    fd.append("uploads[]", file);
  });
  fd.append("name", name);
  fd.append("description", "Secure Files Transfer");

  let reply = await fetch(`/n/api/v1/direct/send/recipient/${recipientId}`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function directSendUploadedTemplates(rawDocID, recipientId) {
  let reply = await fetch(`/n/api/v1/direct/send/recipient/${recipientId}`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      rawDocId: rawDocID,
    }),
  });

  return reply;
}

async function createTemplate(templateName, file, isArchived) {
  let fd = new FormData();

  fd.append("name", templateName);
  fd.append("upload", file);
  fd.append("archive_template", isArchived);

  let reply = await fetch(`/n/api/v1/template`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

async function directSendChecklist(checklistId, recipientId) {
  console.log(checklistId, recipientId);
  let reply = await fetch(
    `/n/api/v1/direct/send/checklist/${checklistId}/recipient/${recipientId}`,
    {
      method: "POST",
      credentials: "include",
    }
  );

  return reply;
}

export {
  updateTemplate,
  getTemplate,
  getTemplates,
  deleteTemplate,
  archiveTemplate,
  templateManualUpload,
  directSendTemplates,
  directSendChecklist,
  createTemplate,
  directSendUploadedTemplates,
  replaceActiveTemplateUpload,
  resetTemplate,
  updateTemplateName,
};
