<script>
  import DocumentItemView from "../../components/ReviewHelpers/DocumentItemView.svelte";
  import RequestItemView from "../../components/ReviewHelpers/RequestItemView.svelte";
  import NavBar from "../../components/NavBar.svelte";
  import ReviewStatus from "../../components/ReviewStatus.svelte";
  import Button from "../../atomic/Button.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import ReturnModal from "Components/Requestor/Review/ReturnModal.svelte";
  import {
    getReviewItemsContents,
    returnReviewItem,
    acceptReviewItem,
    acceptAllReviewItem,
    checkIfLastReviewPending,
    getCompanyAdmins,
    getActionsPrompt,
  } from "BoilerplateAPI/Review";
  import { getChecklist } from "BoilerplateAPI/Checklist";
  import { getRecipient } from "BoilerplateAPI/Recipient";
  import { getTemplate } from "BoilerplateAPI/Template";
  import { getFileRequest } from "BoilerplateAPI/FileRequest";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";
  import RecipientTaskDescription from "Components/Recipient/RecipientTaskDescription.svelte";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import { featureEnabled } from "Helpers/Features";
  import {
    capitalizeFirstLetter,
    getValidUrlLink,
  } from "../../../helpers/util";
  import { archiveAssignment } from "BoilerplateAPI/Assignment";
  import {
    handleEmailSendEvent,
    assignPackage,
  } from "../../../helpers/ReviewActions";
  import ChooseChecklistModal from "../../modals/ChooseChecklistModal.svelte";
  import FormItemView from "../../components/ReviewHelpers/FormItemView.svelte";
  import { convertTime } from "Helpers/util";
  import { getChecklistDownloadUrl } from "../../../helpers/fileHelper";

  export let checklistId = 0;
  export let reviewItem = null;
  let reviewItemPromise = (async function () {
    let ri = await getReviewItemsContents(checklistId);
    let xy = await makeStuff(ri);
    reviewItem = xy;
    return xy;
  })();

  let track_document_expiration = true;

  let showTaskDetails = false;
  let taskToBeViewed = null;

  let showReturnModal = false;
  function returnIt() {
    showReturnModal = true;
  }

  let showTaskRejectConfirmationDialogBox = false;
  function handleTaskReturn(req) {
    const {
      has_confirmation_file_uploaded: hasConfirmationFileUploaded,
      task_confirmation_upload_doc_id: taskRequestConfirmationUploadDoc,
    } = req;
    if (!hasConfirmationFileUploaded) return returnIt();
    taskRequestConfirmationUploadId = taskRequestConfirmationUploadDoc;
    if (req.task_confirmation_upload_doc_id)
      return (showTaskRejectConfirmationDialogBox = true);
  }

  let requestId;

  let disableArchiveButtonOption = false;
  let companyAdmins = [];
  let actionsAfterReview = false;
  let showChecklistModal = false;
  let showAddEmailAddressBox = false;
  let showAcceptAllDialog = false;
  let dropdownValues;
  let showArchivePrompt = false;
  let isAcceptButtonStatus = false;
  let currentRequestItemId = "";
  let acceptReviews;

  const prepareForActionAfterReview = async () => {
    const { company_id: companyId } = reviewItem.requestor;
    const admins = await getCompanyAdmins(companyId);
    companyAdmins = admins;
    setTimeout(() => {
      actionsAfterReview = true;
    }, 100);
  };

  const handleNotifyMembers = () => {
    dropdownValues = companyAdmins;
    dropdownValues = dropdownValues.map((value) => ({
      ret: value.email,
      text: `${value.name} ${value.email}`,
    }));
    showAddEmailAddressBox = true;
    actionsAfterReview = false;
  };

  const processEmailSendEvent = (evt) => {
    const { text } = evt.detail;
    console.log(text);
    if (!text) {
      showToast("Choose emails", 1000, "error", "TM");
    } else {
      showAddEmailAddressBox = false;
      actionsAfterReview = true;
      return handleEmailSendEvent(text, reviewItem);
    }
  };

  async function acceptIt() {
    isAcceptButtonStatus = true;
    const { is_last_to_review, checklist_archived } =
      await checkIfLastReviewPending(reviewItem.assignment_id);
    acceptReviewItem({ id: requestId }, "request").then(async () => {
      disableArchiveButtonOption = checklist_archived;
      setTimeout(() => {
        isAcceptButtonStatus = false;
        currentRequestItemId = "";
      }, 1000);
      if (is_last_to_review) return prepareForActionAfterReview();
      else window.location.reload();
    });
  }

  async function makeStuff(item) {
    if (item == undefined || item.fully_reviewed) {
      window.location = "#reviews";
      return undefined;
    } else {
      let checklist = await getChecklist(item.checklist_id);
      let recipient = await getRecipient(item.recipient_id);

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

      return new_item;
    }
  }

  let showTaskConfirmationFileReviewDialog = false;
  let taskRequestConfirmationUploadId = null;

  const reviewTaskConfirmationFile = () => {
    window.location.href = `#review/${checklistId}/request/${taskRequestConfirmationUploadId}`;
  };

  const processTaskReview = (req) => {
    const {
      has_confirmation_file_uploaded: hasConfirmationFileUploaded,
      task_confirmation_upload_doc_id: taskRequestConfirmationUploadDoc,
    } = req;
    if (!hasConfirmationFileUploaded) return acceptIt();
    taskRequestConfirmationUploadId = taskRequestConfirmationUploadDoc;
    return (showTaskConfirmationFileReviewDialog = true);
  };

  const closeModal = () => {
    showReturnModal = false;
  };

  const sortRequests = (req) => {
    return req.sort((a, b) => a.name.localeCompare(b.name));
  };

  // Accept reviews
  const acceptAll = (data) => {
    showAcceptAllDialog = false;
    acceptAllReviewItem(data).then(() => {
      return prepareForActionAfterReview();
    });
  };
