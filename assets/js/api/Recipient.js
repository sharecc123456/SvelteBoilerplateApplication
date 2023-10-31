import { createQueryParams } from "Helpers/util";

export const SORT_FIELDS = {
  NAME: "name",
  COMPANY: "organization",
  EMAIL: "email",
  DATE_ADDED: "inserted_at",
  LAST_MODIFIED: "updated_at",
};

export const RECIPIENT_DROPDOWN_ACTIONS = {
  DETAILS: 1,
  DELETE: 2,
  ADD_FILE_CABINET: 3,
  SHOW_IN_DASHBOARD: 4,
  VIEW_DOCUMENTS: 5,
  SEND_NEW_REQUEST: 6,
  ASSIGN: 7,
  RESTORE: 8,
};

export const SHOW_DELETED_RECIPIENT_KEY = "SHOW_DELETED_RECIPIENT_KEY";

export async function getRecipientsPaginated(_params) {
  const url = "/n/api/v1/recipients-paginated";
  const queryParams = createQueryParams(_params);
  let request = await fetch(url + queryParams);
  let reply = await request.json();
  return reply;
}

async function getRecipients() {
  let request = await fetch("/n/api/v1/recipients");
  let reply = await request.json();
  return reply;
}

async function loadDashboardCSV(filterStr, queryStr) {
  let response = await fetch(`/n/api/v1/dashboard${queryStr}`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ ...filterStr, export: true }),
  });

  let reply = await response.json();

  return reply;
}

async function loadDashboardData(filterStr, queryStr) {
  let response = await fetch(`/n/api/v1/dashboard${queryStr}`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(filterStr),
  });

  let reply = await response.json();

  return reply;
}

async function loadDashboardMetadata(filterStr, queryStr) {
  let response = await fetch(`/n/api/v1/metadashboard${queryStr}`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(filterStr),
  });

  let reply = await response.json();

  return reply;
}

async function loadDashboardForRecipient(recipient_id, filterStr) {
  const response = await fetch(`/n/api/v1/dashboard/${recipient_id}`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(filterStr),
  });

  let reply = await response.json();

  return reply;
}

async function getHiddenRecipients() {
  let request = await fetch("/n/api/v1/recipients?filter=hidden");
  let reply = await request.json();
  return reply;
}

async function getRecipient(id) {
  let request = await fetch(`/n/api/v1/recipient/${id}`);
  let reply = await request.json();
  return reply;
}

/* Checks if a recipient by email @email exists in the _current_ company */
async function recipientExists(email) {
  let request = await fetch(`/n/api/v1/recipient?email=${encodeURI(email)}`);

  if (request.ok) {
    let status = await request.json();
    return status;
  } else {
    return false;
  }
}

async function getCabinet(id) {
  let request = await fetch(`/n/api/v1/recipient/${id}/cabinet`);
  let assignments = await request.json();
  return assignments;
}

async function newRecipient(n) {
  let reply = await fetch("/n/api/v1/recipient", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(n),
  });

  return reply;
}

async function bulkNewRecipient(recipients) {
  let reply = await fetch("/n/api/v1/recipient/bulk", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      recipients: recipients,
    }),
  });

  return reply;
}

async function deleteRecipient(id, type = "") {
  let reply = await fetch(`/n/api/v1/recipient/${id}?type=${type}`, {
    method: "DELETE",
    credentials: "include",
  });

  return reply;
}

async function hideRecipient(id) {
  let reply = await fetch(`/n/api/v1/recipient/hide/${id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
}

async function unHideRecipient(id) {
  let reply = await fetch(`/n/api/v1/recipient/show/${id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
}

async function updateRecipient(
  n,
  name,
  organization,
  email,
  phone_number,
  start_date,
  tags
) {
  let reply = await fetch(`/n/api/v1/recipient/${n.id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: name,
      organization: organization,
      email: email,
      phone_number: phone_number,
      start_date: start_date,
      tags: tags,
    }),
  });

  return reply;
}

/* Return the list of the companies this User has an account with. */
async function getCompanies() {
  let request = await fetch("/n/api/v1/user/companies");
  let reply = await request.json();
  return reply;
}

/**
 * @name currentUserInfo
 * @description get current user information based on the portal logged into
 * @param {str} usertype api client Enum: requestor, recipient
 *
 * @returns {Object} logged user info
 */
async function currentUserInfo(usertype) {
  let request = await fetch(`/n/api/v1/user/me?type=${usertype}`);
  let reply = await request.json();
  return reply;
}

async function recipientAddData(recipientId, label, value) {
  let response = await fetch(`/n/api/v1/recipient/${recipientId}/data`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      label: label,
      value: value,
    }),
  });

  return response;
}

export const recipientRestore = async (id) => {
  let reply = await fetch(`/n/api/v1/recipient/restore/${id}`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
  });

  return reply;
};

export const googleListContacts = async () => {
  let request = await fetch(`/n/api/v1/recipients/google`);
  let reply = await request.json();
  return reply;
};

export {
  getRecipients,
  loadDashboardCSV,
  loadDashboardData,
  loadDashboardMetadata,
  newRecipient,
  bulkNewRecipient,
  getRecipient,
  recipientExists,
  deleteRecipient,
  updateRecipient,
  getCompanies,
  getCabinet,
  hideRecipient,
  getHiddenRecipients,
  unHideRecipient,
  currentUserInfo,
  loadDashboardForRecipient,
  recipientAddData,
};
