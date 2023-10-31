<script>
  import IacFill from "./IacFill.svelte";
  import {
    getReviewItems,
    acceptReviewItem,
    checkIfLastReviewPending,
    getActionsPrompt,
    getCompanyAdmins,
    REVIEW_AUTO_DOWNLOAD_KEY,
  } from "BoilerplateAPI/Review";
  import { getChecklist } from "BoilerplateAPI/Checklist";
  import { getRecipient } from "BoilerplateAPI/Recipient";
  import { getTemplate } from "BoilerplateAPI/Template";
  import { getFileRequest } from "BoilerplateAPI/FileRequest";
  import { navigateToNextItem } from "Helpers/Requester/ReviewOne";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage.js";
  import ToastBar from "Atomic/ToastBar.svelte";
  import { VALIDEMAILFORMAT, fileDownloader } from "Helpers/util";
  import { archiveAssignment } from "BoilerplateAPI/Assignment";
  import ChooseChecklistModal from "../modals/ChooseChecklistModal.svelte";
  import {
    processEmailNotification,
    assignPackage,
  } from "Helpers/ReviewActions";

  import ProgressTab from "../components/ProgressTab.svelte";
  import { getChecklistDownloadUrl } from "../../helpers/fileHelper";

  export let reviewType;
  export let checklistId;
  export let itemId;
  let item = null;
  let nextItemAvailable = false;
  let theReview = null;
  let companyId;

  let contents_id;
  let recipient_id;
  let actionsAfterReview = false;
  let showArchivePrompt = false;
  let disableArchiveButtonOption = false;
  let showAddEmailAddressBox = false;
  let showChecklistModal = false;

  const handleEmailSendEvent = (evt) => {
    const { text } = evt.detail;
    const isValidEmail = text.match(VALIDEMAILFORMAT);
    showAddEmailAddressBox = false;
    actionsAfterReview = true;
    if (isValidEmail) {
      processEmailNotification(text, item);
    } else {
      showToast(`Invalid Email format`, 1000, "warning", "TM");
    }
  };

  let reviewItemPromise = getReviewItems().then(async (items) => {
    item = items.find((x) => x.contents_id == checklistId);
    let checklist = await getChecklist(item.checklist_id);
    let recipient = await getRecipient(item.recipient_id);
    companyId = item?.requestor?.company_id;
    recipient_id = recipient.id;

    let { documents, requests: reqs } = item;
    const requests = reqs.filter((req) => !req.has_confirmation_file_uploaded);
    const itemsLeftCount = documents.length + requests.length - 1; // in any case 1 item has been reviewed
    nextItemAvailable = itemsLeftCount !== 0;

    let new_item = item;
    new_item.checklist = checklist;
    new_item.recipient = recipient;

    let new_documents = [];
    for (const doc of item.documents) {
      let fullDoc = await getTemplate(doc.base_document_id, "requestor");
      doc.full = fullDoc;
      new_documents.push(doc);
    }
    new_item.documents = new_documents;

    let new_requests = [];
    for (const req of item.requests) {
      let fullRequest = await getFileRequest(req.request_id);
      req.full = fullRequest;
      new_requests.push(req);
    }
    new_item.requests = new_requests;

    if (reviewType == "document") {
      theReview = new_item.documents.find((x) => x.base_document_id == itemId);
    } else if (reviewType == "request") {
      theReview = new_item.requests.find((x) => x.request_id == itemId);
    }
    return theReview;
  });

  const getNewReviewItem = async () => {
    let newReviewItem = {};

    const items = await getReviewItems();
    item = items.find((x) => x.contents_id == checklistId);
    const { documents, requests } = item;

    if (reviewType == "document") {
      newReviewItem = documents.find((x) => x.base_document_id == itemId);
    } else if (reviewType == "request") {
      newReviewItem = requests.find((x) => x.request_id == itemId);
    }
    return newReviewItem;
  };

  let dropdownValues;
  const handleNotifyMembers = () => {
    dropdownValues = companyAdmins;
    dropdownValues = dropdownValues.map((value) => ({
      ret: value.email,
      text: `${value.name} ${value.email}`,
    }));
    showAddEmailAddressBox = true;
    actionsAfterReview = false;
  };

  let companyAdmins = [];
  const prepareForActionAfterReview = async () => {
    const admins = await getCompanyAdmins(companyId);
    companyAdmins = admins;
    actionsAfterReview = true;
  };
  const handleReviewDownload = async (review) => {
    if (reviewType === "form") {
      handleDownloadCSV(review);
      return;
    }
    const res = await fetch(
      `/review${reviewType}/${review.id}/download/review`
    );
    const filename = res.headers
      .get("Content-Disposition")
      .match(/filename="(.+)"/)[1]
      .replaceAll("-review-", "-completed-");
    const blob = await res.blob();
    fileDownloader(blob, filename);
  };
  let autoDownloadEnabled =
    localStorage.getItem(REVIEW_AUTO_DOWNLOAD_KEY) == "yes";

  async function acceptIt() {
    // since this is called after finish, id increments by one for newer version
    const newReviewItem = await getNewReviewItem();
    const { is_last_to_review, checklist_archived } = !nextItemAvailable
      ? await checkIfLastReviewPending(item.assignment_id)
      : {};
    disableArchiveButtonOption = checklist_archived;
    if (autoDownloadEnabled) {
      await handleReviewDownload(newReviewItem);
    }
    acceptReviewItem(newReviewItem, reviewType).then(() => {
      if (nextItemAvailable) handleAcceptNext();
      else if (is_last_to_review) {
        // This is a hack to handle error if any page reload occurs while actions after review
        // replaces the url with the review checklist screen and if any page reload occurs gracefully routes the user to review screen
        // this is a terrible hack :-D, feel free to refactor ...
        history.replaceState({}, "", `#review/${checklistId}`);
        if (is_last_to_review) return prepareForActionAfterReview();
      } else {
        window.location.hash = `#review/${checklistId}`;
      }
    });
  }
  const handleAcceptNext = () => {
    navigateToNextItem({ item, checklistId, reviewType, itemId });
  };
