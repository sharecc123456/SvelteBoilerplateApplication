import { createNewChecklist, setupRSDDocument } from "./Checklist.js";

export const requires_iac_fill = (templates) => {
  // checks if any selected templates has IAC setup
  return templates.some((x) => { console.log(x); console.log(x.is_iac); return x.is_iac === true });
};

export async function createAndSendChecklist({ text, CheckBoxStatus }, templates) {
  const checklistContents = {
    name: text,
    description: "-",
    documents: [...templates.map(x => x.id)],
    file_requests: [],
    commit: true,
    allow_duplicate_submission: false,
    allow_multiple_requests: false,
    archive_checklist: !CheckBoxStatus
  };

  // create checklist
  const reply = await createNewChecklist(checklistContents);
  if (reply.ok) {
    let response = await reply.json();
    return { ok: true, id: response.id }
  } else {
    return {};
  }
};

export async function setupTemplateForRSD(rawDocId, recipientId) {
  const reply = await setupRSDDocument(rawDocId, recipientId);
  if (reply.ok) {
    let response = await reply.json();
    console.log(response)
    return response
  } else {
    return {};
  }
};
