<script>
  import { getFormSubmission, handleDownloadCSV } from "BoilerplateAPI/Form";
  import { onMount } from "svelte";
  import NavBar from "../../components/NavBar.svelte";
  import BottomBar from "../../components/BottomBar.svelte";
  import Loader from "../../components/Loader.svelte";
  import PageNavigation from "../../components/PageNavigation.svelte";
  import PdfViewer from "../../content/PdfViewer.svelte";
  import Modal from "../../components/Modal.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Button from "../../atomic/Button.svelte";
  import {
    getReviewItemsContents,
    acceptReviewItem,
    checkIfLastReviewPending,
    getActionsPrompt,
    getCompanyAdmins,
    lockReviewChecklists,
    REVIEW_AUTO_DOWNLOAD_KEY,
  } from "BoilerplateAPI/Review";
  import { getChecklist } from "BoilerplateAPI/Checklist";
  import { getRecipient } from "BoilerplateAPI/Recipient";
  import { getTemplate } from "BoilerplateAPI/Template";
  import { getFileRequest } from "BoilerplateAPI/FileRequest";
  import ReturnModal from "Components/Requestor/Review/ReturnModal.svelte";
  import printJS from "print-js";
  import { isImage } from "Helpers/fileHelper";
  import { getCompanyInfo } from "BoilerplateAPI/Features";
  import ImageReview from "../../components/ImageReview.svelte";
  import { navigateToNextItem } from "Helpers/Requester/ReviewOne";
  import {
    processEmailNotification,
    assignPackage,
  } from "Helpers/ReviewActions";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage.js";
  import ToastBar from "Atomic/ToastBar.svelte";
  import {
    isBrowserTypeSafari,
    capitalizeFirstLetter,
    VALIDEMAILFORMAT,
    fileDownloader,
  } from "Helpers/util";
  import { isMobile, isNullOrUndefined } from "../../../helpers/util";
  import SwipeWrapper from "../../components/SwipeWrapper.svelte";
  import { archiveAssignment } from "BoilerplateAPI/Assignment";
  import ChooseChecklistModal from "../../modals/ChooseChecklistModal.svelte";
  import FormRenderer from "../../components/Form/FormRenderer.svelte";
  import AddExpirationDate from "../../components/AddExpirationDate.svelte";
  import { requestExpirationInfo } from "BoilerplateAPI/RecipientPortal";
  import dayjs from "dayjs";
  import ProgressTab from "../../components/ProgressTab.svelte";
  import { getChecklistDownloadUrl } from "../../../helpers/fileHelper";
  import Switch from "../../components/Switch.svelte";
  import { getIACFillChannel } from "../../../webChannels";
  import { isRecipientInFillMode } from "../../../store";

  export let checklistId;
  export let reviewType;
  export let itemId;

  let theReview;
  let pdfView;
  let itemLoaded = false;
  let showReturnModal = false;
  let hasReviewFill = false;
  let singlePage = true;
  let lastPage = false;
  let firstPage = true;
  let pageLoading = false;
  let pdfRendered = false;
  let reviewFillPopup = false;
  let item = null;
  let nextItemAvailable = false;
  const isSafari = isBrowserTypeSafari();
  let actionsAfterReview = false;
  let showArchivePrompt = false;
  let disableArchiveButtonOption = false;
  let showAddEmailAddressBox = false;
  let recipient_id;
  let showChecklistModal = false;
  let companyId;
  let dropdownValues;
  let currentPage, pageCount;
  let showFillModal = false;
  let showEditDataModal = false;
  let showExportInfoModal = false;
  let exportSpEnabled = true;
  let exportSpName = "Box";
  let exportSpTemplate = "/Boilerplate Uploads/Employees/2023/Levente Kurusa";
  let requestorChannel;
  let disableRequestorReviewProcess = false;
  let showRefereshButton = false;

  let now = new Date(),
    month,
    day,
    year;
  onMount(() => {
    (month = "" + (now.getMonth() + 1)),
      (day = "" + now.getDate()),
      (year = now.getFullYear());

    if (month.length < 2) month = "0" + month;
    if (day.length < 2) day = "0" + day;
  });

  function requestorChannelConnect(fillId, fillType) {
    requestorChannel = getIACFillChannel(fillId, {
      fillType,
    });

    requestorChannel.on("recipient_fill_complete", () => {
      showRefereshButton = true;
      disableRequestorReviewProcess = false;
    });
  }

  const getExportInfo = async () => {
    let info = await getCompanyInfo();
    autoExportEnabled = info.storage_providers.permanent.auto_export;
    exportSpEnabled = info.storage_providers.permanent.type != "s3";
    exportSpName =
      info.storage_providers.permanent.type == "gdrive"
        ? "Google Drive"
        : info.storage_providers.permanent.type == "box"
        ? "Box"
        : "N/A";
    exportSpTemplate = info.storage_providers.permanent.path_template;
    let full_name = item?.recipient?.name;
    let current_date = new Date();
    let year = current_date.getFullYear();
    let month = current_date.getMonth() + 1;
    let day = current_date.getDate();
    let checklist = "WIP";
    console.log({ full_name });

    exportSpTemplate = exportSpTemplate
      .replaceAll("$FULLNAME", full_name)
      .replaceAll("$YEAR", year)
      .replaceAll("$MONTH", month)
      .replaceAll("$DAY", day)
      .replaceAll("$CHECKLIST", checklist);
  };

  const handleEmailSendEvent = (evt) => {
    const { text } = evt.detail;
    const isValidEmail = text.match(VALIDEMAILFORMAT);
    showAddEmailAddressBox = false;
    actionsAfterReview = true;
    if (isValidEmail) {
      processEmailNotification(text, item);
    } else {
      showToast(`Invalid Email format`, 1500, "warning", "TM");
    }
  };
  let isExpirationTrackingEnabled = false;
  let expirationValue;
  let errorLoadingPDF = false;

  let reviewItemPromise = getReviewItemsContents(checklistId).then(
    async (_item) => {
      item = _item;
      let checklist = await getChecklist(item.checklist_id);
      let recipient = await getRecipient(item.recipient_id);
      companyId = item?.requestor?.company_id;
      recipient_id = recipient.id;
      let { documents, requests: reqs, forms } = item;
      const requests = reqs.filter(
        (req) => !req.has_confirmation_file_uploaded
      );
      const itemsLeftCount =
        documents.length + requests.length + forms.length - 1; // in any case 1 item has been reviewed
      nextItemAvailable = itemsLeftCount !== 0;
      let new_item = item;
      new_item.checklist = checklist;
      new_item.recipient = recipient;

      let new_documents = [];
      for (const doc of documents) {
        let fullDoc = await getTemplate(doc.base_document_id, "requestor");
        doc.full = fullDoc;
        new_documents.push(doc);
      }
      new_item.documents = new_documents;

      let new_requests = [];
      for (const req of requests) {
        let fullRequest = await getFileRequest(req.request_id);
        req.full = fullRequest;
        new_requests.push(req);
      }
      new_item.requests = new_requests;

      if (reviewType == "document") {
        theReview = new_item.documents.find(
          (x) => x.base_document_id == itemId
        );
        onReviewProcess(theReview);
      } else if (reviewType == "request") {
        theReview = new_item.requests.find((x) => x.request_id == itemId);
      } else if (reviewType == "form") {
        const { assignment_id } = new_item;
        theReview = await getFormSubmission(assignment_id, itemId);
        if (theReview.status == 3) {
          window.location.hash = `#review/${checklistId}`;
        }
        setItemLoaded(true);
      }
      theReview["recipient_description"] = new_item["recipient_description"];
      // theReview - status - 5 - missing
      // request cannot be displayed
      // request is type data
      const cannotBeDisplayed =
        reviewType == "form"
          ? false
          : !theReview.filename.endsWith(".pdf") ||
            !isImage(theReview.filename);
      if (
        theReview.status === 5 ||
        cannotBeDisplayed ||
        theReview.request_type === "data"
      )
        setItemLoaded(true);

      isExpirationTrackingEnabled = theReview.is_enabled_tracking || false;
      if (isExpirationTrackingEnabled) {
        const { value } = theReview.doc_expiration_info;
        expirationValue = value || "Not set";
      }

      if (theReview.allow_edits) {
        let preference = localStorage.getItem("reviewFillPopup");
        hasReviewFill = true;
        if (preference !== "yes") reviewFillPopup = true;
      }
      console.log({
        theReview,
      });
      if (!isNullOrUndefined(theReview.iac_assigned_form_id)) {
        requestorChannelConnect(theReview.iac_assigned_form_id, "review");
      }

      return new_item;
    }
  );

  function returnIt() {
    showReturnModal = true;
  }

  let windowInnerWidth, elmWidth;
  onMount(() => {
    windowInnerWidth = window.innerWidth;
  });

  let showTaskAcceptConfirmationDialogBox = false;
  const handleAcceptItem = async () => {
    if (
      autoDownloadEnabled &&
      hasReviewFill == false &&
      theReview.status !== 5
    ) {
      await handleReviewDownload();
    }
    if (theReview.is_task_confirmation_file_upload)
      return (showTaskAcceptConfirmationDialogBox = true);
    acceptIt();
  };

  async function acceptIt() {
    if (hasReviewFill) {
      editIt();
      return;
    }
    // before accepting, check if the reviewing item is last to review
    const { is_last_to_review, checklist_archived } = !nextItemAvailable
      ? await checkIfLastReviewPending(item.assignment_id)
      : {};

    const acceptItem = {
      id: reviewType === "form" ? theReview.submission_id : theReview.id,
      export:
        autoExportEnabled == true
          ? "yes"
          : autoExportEnabled == false
          ? "no"
          : "default",
      type: reviewType,
    };

    acceptReviewItem(acceptItem, reviewType).then(async () => {
      if (nextItemAvailable) handleAcceptNext();
      if (is_last_to_review) {
        disableArchiveButtonOption = checklist_archived || false;
        // This is a hack to handle error if any page reload occurs while actions after review
        // replaces the url with the review checklist screen and if any page reload occurs gracefully routes the user to review screen
        // this is a terrible hack :-D, feel free to refactor ...
        history.replaceState({}, "", `#review/${checklistId}`);
        return prepareForActionAfterReview();
      } else {
        window.location.hash = `#review/${checklistId}`;
      }
    });
  }

  function editIt() {
    window.location.hash = `${window.location.hash}/edit`;
  }

  const closeModal = () => {
    showReturnModal = false;
  };

  const handleAcceptNext = () => {
    navigateToNextItem({ item, checklistId, reviewType, itemId });
  };

  const setItemLoaded = (value) => {
    itemLoaded = value;
  };

  console.log(
    `IF/ReviewOne: checklistId=${checklistId} reviewType=${reviewType} itemId=${itemId}`
  );

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
    setTimeout(() => {
      actionsAfterReview = true;
    }, 100);
  };

  const onReviewProcess = (doc) => {
    lockReviewChecklists(doc.assignment_id);
  };

  $: pdfPageNavigationLeft = (windowInnerWidth - elmWidth) / 2 - 15;
  let showAddExpirationPopUp = false;

  const handleEditExpirationInfo = async (
    id,
    newExpiration,
    currentExpirationInfo
  ) => {
    if (
      currentExpirationInfo.type === newExpiration.type &&
      newExpiration.value === currentExpirationInfo.value
    ) {
      showToast("Nothing to update", 1000, "warning", "MM");
    } else {
      const reply = await requestExpirationInfo(id, newExpiration);
      if (reply.ok) {
        showToast(
          "Document expiration succesfully edited",
          1500,
          "default",
          "MM"
        );
        expirationValue = newExpiration.value;
        // update the expiration for review
        theReview.doc_expiration_info = newExpiration;
      } else {
        showToast(
          "Error while updating expiration Information",
          1500,
          "error",
          "MM"
        );
      }
    }
    return;
  };

  let autoDownloadEnabled =
    localStorage.getItem(REVIEW_AUTO_DOWNLOAD_KEY) == "yes";
  let autoExportEnabled = null;

  $: {
    const value = autoDownloadEnabled ? "yes" : "";
    localStorage.setItem(REVIEW_AUTO_DOWNLOAD_KEY, value);
  }

  const handleReviewDownload = async () => {
    if (reviewType === "request" && theReview.request_type !== "file") return;
    if (reviewType === "form") {
      handleDownloadCSV(theReview);
      return;
    }

    const res = await fetch(
      `/review${reviewType}/${theReview.id}/download/review`
    );
    const filename = res.headers
      .get("Content-Disposition")
      .match(/filename="(.+)"/)[1]
      .replaceAll("-review-", "-completed-");
    const blob = await res.blob();
    fileDownloader(blob, filename);
  };

  $: {
    disableRequestorReviewProcess = $isRecipientInFillMode;
    window.temp_disable_review_fill = disableRequestorReviewProcess;
  }
