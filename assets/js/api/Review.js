import { createQueryParams } from "Helpers/util";

export const SORT_FIELDS = {
  RECIPIENT_NAME: "recipient_name",
  CHECKLIST_NAME: "checklist_name",
  RECIPIENT_ORG: "recipient_organization",
  DATE_SUBMITTED: "submitted",
  STATUS: "status",
};

export const REVIEW_AUTO_DOWNLOAD_KEY = "autoDownloadEnabled";

/*
 * Get the currently pending review items paginated
 */
async function getReviewsPaginated(_params) {
  const url = "/n/api/v1/reviews-paginated";
  const queryParams = createQueryParams(_params);
  let request = await fetch(url + queryParams);
  let reply = await request.json();
  return reply;
}
/*
 * Get the currently pending review items
 */
async function getReviewItems() {
  let request = await fetch("/n/api/v1/reviews");
  let reviews = await request.json();
  return reviews;
}

export async function getReviewItemsContents(contents_id) {
  let request = await fetch(`/n/api/v1/reviews/contents/${contents_id}`);
  let reviews = await request.json();
  return reviews;
}

/*
 * check for pending reviews
 */
async function checkIfReviewsPending() {
  let request = await fetch("/n/api/v1/lookup/reviews/pending");
  let reviews = await request.json();

  return reviews;
}

/*
 * check if reviews doc is last doc to review
 */
async function checkIfLastReviewPending(assignment_id) {
  let request = await fetch(
    `/n/api/v1/lookup/remaining/reviews/${assignment_id}`
  );
  let reviewItem = await request.json();

  return reviewItem;
}

/*
 * Return a currently pending review item of type with comments
 */
async function returnReviewItem(item, type, comments) {
  let data = {
    type: type,
    comments: comments,
    itemId: item.id,
  };

  let request = await fetch("/n/api/v1/review/return", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

/*
 * Accept a pending review item
 */
async function acceptReviewItem(item, type) {
  let data = {
    type: type,
    export: item.export,
    itemId: item.id,
  };

  let request = await fetch("/n/api/v1/review/accept", {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  return request;
}

/*
 * Accept all pending review items
 */
async function acceptAllReviewItem(data) {
  let requests = [];
  data.forEach((item) => {
    // add documents
    for (let i = 0; i < item.documents.length; i++) {
      if (item.documents[i].allow_edits) {
        // Skip countersign documents
        continue;
      }
      requests.push(
        acceptReviewItem(
          {
            id: item.documents[i].id,
          },
          "document"
        )
      );
    }
    // add requests
    for (let i = 0; i < item.requests.length; i++) {
      requests.push(
        acceptReviewItem(
          {
            id: item.requests[i].id,
          },
          "request"
        )
      );
    }
    // add forms
    for (let i = 0; i < item.forms.length; i++) {
      requests.push(
        acceptReviewItem(
          {
            id: item.forms[i].submission_id,
          },
          "form"
        )
      );
    }
  });
  return Promise.all(requests); //.then((data) => {
  //   // window.location.reload();
  //   console.log(data);
  //   console.lg("reviews accepted");
  // });
}

/**
 * @description Send email of checklist completion notification
 * @param {string} emailAddress email address of the recipeint
 * @param {string} checklistId checklist to send
 *
 */
async function sendEmailNotification({
  emailAddress,
  assignment_id,
  forward_name = "None", // not getting Notifying user name currently
}) {
  let data = {
    forward_name: forward_name,
    assignment_id: assignment_id,
    emailAddress: emailAddress,
  };

  let request = await fetch(`/n/api/v1/assignment/email/notification`, {
    method: "POST",
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(data),
  });

  if (request.ok) {
    return await request.json();
  }
}

const getActionsPrompt = ({ disableArchiveButtonOption, hasLabels }) => {
  return [
    {
      evt: "viewChecklist",
      description: "View Checklist",
      icon: "eye",
    },
    {
      evt: "notify",
      description: "Notify team member",
      icon: "flag-checkered",
    },
    {
      evt: "archive",
      description: `${
        disableArchiveButtonOption ? "Checklist In Archive State" : "Archive"
      }`,
      icon: "archive",
      disabled: disableArchiveButtonOption,
    },
    {
      description: "Export Data to Documents",
      disabled: !hasLabels,
      icon: "file-export",
      evt: "datatab",
    },
    {
      evt: "send",
      description: "Send next checklist (will close this menu)",
      icon: "paper-plane",
    },
    {
      evt: "download-all",
      description: "Download All",
      icon: "download",
    },
  ];
};

/**
 * @description get list of admins for the company
 * @param {string} companyId
 * @returns {Array} admins
 *
 */
async function getCompanyAdmins(companyId) {
  let request = await fetch(`/n/api/v1/company/${companyId}/admin`);
  let reviewItem = await request.json();

  return reviewItem;
}

/*
 * Accept a pending review item
 */
async function lockReviewChecklists(checklistId) {
  let request = await fetch(
    `/n/api/v1/review/assignment/${checklistId}/progress`,
    {
      method: "PUT",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
    }
  );

  return request;
}

export {
  getReviewItems,
  returnReviewItem,
  acceptReviewItem,
  acceptAllReviewItem,
  checkIfReviewsPending,
  checkIfLastReviewPending,
  sendEmailNotification,
  getActionsPrompt,
  getCompanyAdmins,
  lockReviewChecklists,
  getReviewsPaginated,
};
