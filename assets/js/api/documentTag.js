export async function getDocumentTag(companyId, type) {
  let reply = await fetch(`/n/api/v1/company/${companyId}/tags?type=${type}`);
  let result = await reply.json();
  return result;
}

export async function createDocumentTag(companyId, tag, type) {
  let request = await fetch(
    `/n/api/v1/company/${companyId}/tags?type=${type}`,
    {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(tag),
    }
  );

  return request;
}

export async function getDocumentTagById(tagId, type) {
  let reply = await fetch(`/n/api/v1/document-tag/${tagId}?type=${type}`);
  let result = await reply.json();
  return result;
}