</script>

<div class="mobile-navbar">
  <NavBar
    backLink=" "
    backLinkHref="#reviews"
    navbar_spacer_classes="navbar_spacer_pb1"
    showCompanyLogo={false}
    middleText={reviewItem ? reviewItem.checklist.name : ""}
    middleSubText={reviewItem
      ? `${reviewItem.recipient.name}(${reviewItem.recipient.email})`
      : ""}
  />
</div>
<div class="desktop-navbar">
  <NavBar
    backLink=" "
    backLinkHref="#reviews"
    navbar_spacer_classes="navbar_spacer_pb1"
  >
    {#if reviewItem}
      <div class="information">
        <div style="margin-top: 3%;" class="content-information">
          <span style="font-weight: 600; font-size: 18px;" class="overflow-text"
            >{capitalizeFirstLetter(reviewItem.checklist.name)}</span
          >
          {#if reviewItem.recipient_description}
            <span
              class="overflow-text"
              style="margin: 0; padding: 0 0 0 5px; font-size: 16px;"
              >{"(" +
                capitalizeFirstLetter(reviewItem.recipient_description) +
                ")"}</span
            >
          {/if}
        </div>
        <div class="dates text-center">
          <p style="font-size: 16px; margin-top: 0.5rem;" class="name">
            <span>{capitalizeFirstLetter(reviewItem.recipient.name)}</span>
            {#if reviewItem.recipient.company}
              <span>{"(" + reviewItem.recipient.company + ")"}</span>
            {/if}
            <span class="desktop-only"
              >{"<" + reviewItem.recipient.email + ">"}</span
            >
          </p>
        </div>
      </div>
    {/if}
  </NavBar>
</div>

{#await reviewItemPromise then item}
  {#if item == undefined}
    <p>You are being redirected...</p>
  {:else}
    <div class="container">
      <section>
        <div class="flex justify-between">
          <div class="title">Items to be Reviewed</div>
          {#if featureEnabled("review_accept_all")}
            <div
              style="display: flex;
            width: 20%;
            align-content: flex-end;
            justify-content: end;
            "
            >
              <span
                style="margin-right: 1rem;"
                on:click={() => {
                  acceptReviews = [item];
                  showAcceptAllDialog = true;
                }}
              >
                <Button text="Accept All" color="secondary" />
              </span>
              <span
                on:click={() => {
                  window.location = getChecklistDownloadUrl(
                    4,
                    reviewItem.assignment_id
                  );
                }}
              >
                <Button text="Download All" color="secondary" />
              </span>
            </div>
          {/if}
        </div>
        <div class="table">
          <span class="desktop-only">
            <div class="tr th">
              <div class="td icon" />
              <div class="td th name">Document name</div>
              <div class="td desktop">Status</div>
              <div style="justify-content: center;" class="td">Actions</div>
            </div>
          </span>
          {#if item.documents.length > 0}
            {#each item.documents as document}
              <span class="desktop-only">
                <div class="tr">
                  <div class="td icon">
                    {#if document.is_rspec}
                      <FAIcon icon="file-user" iconStyle="solid" />
                    {:else}
                      <FAIcon icon="file-alt" iconStyle="regular" />
                    {/if}
                  </div>
                  <div
                    on:click={() => {
                      if (document.status == 2) {
                        window.location.href = `/reviewdocument/${document.id}/download/review`;
                      } else {
                        window.location.href = `#review/${checklistId}/document/${document.base_document_id}`;
                      }
                    }}
                    style="cursor: pointer;"
                    class="td name"
                  >
                    <div class="twoline">
                      <div class="line">
                        {document.full.name}
                      </div>
                      <div class="line">
                        {document.full.description}
                      </div>
                    </div>
                  </div>
                  <div class="td desktop">
                    <div>
                      <ReviewStatus status={document.status} />
                      <div class="submitted">
                        Submitted: {document.full?.upated_at ||
                          document.full.inserted_at}
                        {convertTime(
                          document.full?.upated_at || document.full.inserted_at,
                          document.full?.upated_time ||
                            document.full.inserted_time
                        )}
                      </div>
                    </div>
                  </div>
                  <div style="justify-content: center;" class="td">
                    {#if document.status == 2}
                      <a
                        href={`/reviewdocument/${document.id}/download/review`}
                      >
                        <Button color="gray" text="View" />
                      </a>
                    {:else}
                      <a
                        style="padding-right: 0.5rem;"
                        href={`#review/${checklistId}/document/${document.base_document_id}`}
                      >
                        <Button color="primary" text="Review" />
                      </a>
                    {/if}
                  </div>
                </div>
              </span>

              <span class="mobile-only">
                <DocumentItemView data={document} {checklistId} />
              </span>
            {/each}
          {/if}
          {#if item.requests.length > 0}
            {#each sortRequests(item.requests) as request}
              <span class="desktop-only">
                <div class="tr">
                  <div class="td icon">
                    {#if request.request_type == "file"}
                      <FAIcon icon="paperclip" iconStyle="regular" />
                    {:else if request.request_type == "data"}
                      <FAIcon icon="font-case" iconStyle="regular" />
                    {:else if request.request_type == "task"}
                      <FAIcon icon="thumbtack" iconStyle="regular" />
                    {/if}
                  </div>
                  <div
                    class="td name"
                    style="cursor: pointer;"
                    on:click={() => {
                      if (request.request_type == "file") {
                        if (request.status == 2) {
                          window.location.href = `/reviewrequest/${request.id}/download/review`;
                        } else {
                          window.location.href = `#review/${checklistId}/request/${request.request_id}`;
                        }
                      } else {
                        showTaskDetails = true;
                        taskToBeViewed = {
                          name: request.full.name,
                          type: request.request_type,
                          description: request.description,
                          link: request.link,
                        };
                      }
                    }}
                  >
                    <div class="twoline">
                      <div class="line truncate">
                        {request.full.name}
                      </div>
                      {#if request.request_type == "task"}
                        <RecipientTaskDescription
                          description={request.description}
                        />
                        {#if request.link && Object.keys(request.link).length !== 0 && request.link.url != ""}
                          <div
                            class="truncate"
                            style="font-style: normal;
                            font-weight: normal;
                            font-size: 12px;
                            line-height: 24px;
                            color: #76808b;
                            margin-top: 0px;"
                          >
                            <a
                              target="_blank"
                              href={getValidUrlLink(request.link.url)}
                            >
                              {request.link.url}
                            </a>
                          </div>
                        {/if}
                      {/if}
                      {#if request.request_type == "file"}
                        {#if request.status == 5}
                          <div class="line">
                            <div class="data-header">Unavailable -</div>
                            {request.return_reason}
                          </div>
                        {/if}
                      {:else if request.request_type == "data"}
                        <div class="line">
                          <div class="data-header">Contact input:</div>
                          <span
                            on:copy={() => {
                              showToast(
                                `Copied to clipboard.`,
                                1000,
                                "default",
                                "MM"
                              );
                            }}
                            style="cursor: auto;">{request.filename}</span
                          >
                        </div>
                      {/if}
                      <div class="mobile status">
                        <ReviewStatus status={request.status} />
                        <div class="submitted">
                          Submitted: {request.submitted}
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="td desktop">
                    <div>
                      <ReviewStatus status={request.status} />
                      <div class="submitted">
                        Submitted: {request.submitted}
                      </div>
                    </div>
                  </div>
                  <div style="justify-content: center;" class="td">
                    {#if request.request_type == "data" || request.status == 5}
                      <div style="padding-right: 0.5rem;" class="button-group">
                        <span
                          on:click={() => {
                            currentRequestItemId = request.id;
                            if (
                              !isAcceptButtonStatus &&
                              currentRequestItemId === request.id
                            ) {
                              requestId = request.id;
                              acceptIt();
                            }
                          }}
                        >
                          <Button
                            color="secondary"
                            text="Accept"
                            disabled={isAcceptButtonStatus &&
                              currentRequestItemId === request.id}
                          />
                        </span>
                        <span
                          on:click={() => {
                            requestId = request.id;
                            returnIt();
                          }}
                        >
                          <Button color="danger" text="Reject" />
                        </span>
                      </div>
                    {/if}
                    {#if request.request_type == "file" && request.status != 5}
                      {#if request.status == 2}
                        <a
                          href={`/reviewrequest/${request.id}/download/review`}
                        >
                          <Button color="gray" text="View" />
                        </a>
                      {:else if track_document_expiration}
                        <a
                          style="padding-right: 0.5rem;"
                          href={`#review/${checklistId}/request/${request.request_id}/Expiration`}
                        >
                          <Button color="primary" text="Review" />
                        </a>
                      {:else}
                        <a
                          style="padding-right: 0.5rem;"
                          href={`#review/${checklistId}/request/${request.request_id}`}
                        >
                          <Button color="primary" text="Review" />
                        </a>
                      {/if}
                    {/if}
                    {#if request.request_type == "task"}
                      <div class="button-group">
                        <span
                          on:click={() => {
                            requestId = request.id;
                            processTaskReview(request);
                          }}
                        >
                          <Button color="secondary" text="Accept" />
                        </span>
                        <span
                          on:click={() => {
                            requestId = request.id;
                            handleTaskReturn(request);
                          }}
                        >
                          <Button color="danger" text="Reject" />
                        </span>
                      </div>
                    {/if}
                  </div>
                </div>
              </span>

              <span class="mobile-only">
                <RequestItemView
                  data={request}
                  {checklistId}
                  {showToast}
                  {acceptIt}
                  {returnIt}
                  {handleTaskReturn}
                  {processTaskReview}
                  bind:requestId
                  on:showTaskDetails={({ detail: { itemData } }) => {
                    console.log(itemData);
                    if (itemData.request_type !== "data") {
                      showTaskDetails = true;
                    }
                    taskToBeViewed = {
                      name: itemData.full.name,
                      type: itemData.request_type,
                      description: itemData.description,
                      link: itemData.link,
                    };
                  }}
                />
              </span>
            {/each}
          {/if}
          {#if item.forms.length > 0}
            {#each item.forms as form}
              <span class="desktop-only">
                <div class="tr">
                  <div class="td icon">
                    <span
                      ><FAIcon
                        iconStyle="regular"
                        icon="rectangle-list"
                      /></span
                    >
                  </div>
                  <div
                    on:click={() => {
                      window.location.href = `#review/${checklistId}/form/${form.id}`;
                    }}
                    style="cursor: pointer;"
                    class="td name"
                  >
                    <div class="twoline">
                      <div class="line truncate">
                        {form.title}
                      </div>
                      <div class="line truncate">
                        {form.description}
                      </div>
                    </div>
                    <div class="mobile status">
                      <ReviewStatus status={form.status} />
                      <div class="submitted">
                        Submitted: {form.submitted}
                      </div>
                    </div>
                  </div>
                  <div class="td desktop">
                    <div>
                      <ReviewStatus status={form.status} />
                      <div class="submitted">
                        Submitted: {form.submitted}
                      </div>
                    </div>
                  </div>
                  <div style="justify-content: center;" class="td">
                    <a
                      style="padding-right: 0.5rem;"
                      href={`#review/${checklistId}/form/${form.id}`}
                    >
                      <Button color="primary" text="Review" />
                    </a>
                  </div>
                </div>
              </span>

              <span class="mobile-only">
                <FormItemView data={form} {checklistId} />
              </span>
            {/each}
          {/if}
        </div>
      </section>
    </div>
  {/if}
{:catch error}
  <p>Failed to load this review item: {error.name} / {error.message}</p>
{/await}

{#if showReturnModal}
  <ReturnModal
    maxWidth={"32rem"}
    {...{
      requestId,
      closeModal,
    }}
  />
{/if}

{#if showTaskDetails}
  <ConfirmationDialog
    title="Task Details"
    itemDisplay={taskToBeViewed}
    recipient={true}
    popUp={true}
    on:close={() => {
      showTaskDetails = false;
      taskToBeViewed = null;
    }}
  />
{/if}

{#if showTaskConfirmationFileReviewDialog}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`This task has task completion confirmation request uploaded`}
    yesText="Review, Confirmation"
    noText="Cancel"
    yesColor="secondary"
    noColor="white"
    on:yes={reviewTaskConfirmationFile}
    on:close={() => {
      showTaskConfirmationFileReviewDialog = false;
    }}
  />
{/if}

{#if showTaskRejectConfirmationDialogBox}
  <ConfirmationDialog
    title={"Warning!"}
    question={`This task has task completion confirmation request uploaded`}
    yesText="Review, Confirmation"
    noText="Cancel"
    yesColor="secondary"
    noColor="white"
    on:yes={reviewTaskConfirmationFile}
    on:close={() => {
      showTaskRejectConfirmationDialogBox = false;
    }}
  />
{/if}

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
      window.location.hash = `#recipient/${reviewItem.recipient_id}/details/data`;
      actionsAfterReview = false;
    }}
    on:close={() => {
      window.location.hash = "";
      window.location.hash = `#reviews`;
      actionsAfterReview = false;
    }}
    on:hide={() => {
      window.location.hash = "";
      window.location.hash = `#reviews`;
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
      window.open(`#recipient/${reviewItem.recipient_id}`, "_blank");
    }}
    on:download-all={() => {
      window.location = getChecklistDownloadUrl(4, reviewItem.assignment_id);
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
    on:message={processEmailSendEvent}
    on:yes={() => {}}
    on:close={() => {
      showAddEmailAddressBox = false;
      actionsAfterReview = true;
    }}
  />
{/if}

{#if showChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={(e) => assignPackage(e, reviewItem.recipient_id)}
    on:close={() => {
      showChecklistModal = false;
    }}
  />
{/if}

{#if showAcceptAllDialog}
  <ConfirmationDialog
    title="Attention!"
    question={`Are you sure you want to accept all? This will bypass individual reviews of these items and can’t be undone. Note that items requiring countersignatures will be skipped.`}
    yesText="Yes, Accept All"
    noText="Cancel"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      console.log("accept all");
      acceptAll(acceptReviews);
    }}
    on:close={() => {
      showAcceptAllDialog = false;
      taskToBeViewed = null;
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
      console.log(reviewItem);
      const { checklist, assignment_id } = reviewItem;
      disableArchiveButtonOption = true;
      archiveAssignment(assignment_id).then(() => {
        showToast(
          `Checklist "${checklist.name}" has been archived.`,
          1000,
          "default",
          "TM"
        );
      });
    }}
    on:close={() => {
      showArchivePrompt = false;
      actionsAfterReview = true;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  a {
    width: 250px;
    display: block;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  }
  .content-information {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: center;
  }

  .overflow-text {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: contents;
  }

  .information {
    font-family: "Lato", sans-serif;
    font-size: 20px;
    font-weight: 500;
    font-style: normal;
    /* line-height: 27px; */
    letter-spacing: 0.15px;
    color: #2a2f34;
  }

  /* return modal */
  a {
    text-decoration: none;
  }
  .data-header {
    display: inline;
    font-weight: 600;
    padding-right: 0.2rem;
    font-size: 13px;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .twoline {
    display: flex;
    flex-flow: column nowrap;
    width: 90%;
  }

  .twoline > .line:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #2a2f34;
  }

  .twoline > .line:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  /* table */
  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 0 auto;
    padding-top: 0.5rem;
  }

  .th {
    display: none;
  }

  .th > .td {
    white-space: normal;
    justify-content: left;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;

    height: 37px;
    align-items: center;
  }

  .tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding-top: 1rem;
    padding-bottom: 1rem;
  }

  .tr > .td:first-child {
    padding-left: 2rem;
  }

  .tr:not(.th) {
    margin-bottom: 0.4rem;
    height: 100%;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .td.name {
    flex-grow: 2.2;
  }

  .td.icon {
    flex-grow: 0;
    flex-basis: 40px;
    width: 60px;
    font-size: 24px;
    color: #7e858e;
  }

  .button-group {
    display: flex;
    align-items: center;
  }

  .button-group span:first-child {
    margin-right: 0.7rem;
  }

  .submitted {
    font-size: 14px;
    margin-top: 0.5rem;
  }

  /* X */
  section {
    margin: 1rem 0;
  }
  .title {
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 28px;
    color: #4a5158;
  }

  .container {
    padding: 1.5rem;
  }

  .mobile-navbar {
    display: none;
  }
  .mobile-only {
    display: none;
  }
  @media only screen and (max-width: 1024px) {
    .overflow-text {
      width: 90%;
    }
    .information {
      width: 100%;
      flex-direction: column;
    }
  }

  /* mobile styles */
  @media only screen and (min-width: 650px) {
    .mobile {
      display: none;
    }
  }
  @media only screen and (max-width: 767px) {
    .information {
      font-size: 16px;
      line-height: 22px;
    }

    .button-group {
      flex-direction: column;
    }
    .button-group span:first-child {
      margin-bottom: 1rem;
      margin-right: 0;
    }
    .desktop-navbar {
      display: none;
    }
    .mobile-navbar {
      display: block;
    }
    .container {
      padding: 0 0.5rem;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
  }

  @media only screen and (max-width: 650px) {
    .desktop {
      display: none;
    }
    .td.name {
      flex-grow: 1;
      flex-direction: column;
      padding-right: 15px;
    }
    .td.th.name {
      flex-direction: row;
    }
    .mobile.status {
      border-top: 0.5px solid #b3c1d0;
      margin-top: 5px;
      padding-top: 5px;
    }

    .title {
      font-size: 18px;
      line-height: 20px;
    }
  }

  @media only screen and (max-width: 767px) {
    .container {
      padding: 0 0.5rem;
    }
  }

  @media only screen and (max-width: 330px) {
    .tr:not(.th) {
      margin-bottom: 1.5rem;
      height: 100%;
      width: 275px;
    }
  }
</style>
