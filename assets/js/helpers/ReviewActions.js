import { sendEmailNotification } from "BoilerplateAPI/Review";
import { showToast } from "Helpers/ToastStorage.js";
import { VALIDEMAILFORMAT } from "Helpers/util";

export const processEmailNotification = async (
  emailAddress,
  { assignment_id }
) => {
  let reply = await sendEmailNotification({
    emailAddress,
    assignment_id,
  });
  // TODO: Remove this after email notification integration
  if (reply.status) {
    showToast(
      `<<${emailAddress}>> is notified that the checklist has been completed`,
      2000,
      "default",
      "TM"
    );
  } else {
    showToast(
      `Error! Error sending Checklist completion notiification for <<${emailAddress}>>`,
      2000,
      "error",
      "TM"
    );
  }
};

export const handleEmailSendEvent = async (email, reviewItem) => {
  const isValidEmail = email.match(VALIDEMAILFORMAT);
  if (isValidEmail) {
    return await processEmailNotification(email, reviewItem);
  } else {
    showToast(`Invalid Email format`, 1500, "warning", "TM");
  }
};

export function assignPackage(evt, id) {
  let detail = evt.detail;
  let packageId = detail.checklistId;
  let recipient_id = id;

  window.location.hash = `#recipient/${recipient_id}/assign/${packageId}`;
}
