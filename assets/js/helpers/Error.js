import OopsModal from "../ui/modals/OopsModal.svelte";
import FatalError from "../ui/pages/errors/FatalError.svelte";

let common_errors = {
  forbidden: "You do not have access to this resource.",
};

let template_errors = {
  contained_in_package:
    "This template is currently part of a checklist and thus cannot be deleted until removed from the checklist.",
};

let recipient_errors = {
  invalid_invitation:
    "Failed to add the recipient, maybe the email address field is malformed or their name is missing?",
  bad_data:
    "Failed to add the recipient, maybe the email address field is malformed or their name is missing?",
  assigned_packages:
    "This recipient currently has a checklist assigned and cannot be removed until that assignment is archived or deleted.",
  duplicate_email: "This email address is already present in the system.",
};

let pdf_render_error = {
  generic: "Failed to load PDF file",
};

let checklist_errors = {
  already_assigned:
    "This checklist is currently assigned to a recipient and thus cannot be deleted until the assignment is rescinded or achived.",
  intake_with_rsds:
    "This checklist contains documentation that has to be customized for the recipient. Therefore, it is not possible to create an Intake Link for this Checklist.",
};

let iac_errors = {
  invalid_state: "Cannot add a field to a form that isn't a master form.",
  oops: "Couldn't add this field.",
};

let user_errors = {
  email: "Invalid email address",
  password: "Invalid Password",
  name: "Invalid Name field",
  mfa_mandate:
    "Multi-factor user authentication is required for security purposes in your organization. Please contact support@boilerplate.co for questions and exemptions.",
};

let iac_ses_errors = {
  review_first:
    "Please review the checklist on the Review tab before attempting to Export to a Document",
};

let handlers = {
  template: template_errors,
  recipient: recipient_errors,
  checklist: checklist_errors,
  iac: iac_errors,
  iac_ses: iac_ses_errors,
  userErrors: user_errors,
  pdfRenderError: pdf_render_error,
};

let fatal_errors = {
  no_recipient_account: {
    icon: "exclamation-triangle",
    title: "Restricted Access",
    message:
      "This resource is currently not available to you because your account is not a Recipient at any company.",
  },
  no_requestor_account: {
    icon: "exclamation-triangle",
    title: "Restricted Access",
    message:
      "This resource is currently not available to you because your account is not a Requestor at any company.",
  },
};

function doError(title, message) {
  if (message == undefined) {
    message = "Undefined error occured.";
  }

  console.log(`ERROR: title="${title}" message="${message}"`);

  new OopsModal({
    target: document.getElementById("boilerplate-error-container"),
    props: {
      title: title,
      message: message,
    },
  });
}

export function showErrorMessage(host, error_code) {
  console.log(`ERROR(raw): host=${host} error_code=${error_code}`);
  if (error_code in common_errors) {
    doError("Oops!", common_errors[error_code]);
  } else {
    doError("Oops!", handlers[host][error_code]);
  }
}

/* Fatal errors display a full screen error */
export function showFatalError(host, error_code) {
  console.log(
    `FATAL ERROR(raw): host=${host} error_code=${error_code} logged=false`
  );

  let props = fatal_errors[error_code];
  let fromRequestor = true;
  let target = document.getElementById("stormwind-base-container");
  if (target) {
    fromRequestor = false;
  } else {
    target = document.getElementById("ironforge-base-container");
  }

  props.fromRequestor = fromRequestor;

  // try to reset as much as possible
  target.innerHTML = "";

  new FatalError({
    target: target,
    props: props,
  });
}
