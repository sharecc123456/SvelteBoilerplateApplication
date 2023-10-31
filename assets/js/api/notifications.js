async function getNotifications() {
  let request = await fetch(`/n/api/v1/notifications`);
  let notifications = await request.json();
  return notifications;
}

async function markNotificationRead(nid) {
  let reply = await fetch(`/n/api/v1/notification/${nid}/markread`, {
    method: "PUT",
    credentials: "include",
  });

  return reply;
}

async function getNotificationDetails(nid) {
  let reply = await fetch(`/n/api/v1/notification/${nid}/details`, {
    method: "GET",
    credentials: "include",
  });
  return reply;
}

async function markNotificationArchive(nid) {
  let reply = await fetch(`/n/api/v1/notification/${nid}/archive`, {
    method: "PUT",
    credentials: "include",
  });

  return reply;
}

async function getUnreadNotificationCount(type = "requestor") {
  let reply = await fetch(`/n/api/v1/notifications/unread?type=${type}`, {
    method: "GET",
    credentials: "include",
  });
  let notifications = await reply.json();

  return notifications;
}

export {
  getNotifications,
  markNotificationRead,
  getUnreadNotificationCount,
  markNotificationArchive,
  getNotificationDetails,
};
