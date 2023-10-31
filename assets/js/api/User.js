async function loginUser(email, hashed_password) {
  let request = await fetch("/n/api/v1/login", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: email,
      hashedPassword: hashed_password,
    }),
  });

  return request;
}

async function loginUserSSO(sso, credential) {
  let request = await fetch("/n/api/v1/loginsso", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      sso: sso,
      credential: credential,
    }),
  });

  return request;
}

async function checkIfExists(email) {
  let request = await fetch(`/n/api/v1/user/lookup?email=${encodeURI(email)}`);

  if (request.ok) {
    let status = await request.json();
    return status;
  } else {
    return false;
  }
}

/* Try to register the user and immediately apply the adhoc  */
async function adhocRegister(name, email, hashed_password, adhoc_string, org) {
  let request = await fetch("/n/api/v1/user/adhoc/register", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      name: name,
      email: email,
      hashedPassword: hashed_password,
      adhocString: adhoc_string,
      organization: org,
    }),
  });

  return request;
}

/* Apply the adhoc to the user denoted by the id  */
async function adhocAssign(id, name, adhoc_string) {
  let request = await fetch("/n/api/v1/user/adhoc/assign", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      id: id,
      name: name,
      adhocString: adhoc_string,
    }),
  });

  return request;
}

async function sendForgotPassword(email) {
  let request = await fetch("/n/api/v1/forgot/password", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: email,
    }),
  });

  return request;
}

async function userUpdateProfile(user_id, data) {
  let request = await fetch(`/n/api/v1/user/${user_id}/profile`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

async function userMfaUpdate(user_id, new_state, extra = {}) {
  let request = await fetch(`/n/api/v1/user/${user_id}/mfa`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ state: new_state, data: extra }),
  });

  return request;
}

async function addTextSignature(text_signature) {
  let request = await fetch(`/n/api/v1/user/add_text_signature`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      text_signature: text_signature,
    }),
  });

  return request;
}

async function getTextSignature() {
  let request = await fetch(`/n/api/v1/user/get_text_signature`);
  let reply = await request.json();
  return reply;
}

async function toggleAdminNotifications(reqId, setFlag) {
  let request = await fetch(`/n/api/v1/requestor/${reqId}/set-admin-notify`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      flag: setFlag,
    }),
  });

  return request;
}

export async function toggleWeeklyDigest(reqId, setFlag) {
  let request = await fetch(`/n/api/v1/requestor/${reqId}/set-weekly-digest`, {
    method: "PUT",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      flag: setFlag,
    }),
  });

  return request;
}

async function getUserRetrieveLink(user_id) {
  let request = await fetch(`/n/api/v1/user/retrieve-link`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      uid: user_id,
    }),
  });

  return request;
}

export {
  loginUser,
  loginUserSSO,
  checkIfExists,
  adhocRegister,
  adhocAssign,
  sendForgotPassword,
  userUpdateProfile,
  userMfaUpdate,
  addTextSignature,
  getTextSignature,
  toggleAdminNotifications,
  getUserRetrieveLink,
};
