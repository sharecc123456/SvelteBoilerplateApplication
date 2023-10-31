export async function uploadCabinet(cabinet, cabinetRID) {
  let fd = new FormData();
  fd.append("name", cabinet.name);
  fd.append("upload", cabinet.file);
  let reply = await fetch(`/n/api/v1/recipient/${cabinetRID}/cabinet`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

export async function deleteRecipientCabinetId(rId, id) {
  let reply = await fetch(`/n/api/v1/recipient/${rId}/cabinet/${id}`, {
    method: "DELETE",
    credentials: "include",
  });

  return reply;
}

export async function replaceRecipientCabinetId(cabinet, rId, id) {
  let fd = new FormData();
  fd.append("upload", cabinet.file);
  let reply = await fetch(`/n/api/v1/recipient/${rId}/cabinet/${id}/replace`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}