</script>

{#await reviewItemPromise}
  <p>Loading...</p>
{:then item}
  <div class="progress-tab">
    <ProgressTab
      elements={[
        "Submission received",
        "Accept or reject portion filled by other party",
        "Fill your portion/ countersign",
      ]}
      current={2}
    />
  </div>
  <IacFill
    iacDocId={item.iac_doc_id}
    fillType={"review"}
    contentsId={item.contents_id}
    assignmentId={item.assignment_id}
    recipientId={item.recipient_id}
    finishCallback={acceptIt}
  />
{/await}

{#if actionsAfterReview}
  <ConfirmationDialog
    title="Checklist complete"
    question="What would you like to do next?"
    hideText="I'm done, thanks"
    hideColor="white"
    actionsColor="black"
    actions={getActionsPrompt({ disableArchiveButtonOption, hasLabels: true })}
    on:datatab={() => {
      window.location.hash = "";
      window.location.hash = `#recipient/${item.recipient_id}/details/data`;
      actionsAfterReview = false;
    }}
    on:close={() => {
      window.location.hash = "";
      window.location.hash = `#review/${checklistId}`;
      actionsAfterReview = false;
    }}
    on:hide={() => {
      window.location.hash = "";
      window.location.hash = `#review/${checklistId}`;
      actionsAfterReview = false;
    }}
    on:send={() => {
      showChecklistModal = true;
    }}
    on:notify={() => {
      handleNotifyMembers();
    }}
    on:archive={() => {
      actionsAfterReview = false;
      showArchivePrompt = true;
    }}
    on:viewChecklist={() => {
      theReview.recipient;
      window.open(`#recipient/${item.recipient_id}`, "_blank");
    }}
    on:download-all={() => {
      window.location = getChecklistDownloadUrl(4, item.assignment_id);
    }}
  />
{/if}

{#if showAddEmailAddressBox}
  <ConfirmationDialog
    question={`Email the checklist`}
    dropdownEnable="true"
    {dropdownValues}
    dropdownName="Choose Member"
    requiresResponse={true}
    yesText="Send, Email"
    noText="No, Cancel"
    yesColor="primary"
    noColor="white"
    on:message={handleEmailSendEvent}
    on:yes={() => {}}
    on:close={() => {
      showAddEmailAddressBox = false;
      actionsAfterReview = true;
    }}
  />
{/if}

{#if showArchivePrompt}
  <ConfirmationDialog
    question={`Archiving this checklist will make it disappear from the dashboard. You'll still be able to access in Contact Details. Proceed with archive?`}
    yesText="Yes, archive"
    noText="Cancel"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      showArchivePrompt = false;
      actionsAfterReview = true;
      const { checklist, assignment_id } = item;
      disableArchiveButtonOption = true;
      archiveAssignment(assignment_id).then(() => {
        showToast(`Checklist has been archived.`, 1000, "default", "TM");
      });
    }}
    on:close={() => {
      showArchivePrompt = false;
      actionsAfterReview = true;
    }}
  />
{/if}

{#if showChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={(e) => assignPackage(e, item.recipient_id)}
    on:close={() => {
      showChecklistModal = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .progress-tab {
    display: none;
  }
  @media only screen and (min-width: 768px) {
    .progress-tab {
      margin: 80px 16px 0 16px;

      display: flex;
      flex-flow: row nowrap;
      justify-content: center;
    }
  }
</style>
