export const addWhiteLabel = async (_body) => {
  const body = JSON.stringify(_body);

  let reply = await fetch(`/n/api/v1/company/add-white-label`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body,
  });

  const resBody = await reply.json();

  return resBody;
};

export const uploadWhiteLabel = async (companyId, file) => {
  const formData = new FormData();
  formData.append("file", file[0]);
  formData.append("company_id", companyId);

  let reply = await fetch(`/n/api/v1/company/upload-white-label`, {
    method: "POST",
    credentials: "include",
    body: formData,
  });

  const resBody = await reply.json();

  return resBody;
};
