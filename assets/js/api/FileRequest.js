async function getFileRequest(id) {
  let request = await fetch(`/n/api/v1/filerequest/${id}`);
  let assignments = await request.json();
  return assignments;
}

async function fileRequestManualUpload(assignId, requestId, file) {
  let fd = new FormData();
  fd.append("file", file);
  fd.append("assignId", assignId);

  let reply = await fetch(`/n/api/v1/filerequest/${requestId}/manual`, {
    method: "POST",
    credentials: "include",
    body: fd,
  });

  return reply;
}

/**
 * @description method to return expired document back to user for reupload
 * this method uses exact signature of return review item method
 * @param {number} item - submitted item id
 * @param {string} type - template or request type
 * @param {string} comments
 * @returns
 */
async function returnExpiredItem(itemId, type, comments) {
  let data = {
    type: type,
    comments: comments,
    itemId: itemId,
  };

  let request = await fetch(`/n/api/v1//document/${itemId}/return/expire`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

const hasExpirationValueChanged = (newExpiration, currentExpirationInfo) => {
  if (
    currentExpirationInfo.type === newExpiration.type &&
    newExpiration.value === currentExpirationInfo.value
  ) {
    return false;
  }
  return true;
};

export {
  getFileRequest,
  fileRequestManualUpload,
  returnExpiredItem,
  hasExpirationValueChanged,
};
