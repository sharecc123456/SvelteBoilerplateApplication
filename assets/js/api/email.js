export async function sendUpdatedDocumentEmailNotification(iacDocId, note) {
  let reply = await fetch(`/n/api/v1/document/update/email/notification`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      iacDocId,
      comment: note,
    }),
  });

  return reply;
}