</script>

<div class="mobile-only">
  {#if item && (theReview?.full?.name || theReview?.title)}
    <NavBar
      navbar_spacer_classes="navbar_spacer_pb1_desktop navbar_spacer_pb1"
      middleText={`${capitalizeFirstLetter(
        theReview?.full?.name
      )} (${capitalizeFirstLetter(theReview?.recipient_description || "-")})`}
      middleSubText={item.recipient
        ? `${capitalizeFirstLetter(item.recipient.name)}(${
            item.recipient.email
          })`
        : ""}
      backLink=" "
      backLinkHref={`#review/${checklistId}`}
    />
  {/if}
  <NavBar
    navbar_spacer_classes="navbar_spacer_pb1_desktop"
    backLink=" "
    backLinkHref={`#review/${checklistId}`}
  >
    {#if item && (theReview?.full?.name || theReview?.title)}
      <div class="information">
        <div class="content-information">
          <span
            style="font-weight: 600; font-size: 18px;"
            class="overflow-text"
          >
            {capitalizeFirstLetter(
              theReview?.full?.name || theReview?.title || ""
            )}
          </span>
          <span
            class="overflow-text"
            style="margin: 0; padding: 0 0 0 5px; font-size: 16px;"
          >
            {"(" +
              capitalizeFirstLetter(theReview?.recipient_description || "") +
              ")"}
          </span>
        </div>
        <div class="dates text-center">
          <p class="user-info">
            <span>{capitalizeFirstLetter(item.recipient.name) || ""}</span>
            <span>{"(" + item.recipient.company + ")"}</span>
            <span>{"<" + item.recipient.email + ">"}</span>
          </p>
        </div>
      </div>
    {/if}
  </NavBar>
</div>

<div class="desktop-only">
  <NavBar
    navbar_spacer_classes="navbar_spacer_pb1_desktop"
    backLink=" "
    backLinkHref={`#review/${checklistId}`}
  >
    {#if item && (theReview?.full?.name || theReview?.title)}
      <div class="information">
        <div class="content-information">
          <span
            style="font-weight: 600; font-size: 18px;"
            class="overflow-text"
          >
            {capitalizeFirstLetter(theReview?.full?.name || theReview?.title)}
          </span>
          {#if theReview.recipient_description}
            <span
              class="overflow-text"
              style="margin: 0; padding: 0 0 0 5px; font-size: 16px;"
            >
              {"(" +
                capitalizeFirstLetter(theReview?.recipient_description) +
                ")"}
            </span>
          {/if}
        </div>
        <div class="dates">
          <p style="font-size: 16px; margin-top: 0.3rem;" class="name">
            <span>{capitalizeFirstLetter(item.recipient.name)}</span>
            <span>{"(" + item.recipient.company + ")"}</span>
            <span class="desktop-only">{"<" + item.recipient.email + ">"}</span>
          </p>
        </div>
      </div>
    {/if}
  </NavBar>
</div>

<div
  style={reviewType === "request" &&
    theReview?.request_type === "data" &&
    "margin-bottom: 0px;"}
  class="container"
>
  {#if pageLoading}
    <Loader loading />
  {/if}
  {#await reviewItemPromise then item}
    <!-- If this is a pdf file that containing a counter-signature portions then we are showing following progress bar -->
    {#if hasReviewFill}
      <div class="progress-tab">
        <ProgressTab
          elements={[
            "Submission received",
            "Accept or reject portion filled by other party",
            "Fill your portion/ countersign",
          ]}
          current={1}
        />
      </div>
    {/if}
    <div class="preamble">
      <div class="content">
        {#if theReview?.id}
          {#if reviewType === "form"}
            <div class="form-content">
              <FormRenderer isRequestorReview={true} form={theReview} />
            </div>
          {:else if theReview.filename.endsWith(".pdf")}
            <SwipeWrapper
              on:swipeLeft={() => {
                if (!singlePage || !lastPage) {
                  pageLoading = true;
                  setTimeout(() => {
                    pdfView.nextPage();
                    pageLoading = false;
                  }, 200);
                }
              }}
              on:swipeRight={() => {
                if (!singlePage || !firstPage) {
                  pageLoading = true;
                  setTimeout(() => {
                    pdfView.prevPage();
                    pageLoading = false;
                  }, 200);
                }
              }}
            >
              <div class="pdf" class:hidden={pageLoading}>
                <PageNavigation
                  firstPage={firstPage || singlePage}
                  lastPage={lastPage || singlePage}
                  pageLoading={!pdfRendered || pageLoading}
                  on:doPrevPage={() => {
                    pageLoading = true;
                    setTimeout(() => {
                      pdfView.prevPage();
                      pageLoading = false;
                    }, 200);
                  }}
                  on:doNextPage={() => {
                    pageLoading = true;
                    setTimeout(() => {
                      pdfView.nextPage();
                      pageLoading = false;
                    }, 200);
                  }}
                />

                <PdfViewer
                  bind:this={pdfView}
                  bind:singlePage
                  bind:lastPage
                  bind:firstPage
                  bind:currentPage
                  bind:pageCount
                  bind:pdfRendered
                  url={`/review${reviewType}/${theReview.id}/download/review`}
                  on:downloadFile={handleReviewDownload}
                  on:pdfException={() => (errorLoadingPDF = true)}
                  {setItemLoaded}
                  {itemLoaded}
                />
              </div>
            </SwipeWrapper>
          {:else if isImage(theReview.filename)}
            <ImageReview
              {theReview}
              {reviewType}
              on:loaded={() => {
                setItemLoaded(true);
              }}
            />
          {:else if reviewType === "request" && theReview.request_type === "data"}
            <div class="data">
              <div>
                <h3>Data requested:</h3>
                <p>
                  {theReview?.full?.name}
                </p>
                <h3>Data submitted:</h3>
                <p>
                  {theReview.filename}
                </p>
              </div>
            </div>
          {:else if reviewType === "request" && theReview.request_type === "task"}
            <div class="task">
              <div class="task_details">
                <span class="task_sub_details">
                  <span>Task name:</span>
                  <div style="text-align: initial;">
                    {theReview.name}
                  </div>
                </span>
                <span class="task_sub_details">
                  <span>Task Description:</span>
                  <div style="text-align: initial;">
                    {@html theReview.description ?? "-"}
                  </div>
                </span>
                <span class="task_sub_details">
                  <span>Marked completed by other party:</span>
                  <div style="text-align: initial;">
                    {dayjs(theReview.submitted).format("MMMM D, YYYY")}
                  </div>
                </span>
              </div>
            </div>
          {:else if reviewType === "request" && theReview.return_reason}
            <div class="data">
              <div>
                <h3>Missing</h3>
                <p>
                  Reason: {theReview.return_reason}
                </p>
              </div>
            </div>
          {:else}
            <div class="other">
              <p>
                This file type cannot be previewed in the browser. Please
                download to view.
              </p>
            </div>
          {/if}
        {/if}
      </div>
    </div>
  {:catch error}
    <p>Failed to load this review item: {error}</p>
  {/await}
</div>

<div class="mobile-only">
  <BottomBar
    containerClasses="h-3 px-1 container-flex-end"
    navbarClasses="p-0 gap-0"
    leftButtons={[]}
    rightButtons={[
      {
        button: "Download",
        color: "white",
        evt: "download",
        icon: "download",
        disabled: !itemLoaded,
        ignore:
          theReview?.request_type == "task" ||
          theReview?.request_type == "data",
      },
      {
        button: `Edit/ export data`,
        color: "white",
        evt: "editDataPopUp",
        disabled: !itemLoaded || !theReview?.formFields?.length >= 1,
        ignore: reviewType != "form",
      },
      {
        button: `Exp: ${expirationValue}`,
        color: "white",
        evt: "expirationPopUp",
        disabled: !theReview || !itemLoaded,
        ignore: !isExpirationTrackingEnabled,
        style: "font-weight: bolder;",
      },
      {
        button: "Reject",
        color: "danger",
        evt: "return",
        disabled: disableRequestorReviewProcess || showRefereshButton,
      },
      {
        button: showRefereshButton
          ? "Refresh"
          : hasReviewFill
          ? "Accept & Fill"
          : nextItemAvailable
          ? "Accept & Next Doc"
          : "Accept",
        color: "secondary",
        evt: showRefereshButton ? "refreshPage" : "accept",
        showTooltip: disableRequestorReviewProcess,
        tooltipMessage: "Recipient is actively editing the document",
        disabled: !theReview || !itemLoaded || disableRequestorReviewProcess,
      },
    ]}
    on:accept={() => handleAcceptItem()}
    on:return={returnIt}
    on:scrollup={() => {
      window.scrollTo(0, 0);
    }}
    on:edit={editIt}
    on:prev={() => {
      pdfView.prevPage();
    }}
    on:next={() => {
      pdfView.nextPage();
    }}
    on:download={handleReviewDownload}
    on:print={() => {
      printJS(`/n/api/v1/dproxy/${theReview.filename}`);
    }}
    on:expirationPopUp={() => {
      showFillModal = true;
    }}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      pdfView.pageForwarder(pageNumber);
    }}
    on:editDataPopUp={() => {
      showEditDataModal = true;
    }}
    on:refreshPage={() => {
      showRefereshButton = false;
      window.location.reload();
    }}
    hasPageNavigation
    {windowInnerWidth}
    {currentPage}
    {pageCount}
  />
</div>
<div class="desktop-only">
  <BottomBar
    leftButtons={[
      {
        button: "Reject",
        color: "danger",
        evt: "return",
        disabled: disableRequestorReviewProcess || showRefereshButton,
      },
      {
        button: "<< Prev Page",
        ignore: singlePage,
        color: "white",
        evt: "prev",
        disabled: firstPage ? true : false,
      },
      {
        button: "Download",
        color: "white",
        evt: "download",
        icon: "download",
        disabled: !itemLoaded,
        ignore:
          theReview?.request_type == "task" ||
          theReview?.request_type == "data",
      },

      {
        button: "Print",
        color: "white",
        evt: "print",
        icon: "print",
        ignore:
          !theReview ||
          !theReview?.filename?.endsWith(".pdf") ||
          theReview?.request_type == "data" ||
          theReview?.request_type == "task" ||
          isSafari ||
          isMobile(),
        disabled: false,
      },
    ]}
    centerButtons={[]}
    rightButtons={[
      {
        button: "Fill / Sign", // renamed edit /sign button to fill / sign
        evt: "edit",
        disabled: false,
        ignore: true,
      },
      {
        button: "Next Page >>",
        color: "white",
        ignore: singlePage,
        evt: "next",
        disabled: lastPage ? true : false,
      },
      {
        button: `Exp: ${expirationValue}`,
        color: "white",
        evt: "expirationPopUp",
        disabled: !theReview || !itemLoaded,
        ignore: !isExpirationTrackingEnabled,
        style: "font-weight: bolder;",
      },
      {
        button: `Edit/ export data`,
        color: "white",
        evt: "editDataPopUp",
        disabled: !itemLoaded || !theReview?.formFields?.length >= 1,
        ignore: reviewType != "form",
      },
      {
        button: showRefereshButton
          ? "Refresh"
          : hasReviewFill
          ? "Accept & Fill"
          : nextItemAvailable
          ? "Accept & Next Doc"
          : "Accept",
        color: "secondary",
        evt: showRefereshButton ? "refreshPage" : "accept",
        showTooltip: disableRequestorReviewProcess,
        tooltipMessage: "Recipient is actively editing the document",
        disabled: !theReview || !itemLoaded || disableRequestorReviewProcess,
      },
    ]}
    on:refreshPage={() => {
      showRefereshButton = false;
      window.location.reload();
    }}
    on:accept={() => handleAcceptItem()}
    on:return={returnIt}
    on:scrollup={() => {
      window.scrollTo(0, 0);
    }}
    on:edit={editIt}
    on:prev={() => {
      pdfView.prevPage();
    }}
    on:next={() => {
      pdfView.nextPage();
    }}
    on:download={handleReviewDownload}
    on:print={() => {
      printJS(`/n/api/v1/dproxy/${theReview.filename}`);
    }}
    on:expirationPopUp={() => {
      showFillModal = true;
    }}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      pdfView.pageForwarder(pageNumber + 1);
    }}
    on:editDataPopUp={() => {
      showEditDataModal = true;
    }}
    hasPageNavigation
    {windowInnerWidth}
    currentPage={currentPage - 1}
    {pageCount}
  >
    <span slot="right-slot-start" style="align-self: center;">
      <span
        style="cursor: pointer;"
        on:click={() => {
          getExportInfo();
          showExportInfoModal = true;
        }}
      >
        <FAIcon colordark={true} icon="circle-info" />
      </span>
      <Switch
        text="Auto Download"
        marginBottom={false}
        bind:checked={autoDownloadEnabled}
      />
    </span>
  </BottomBar>
</div>

{#if showExportInfoModal}
  <Modal
    on:close={() => {
      showExportInfoModal = false;
    }}
  >
    <p slot="header">Export Settings</p>
    <span style="font-family: 'Nunito', sans-serif; font-size: 15px;">
      <div>
        <Switch
          text="Auto Download"
          marginBottom={false}
          bind:checked={autoDownloadEnabled}
        />
        <p>
          Automatically download a copy of the document to your computer when
          enabled.
        </p>
      </div>

      {#if exportSpEnabled}
        <div>
          <Switch
            text={`Export to ${exportSpName}`}
            marginBottom={false}
            bind:checked={autoExportEnabled}
          />
          <p>
            Automatically upload a copy of this file to your third-party storage
            provider. If enabled, this file will be uploaded to the folder
            below:
            <br />
            <code>{exportSpTemplate}</code>
            Your export destinations can be adjusted on your
            <a href="/n/requestor#admin?integrations=true">Integrations</a> page.
          </p>
        </div>
      {:else}
        <Switch
          text={`Auto Export to Third-Party Storage Provider`}
          marginBottom={false}
          disabled={true}
        />
        <p>
          Automatically upload a copy of this file to your third-party storage
          provider. <strong>To enable this option</strong>, you need to set it
          up on your
          <a href="/n/requestor#admin?integrations=true">Integrations</a> page.
        </p>
      {/if}
    </span>

    <div class="modal-buttons">
      <span
        on:click={() => {
          showExportInfoModal = false;
        }}
      >
        <Button color="white" text="Close" />
      </span>
    </div>
  </Modal>
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showFillModal}
  <Modal
    on:close={() => {
      showFillModal = false;
    }}
  >
    <p slot="header">Expiration Date</p>

    <div class="modal-field">
      <div class="name">
        Document expires: {expirationValue}
      </div>
    </div>

    <div class="modal-buttons">
      <span
        on:click={() => {
          showAddExpirationPopUp = true;
          showFillModal = false;
        }}
      >
        <Button text="Edit" />
      </span>
    </div>
  </Modal>
{/if}

{#if showAddExpirationPopUp}
  <AddExpirationDate
    expirationInfo={theReview.doc_expiration_info}
    submitButtonText="Submit"
    on:submit={async (evt) => {
      const documentExpirationInformation = evt.detail?.data;
      const { request_id, doc_expiration_info } = theReview;
      await handleEditExpirationInfo(
        request_id,
        documentExpirationInformation,
        doc_expiration_info
      );
      showAddExpirationPopUp = false;
    }}
    on:close={() => {
      showAddExpirationPopUp = false;
    }}
  />
{/if}

{#if showReturnModal}
  <ReturnModal
    {...{
      requestId:
        reviewType === "form" ? theReview.submission_id : theReview?.id,
      closeModal,
      checklistId,
      reviewType,
    }}
  />
{/if}

{#if showTaskAcceptConfirmationDialogBox}
  <ConfirmationDialog
    title="Info"
    question={`This will mark task ${theReview.full.name} as Done`}
    yesText="Accept confirmation"
    noText="Cancel"
    yesColor="primary"
    noColor="white"
    on:close={() => {
      showTaskAcceptConfirmationDialogBox = false;
    }}
    on:yes={() => {
      acceptIt();
    }}
  />
{/if}

{#if showEditDataModal}
  <ConfirmationDialog
    title="Edit/ export data"
    question={`This will accept the submission and take you to the contacts data screen where you can edit the data. If you'd like to have the person who submitted this edit, hit cancel and use the reject button on the left`}
    yesText="Accept and proceed to edit"
    noText="Cancel"
    yesColor="primary"
    noColor="white"
    on:close={() => {
      showEditDataModal = false;
    }}
    on:yes={() => {
      window.location.hash = `#recipient/${item.recipient_id}/details/data`;
    }}
  />
{/if}

{#if reviewFillPopup}
  <ConfirmationDialog
    title="Info"
    question="You'll be able to fill and countersign your part of the document after reviewing what the other party submitted."
    yesText="Okay"
    noText="Don't show this again"
    yesColor="primary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => {
      reviewFillPopup = false;
      localStorage.setItem("reviewFillPopup", "yes");
    }}
    on:yes={() => {
      reviewFillPopup = false;
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
      window.location.hash = `#recipient/${recipient_id}/details/data`;
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
      window.open(`#recipient/${recipient_id}`, "_blank");
    }}
    on:download-all={() => {
      window.location = getChecklistDownloadUrl(4, theReview.assignment_id);
    }}
  />
{/if}

{#if showChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={(e) => assignPackage(e, recipient_id)}
    on:close={() => {
      showChecklistModal = false;
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

<style>
  .progress-tab {
    display: none;
  }
  @media only screen and (min-width: 768px) {
    .progress-tab {
      margin: 16px 0;
      display: flex;
      flex-flow: row nowrap;
      justify-content: center;
    }
  }

  .user-info {
    font-size: 14px;
    margin-top: 0.25rem;
    padding-left: 0.25rem;
    display: flex;
    justify-content: center;

    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  .form-content {
    width: 60%;
    text-align: initial;
  }

  .modal-field > .name {
    font-family: "Nunito", sans-serif;
  }

  .modal-field {
    padding-bottom: 2rem;
  }

  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: flex-end;
    width: 100%;
    align-items: center;
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

  .content-information {
    display: flex;
    flex-direction: row;
    align-items: center;
    padding-top: 0.5rem;
    justify-content: center;
  }

  .overflow-text {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    display: contents;
  }

  .data {
    display: grid;
    place-items: center;
  }
  .hidden {
    visibility: hidden;
  }

  .task {
    display: grid;
    place-items: center;
    position: absolute;
    top: 100%;
    margin: 0;
    overflow-y: auto;
    max-height: 60vh;
    width: 80%;
    border: 1px solid #000;
    padding: 1rem;
  }

  .data p,
  h3 {
    margin: 0;
  }
  .other {
    display: flex;
    flex-flow: column nowrap;
    align-items: center;
    justify-content: center;
  }
  .pdf {
    display: flex;
    flex-flow: row nowrap;
    align-items: flex-start;
  }

  /* content */
  .content {
    background: white;
    width: 100%;
    text-align: center;
    display: flex;
    flex-flow: row nowrap;
    justify-content: center;
  }
  .preamble {
    padding-bottom: 1rem;
  }

  .container {
    padding: 0 1.5rem;
    margin-bottom: 70px;
    position: relative;
    top: 50px;
  }

  .mobile-only {
    display: none;
  }

  .task_details {
    display: flex;
    align-items: flex-start;
    justify-content: space-between;
    flex-direction: column;
    gap: 0.5rem;
  }

  .task_sub_details {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .task_sub_details span {
    font-weight: bolder;
  }

  @media only screen and (max-width: 767px) {
    .container {
      padding: 0.5rem;
      margin-top: 1rem;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }

    .form-content {
      width: 100%;
    }
  }
</style>
