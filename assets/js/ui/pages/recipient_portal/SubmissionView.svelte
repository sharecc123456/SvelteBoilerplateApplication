<script>
  import {
    formSubmitPrefill,
    getFormSubmission,
    handleDownloadCSV,
  } from "BoilerplateAPI/Form";
  import NavBar from "../../components/NavBar.svelte";
  import BottomBar from "../../components/BottomBar.svelte";
  import PageNavigation from "../../components/PageNavigation.svelte";
  import Loader from "../../components/Loader.svelte";
  import Button from "../../atomic/Button.svelte";
  import PdfViewer from "../../content/PdfViewer.svelte";
  import {
    getDocumentCompletion,
    markInfoAsRead,
    submitFileRequest,
    requestExpirationInfo,
    uploadMultipleFileRequest,
    editFileRequest,
    deleteFileRequest,
    getIacSendDocument,
    submitConfirmationAndMarkTaskDone,
  } from "BoilerplateAPI/RecipientPortal";
  import { getChecklist } from "BoilerplateAPI/Checklist";
  import { getTemplate } from "BoilerplateAPI/Template";
  import { getRecipient } from "BoilerplateAPI/Recipient";
  import {
    getAssignments,
    getAssignmentWithId,
  } from "BoilerplateAPI/Assignment";
  import { onMount } from "svelte";
  import { isImage, printOptionMenu } from "Helpers/fileHelper";
  import {
    capitalizeFirstLetter,
    searchParamObject,
    isMobile,
    isNullOrUndefined,
  } from "../../../helpers/util";
  import ImagePreview from "../../components/ImagePreview.svelte";
  import { isBrowserTypeSafari } from "../../../helpers/util";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import SwipeWrapper from "../../components/SwipeWrapper.svelte";
  import RecipientUploadFileModal from "../../modals/RecipientUploadFileModal.svelte";
  import FormRenderer from "../../components/Form/FormRenderer.svelte";
  import AddExpirationDate from "../../components/AddExpirationDate.svelte";
  import FormEntriesRenderer from "../../components/Form/FormEntriesRenderer.svelte";

  import { isInThePast } from "../../../helpers/dateUtils";
  import { resetRequestorSignatureFields } from "../../../helpers/Requester/Dashboard";
  let isSafari = isBrowserTypeSafari();
  // specialId = 8 = form
  export let specialId = 0;
  export let documentId = 0;
  export let documentIndex = 0;
  export let assignmentId = 0;
  export let isPreview = false;
  export let fillType;
  export let isPrefill = false;
  let iacDocId;
  const isRecipient = fillType == "recipient" ? true : false;
  let showExpirationTrackInputBox = false;
  let documentExpirationInformation = null;
  let itemPromise;
  let singlePage = true;
  let lastPage = false;
  let firstPage = true;
  let pdfView;
  let newTab;
  let isFileInProgressStatus = false;
  let showEditUploadFileOption = false;
  let showReplaceFileOption = false;
  let showDeleteFileUploadedConfirmationBox = false;

  let currentPage, pageCount;
  let submitButtonClicked = false;

  let showFileProgressSubmitConfirmation = false;
  let showIACSignatureResetConfirmation = false;

  async function handleConfirmationFileSubmission() {
    const reply = await submitConfirmationAndMarkTaskDone(
      documentId,
      item.request_id,
      assignmentId,
      item.recipient_id,
      item.file_request_reference
    );

    if (!isNullOrUndefined(documentExpirationInformation)) {
      await requestExpirationInfo(
        item.request_id,
        documentExpirationInformation
      );
    }

    if (reply) {
      showToast(
        `Congrats! Task completed and request submitted successfully.`,
        1500,
        "success",
        "MM"
      );
      setTimeout(() => {
        window.location = `/n/recipient#dashboard?a=${assignmentId}`;
      }, 1000);
    } else {
      showToast(`Sorry! could not submit file request.`, 1500, "error", "MM");
    }
    submitButtonClicked = false;
  }

  async function handleSubmitFileRequest() {
    if (!isNullOrUndefined(item.file_request_reference)) {
      return await handleConfirmationFileSubmission();
    } else {
      return await processSubmitFileRequest();
    }
  }

  async function processSubmitFileRequest() {
    let reply = await submitFileRequest(documentId, item.request_id);
    if (!isNullOrUndefined(documentExpirationInformation)) {
      await requestExpirationInfo(
        item.request_id,
        documentExpirationInformation
      );
    }

    if (reply.ok) {
      showToast(
        `Congrats! Request submitted successfully.`,
        1500,
        "white",
        "MM"
      );
      setTimeout(() => {
        window.location = `/n/recipient#dashboard?a=${assignmentId}`;
      }, 1000);
    } else {
      showToast(`Sorry! could not submit file request.`, 1500, "error", "MM");
    }
    submitButtonClicked = false;
  }

  async function deleteFilesUploaded() {
    showDeleteFileUploadedConfirmationBox = false;
    let reply = await deleteFileRequest(documentId);

    if (reply.ok) {
      showToast(`Request deleted successfully.`, 1000, "default", "MM");
      setTimeout(() => {
        window.location = `/n/recipient#dashboard?a=${assignmentId}`;
      }, 1000);
    } else {
      showToast(`Sorry! could not delete file request.`, 1000, "error", "MM");
    }
  }

  async function processFRUpload(evt) {
    let detail = evt.detail;
    const currentFileRequest = { id: item.request_id };
    let reply = await uploadMultipleFileRequest(
      currentFileRequest,
      item.recipient_id,
      assignmentId,
      detail.file
    );
    console.log(reply);
    showReplaceFileOption = false;
    if (reply.ok) {
      showToast(
        `Congrats! Request file replaced successfully.`,
        1000,
        "white",
        "MM"
      );
      setTimeout(() => {
        window.location.reload();
      }, 1000);
    } else {
      showToast(`Sorry! Could not replace File request.`, 1500, "error", "MM");
      reportCrash("processFRUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
    }
  }

  async function editFRUpload(evt) {
    let detail = evt.detail;
    let reply = await editFileRequest(documentId, detail.file);
    console.log(reply);
    showEditUploadFileOption = false;
    if (reply.ok) {
      showToast(
        `Congrats! Request file successfully added.`,
        1000,
        "white",
        "MM"
      );
      setTimeout(() => {
        window.location.reload();
      }, 1000);
    } else {
      showToast(`Sorry! Could not replace File request.`, 1500, "error", "MM");
      reportCrash("editFileRequest", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
    }
  }

  let contentsId;
  let showRequestorFillOption = false;
  async function submitPrefillForm(evt) {
    if (specialId != 8) {
      console.log(
        `possible BUG ?: submitPrefillForm called with specialId == ${specialId} != 8`
      );
      if (window.history.length == 1) {
        window.close();
      } else {
        window.history.back(-1);
      }
      return;
    }

    if (contentsId == undefined) {
      console.log("possible BUG ?: contentsId is undefined!");
      if (window.history.length == 1) {
        window.close();
      } else {
        window.history.back(-1);
      }
      return;
    }

    // all ff.value fields should be mapped to the default_value
    // all ff.value should be cleared
    let new_fields = item.formFields.map((ff) => {
      if (ff.is_multiple) {
        ff.default_value = ff.values;
      } else {
        ff.default_value = ff.value;
      }
      return ff;
    });

    item.formFields = new_fields;
    // TODO submit to the backend
    console.log({
      submitPrefillFormItem: item,
      assignmentId: assignmentId,
      contentsId: contentsId,
    });

    formSubmitPrefill(contentsId, item).then((x) => {
      window.history.go(-1);
    });
  }

  let named_url = "";
  console.log(specialId);
  if (specialId == 1) {
    named_url = `/completeddocument/${assignmentId}/${documentId}/download`;
    itemPromise = getDocumentCompletion(specialId, assignmentId, documentId);
  } else if (specialId == 2) {
    named_url = `/reviewrequest/${documentId}/download/completed`; // Review Completed Document
    itemPromise = getDocumentCompletion(specialId, assignmentId, documentId);
  } else if (specialId == 3) {
    named_url = `/user/${assignmentId}/storage/${documentId}/download`; // Cabinet Download
    itemPromise = getDocumentCompletion(specialId, assignmentId, documentId);
  } else if (specialId == 4) {
    itemPromise = getTemplate(documentId, fillType).then((x) => {
      let y = x;
      y.submitted = "";
      y.filename = x.file_name;
      named_url = x.is_info
        ? `/document/${assignmentId}/${y.id}/download`
        : `/n/api/v1/dproxy/${x.file_name}?dispName=${x.name}`;

      // Info templates is marked read when recipient views the template
      // Only mark as read if its the first view
      // the api checks if the info template is read previously before it is marked as read
      // Note: Its better not to call api itself if the template is already marked read
      if (fillType === "recipient") {
        markInfoAsRead(documentId, assignmentId);
      }

      return y;
    });
  } else if (specialId == 5) {
    named_url = `/rawdocument/${documentId}/download`;
    itemPromise = getTemplate(documentId, fillType).then((x) => {
      let y = x;
      y.submitted = "";
      y.filename = x.file_name;

      return y;
    });
  } else if (specialId === 6) {
    // view rdc doc type after submitted
    // documentId = customizationId
    showRequestorFillOption = true;
    named_url = `/customized/document/${assignmentId}/${documentId}/download`;
    itemPromise = getIacSendDocument(documentId, assignmentId);
  }
  let item = null;
  let recipient = null;
  let assignment = null;
  let pdfRendered = null;
  let pageLoading = null;

  let assignmentDataPromise = getAssignments().then((assignments) => {
    let x = Array.from(assignments).filter((a) => a.id == assignmentId);
    return Promise.resolve(x[0]);
  });

  let isSubmissionEditable = false;
  let showEditOption = false;

  const editOptionStatus = () => {
    showEditOption = item.is_iac && item.status === 1;
    isSubmissionEditable = showEditOption && specialId == 1;
  };

  let isUnsupportedFileView = false;
  let disableDownloads = false;

  let windowInnerWidth, elmWidth;
  onMount(async () => {
    // added this to scroll to the top in mobile
    // required for navigating in mobile from personalization screen
    window.scrollTo(0, 0);
    window.sessionStorage.setItem("showOnceGuideDialog", true);
    windowInnerWidth = window.innerWidth;
    const requestParams = searchParamObject();
    newTab = requestParams?.newTab === "true" ? true : false;
    showRequestorFillOption = newTab ? false : showRequestorFillOption;
    contentsId = requestParams?.cid;
    if (specialId === 8) {
      if (isPreview || isPrefill) {
        let checklist = {};
        if (documentIndex) {
          let req = await fetch(`/n/api/v1/contents/${contentsId}`);
          checklist = await req.json();
        } else {
          checklist = await getChecklist(assignmentId); //Where Error
        }
        if (documentId) {
          const form = checklist.forms.find((f) => f.id == documentId);
          item = form;
        } else if (documentIndex) {
          const form = checklist.forms[documentIndex - 1]; //removing padding value from document index

          // apply the default value to the value field (this is for preflight prefill)
          if (form.has_repeat_entries && form.entries?.entries?.map) {
            let new_entries = form.entries.entries.map((entry) => {
              let acc = {};
              for (const key in entry) {
                acc[`${key}`] = entry[key];
              }
              return acc;
            });

            form.entries = new_entries;
          } else {
            let new_fields = form.formFields.map((ff) => {
              if ("value" in ff.default_value) {
                if (ff.is_multiple) {
                  ff.values = ff.default_value.value;
                } else {
                  ff.value = ff.default_value.value;
                }
              } else {
                ff.value = "";
              }
              return ff;
            });
            form.formFields = new_fields;
          }
          item = form;
        }
      } else {
        const assignment = await getAssignmentWithId(assignmentId);
        const { recipient_id } = assignment;
        recipient = await getRecipient(recipient_id);
        item = await getFormSubmission(assignmentId, documentId);
      }
      console.log({
        item,
      });

      return;
    }
    try {
      item = await itemPromise;
      iacDocId = item.iac_doc_id;
      isUnsupportedFileView = !(
        item?.filename?.endsWith(".pdf") || isImage(item.filename)
      );
      editOptionStatus(item);
      isFileInProgressStatus =
        specialId == 2 && item.type === "file" && item?.status === 0;
      disableDownloads = item.type === "data" || item.type === "task";
      console.log(disableDownloads);
      if (specialId == 3) {
        assignment = { name: "Internal Filing Cabinet" };
      } else if (specialId != 5) {
        // checklist = await getChecklist(assignmentId); //Where Error
        assignment = getAssignments().then((assignments) => {
          let x = Array.from(assignments).filter(
            (a) => a.id == assignmentId
          )[0];
          return x;
        });
      }
      if (specialId !== 5 && item.recipient_id)
        recipient = await getRecipient(item.recipient_id);
    } catch (err) {
      console.error(err);
    }
  });

  /**
   *
   * @param done
   * @param close
   * @param isPreview
   *
   */
  const getButtonTitle = (done, close, isPreview) => {
    return isPreview ? close : done;
  };

  let errorLoadingPDF = false;

  const handleSubmitSubmission = () => {
    if (isFileInProgressStatus && item.is_enabled_tracking) {
      return (showExpirationTrackInputBox = true);
    } else {
      handleSubmitFileRequest();
      submitButtonClicked = true;
      return;
    }
  };
</script>

{#if !specialId == 5 && item.recipient_id}
  {#await assignmentDataPromise then assignment}
    {#await getRecipient(item.recipient_id) then recipient}
      <NavBar
        backLink=""
        backLinkHref={`#`}
        showCompanyLogo={false}
        navbar_spacer_classes="navbar_spacer_pb1_desktop navbar_spacer_pb1"
        middleText={assignment || recipient
          ? ` ${recipient.name ? `${recipient.name} &nbsp;||&nbsp;` : " "}
              ${assignment?.name || ""} &nbsp;&gt;&gt;&nbsp ${item?.name || ""}
            `
          : ""}
        middleSubText={assignment
          ? assignment.description
            ? `(${assignment.description})`
            : " "
          : ""}
        thirdLine={!isNullOrUndefined(item?.doc_expiration_info?.value)
          ? `<b>Expiration:</b> ${item.doc_expiration_info?.value} ${
              isInThePast(item?.doc_expiration_info?.value)
                ? `<i style="color: #db5244;" class="fa-solid fa-circle-exclamation"></i>`
                : ""
            }`
          : null}
      />
    {/await}
  {/await}
{:else if !specialId == 5}
  <!-- why this logic? -->
  {#await assignmentDataPromise then assignment}
    <NavBar
      backLink={location.hash.includes("newTab=true") ? "" : "  "}
      backLinkHref="javascript:window.history.back(-1)"
      showCompanyLogo={false}
      navbar_spacer_classes="navbar_spacer_pb1_desktop navbar_spacer_pb1"
      middleText={assignment
        ? `${assignment?.name || ""} &nbsp;&gt;&gt;&nbsp ${item?.name || ""}`
        : ""}
      middleSubText={assignment
        ? assignment.description
          ? `(${assignment.description})`
          : " "
        : ""}
      thirdLine={!isNullOrUndefined(item?.doc_expiration_info?.value)
        ? `<b>Expiration:</b> ${item.doc_expiration_info?.value} ${
            isInThePast(item?.doc_expiration_info?.value)
              ? `<i style="color: #db5244;" class="fa-solid fa-circle-exclamation"></i>`
              : ""
          }`
        : null}
    />
  {/await}
{:else}
  <NavBar
    backLink={location.hash.includes("newTab=true") || isFileInProgressStatus
      ? ""
      : "  "}
    backLinkHref="javascript:window.history.back(-1)"
    {isRecipient}
    showLogo={false}
    renderOnlyIcon={isFileInProgressStatus ? true : false}
    on:arrowClicked={() => (showFileProgressSubmitConfirmation = true)}
    windowType={fillType}
    showCompanyLogo={false}
    navbar_spacer_classes="navbar_spacer_pb1_desktop navbar_spacer_pb1"
    middleText={item
      ? capitalizeFirstLetter(specialId == 8 ? item.title : item.name)
      : " "}
    middleSubText={recipient
      ? `${recipient?.name || ""} ${
          recipient.company ? `(${recipient.company})` : ""
        }`
      : ""}
    thirdLine={!isNullOrUndefined(item?.doc_expiration_info?.value)
      ? `<b>Expiration:</b> ${item.doc_expiration_info?.value} ${
          isInThePast(item?.doc_expiration_info?.value)
            ? `<i style="color: #db5244;" class="fa-solid fa-circle-exclamation"></i>`
            : ""
        }`
      : null}
  />
{/if}

<div class="container">
  {#if pageLoading}
    <Loader loading={true} />
  {/if}

  {#if item}
    <div class="preamble">
      <div class="title">
        <div class="buttons">
          {#if specialId === 5 && !isPreview}
            <!-- Hide the button when template file is in preview -->
            <a href={`#template/${documentId}`}>
              <Button color="white" icon="edit" text="Edit" />
            </a>
          {/if}
        </div>
      </div>
    </div>
    <div class="content">
      {#if specialId == 8}
        <div style="margin-top: 2rem;" class="form-content">
          {#if item.has_repeat_entries}
            <FormEntriesRenderer formData={item} />
          {:else}
            <FormRenderer {isPrefill} form={item} {isPreview} />
          {/if}
        </div>
      {:else if item?.filename?.endsWith(".pdf")}
        <SwipeWrapper
          on:swipeLeft={() => {
            if (!lastPage) {
              pageLoading = true;
              setTimeout(() => {
                pdfView.nextPage();
                pageLoading = false;
              }, 200);
            }
          }}
          on:swipeRight={() => {
            if (!firstPage) {
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
            <div class="file-container">
              <PdfViewer
                bind:this={pdfView}
                bind:singlePage
                bind:lastPage
                bind:firstPage
                bind:currentPage
                bind:pageCount
                bind:pdfRendered
                url={`/n/api/v1/dproxy/${item.filename}`}
              />
            </div>
          </div>
        </SwipeWrapper>
      {:else if isImage(item.filename)}
        <div style="padding-top: 4rem;">
          <ImagePreview {item} />
        </div>
      {:else if item.type === "task" && item.description}
        <div class="task">
          <div>
            <h3>Description</h3>
            <div style="text-align: center;">
              {@html item.description}
              <!-- for confirmation link could add link here but the confirmation link is required in the description popUps  -->
            </div>
          </div>
        </div>
      {:else}
        <div class="other">
          <p>
            This file type cannot be previewed in the browser. Please download
            to view.
          </p>
        </div>
      {/if}
    </div>
  {/if}
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showExpirationTrackInputBox}
  <AddExpirationDate
    on:close={() => (showExpirationTrackInputBox = false)}
    on:submit={(evt) => {
      documentExpirationInformation = evt.detail?.data;
      showExpirationTrackInputBox = false;
      handleSubmitFileRequest();
      submitButtonClicked = true;
    }}
  />
{/if}

{#if showDeleteFileUploadedConfirmationBox}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`This will delete the current uploaded files . Are you sure?`}
    yesText="yes, delete"
    noText="No, cancel"
    yesColor="danger"
    noColor="white"
    on:yes={deleteFilesUploaded}
    on:close={() => {
      showDeleteFileUploadedConfirmationBox = false;
    }}
  />
{/if}

{#if showFileProgressSubmitConfirmation}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`Submit or Abandon`}
    yesText="Submit"
    noText="Cancel"
    yesColor="secondary"
    noColor="white"
    hideText="Delete"
    hideColor="danger"
    on:yes={() => {
      showFileProgressSubmitConfirmation = false;
      handleSubmitSubmission();
    }}
    on:close={() => (showFileProgressSubmitConfirmation = false)}
    on:hide={() => {
      showFileProgressSubmitConfirmation = false;
      showDeleteFileUploadedConfirmationBox = true;
    }}
  />
{/if}

{#if showReplaceFileOption}
  <RecipientUploadFileModal
    uploadHeaderText="Replace document"
    on:close={() => {
      showReplaceFileOption = false;
    }}
    on:done={processFRUpload}
    specialText={`Replace the requested file (${item.name}) and re-upload it.`}
  />
{/if}

{#if showEditUploadFileOption}
  <UploadFileModal
    requireIACwarning={false}
    uploadHeaderText="Add pages"
    multiple={true}
    on:close={() => {
      showEditUploadFileOption = false;
    }}
    on:done={editFRUpload}
    specialText={`Add pages for file (${item.name}) and upload it.`}
  />
{/if}

<div class="mobile-only">
  <BottomBar
    containerClasses="h-4 pt-8 pb-12"
    leftButtons={[
      {
        button: "Delete",
        color: "danger",
        evt: "deleteUpload",
        ignore: !isFileInProgressStatus,
      },
      {
        button: "Add pages",
        color: "white",
        evt: "edit",
        icon: "edit",
        ignore:
          !isFileInProgressStatus || errorLoadingPDF || isUnsupportedFileView,
      },
      {
        button: "Replace",
        color: "white",
        evt: "replace",
        icon: "exchange",
        ignore: !isFileInProgressStatus,
      },
    ]}
    rightButtons={[
      {
        button: "Update",
        color: "white",
        evt: "allowRequestorEdit",
        ignore: !showRequestorFillOption,
      },
      {
        button: "Submit",
        color: "primary",
        evt: "submitRequest",
        ignore: !isFileInProgressStatus,
        disabled: submitButtonClicked,
      },
      {
        button: getButtonTitle("Done", "Close", true),
        color: "secondary",
        evt: "done",
        disabled: false,
        ignore: isFileInProgressStatus,
      },
      {
        button: "Done",
        color: "primary",
        evt: "submitprefillform",
        ignore: specialId != 8,
        disabled: isPreview,
      },
      {
        button: getButtonTitle("Done", "Close", true),
        color: "secondary",
        evt: "done",
        disabled: false,
        ignore: newTab || isFileInProgressStatus,
        color: "secondary",
      },
    ]}
    on:replace={() => (showReplaceFileOption = true)}
    on:edit={() => (showEditUploadFileOption = true)}
    on:done={() => {
      window.history.go(-1);
    }}
    on:deleteUpload={() => (showDeleteFileUploadedConfirmationBox = true)}
    on:submitRequest={() => handleSubmitSubmission()}
    on:allowPrefill={() => {
      window.location.hash = `#iac/fill/${iacDocId}/${assignmentId}?name=${
        item.name
      }&edit=${true}&docId=${documentId}`;
    }}
    on:prev={() => {
      pdfView.prevPage();
    }}
    on:next={() => {
      pdfView.nextPage();
    }}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      pdfView.pageForwarder(pageNumber + 1);
    }}
    on:allowRequestorEdit={() => {
      showIACSignatureResetConfirmation = true;
    }}
    hasPageNavigation
    {windowInnerWidth}
    currentPage={currentPage - 1}
    {pageCount}
  />
</div>
<div class="desktop-only print-hidden">
  <BottomBar
    leftButtons={[
      {
        button: "<< Prev Page",
        color: "white",
        evt: "prev",
        disabled: firstPage,
        ignore: singlePage,
        color: "white",
      },
      {
        button: "Delete",
        color: "danger",
        evt: "deleteUpload",
        ignore: !isFileInProgressStatus,
      },
      {
        button: "Add pages",
        color: "white",
        evt: "edit",
        icon: "edit",
        ignore:
          !isFileInProgressStatus || errorLoadingPDF || isUnsupportedFileView,
      },
      {
        button: "Replace",
        color: "white",
        evt: "replace",
        icon: "exchange",
        ignore: !isFileInProgressStatus,
      },
      {
        button: "Download",
        evt: "download",
        color: "white",
        icon: "download",
        ignore:
          (!isUnsupportedFileView &&
            isFileInProgressStatus &&
            !errorLoadingPDF) ||
          disableDownloads,
      },
      {
        button: "Print",
        evt: "print",
        color: "white",
        icon: "print",
        ignore:
          isFileInProgressStatus ||
          specialId === 8 ||
          isSafari ||
          isMobile() ||
          disableDownloads,
      },
    ]}
    rightButtons={[
      {
        button: "Update",
        color: "white",
        evt: "allowRequestorEdit",
        ignore: !showRequestorFillOption,
      },
      {
        button: "Submit",
        color: "primary",
        evt: "submitRequest",
        ignore: !isFileInProgressStatus,
        disabled: submitButtonClicked,
      },
      {
        button: "Done",
        color: "primary",
        evt: "submitprefillform",
        ignore: specialId != 8,
        disabled: isPreview,
      },
      {
        button: "Edit",
        evt: "allowPrefill",
        color: "white",
        icon: "edit",
        showTooltip: !isSubmissionEditable,
        tooltipMessage:
          "Document has already been reviewed, please contact your requestor about making a change",
        disabled: !isSubmissionEditable,
        ignore: !showEditOption,
      },
      {
        button: "Next Page >>",
        evt: "next",
        disabled: lastPage,
        ignore: singlePage,
        color: "white",
      },
      {
        button: getButtonTitle("Done", "Close", true),
        color: "secondary",
        evt: "done",
        disabled: false,
        ignore: newTab || isFileInProgressStatus,
        color: "secondary",
      },
    ]}
    on:submitprefillform={submitPrefillForm}
    on:done={() => {
      window.history.go(-1);
    }}
    on:download={() => {
      if (specialId === 8) {
        // form
        handleDownloadCSV(item);
        return;
      }
      window.location = named_url;
    }}
    on:replace={() => (showReplaceFileOption = true)}
    on:edit={() => (showEditUploadFileOption = true)}
    on:deleteUpload={() => (showDeleteFileUploadedConfirmationBox = true)}
    on:submitRequest={() => handleSubmitSubmission()}
    on:allowPrefill={() => {
      window.location.hash = `#iac/fill/${iacDocId}/${assignmentId}?name=${
        item.name
      }&edit=${true}&docId=${documentId}`;
    }}
    on:print={() => {
      printOptionMenu(`/n/api/v1/dproxy/${item.filename}`, item.filename);
    }}
    on:prev={() => {
      pdfView.prevPage();
    }}
    on:next={() => {
      pdfView.nextPage();
    }}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      pdfView.pageForwarder(pageNumber + 1);
    }}
    on:allowRequestorEdit={() => {
      showIACSignatureResetConfirmation = true;
    }}
    hasPageNavigation
    {windowInnerWidth}
    currentPage={currentPage - 1}
    {pageCount}
  />
</div>

{#if showIACSignatureResetConfirmation}
  <ConfirmationDialog
    question={`Are you sure you want to update document? This will reset the signature fields`}
    yesText="Yes, Reset & continue"
    noText="No, Cancel"
    yesColor="secondary"
    noColor="white"
    on:yes={async () => {
      const { iac_doc_id, contents_id, recipient_id } = item;

      await resetRequestorSignatureFields(
        iac_doc_id,
        contents_id,
        recipient_id
      );
      window.location.hash = `#iac/fill/${iac_doc_id}/${contents_id}/${recipient_id}?editMode=true`;
    }}
    on:close={() => {
      showIACSignatureResetConfirmation = false;
    }}
  />
{/if}

<style>
  .form-content {
    width: 650px;
    text-align: initial;
  }

  .pdf {
    display: flex;
    position: relative;
    align-items: flex-start;
    padding-top: 3rem;
  }
  /* content */

  .other {
    display: grid;
    place-items: center;
    position: absolute;
    top: 50%;
    margin-top: 2rem;
    overflow-y: auto;
    max-height: 60vh;
    padding: 1rem;
  }
  .task {
    display: grid;
    place-items: center;
    position: absolute;
    top: 50%;
    margin: 0;
    overflow-y: auto;
    max-height: 60vh;
    width: 80%;
    border: 1px solid #000;
    padding: 1rem;
  }
  .hidden {
    visibility: hidden;
  }

  a {
    text-decoration: none;
  }

  .content {
    padding-top: 1rem;
    padding-bottom: 5rem;
    background: white;
    width: 100%;
    text-align: center;
    display: flex;
    flex-flow: row nowrap;
    justify-content: center;
  }

  .preamble > .title {
    display: flex;
    width: 100%;
    flex-flow: row nowrap;
    justify-content: space-between;
    align-items: center;
  }
  .container {
    padding: 0 1.5rem;
    font-family: "Nunito", sans-serif;
  }

  .buttons {
    display: flex;
    margin-inline: auto;
  }
  .buttons > * {
    display: flex;
    margin-left: 10px;
  }
  .mobile-only {
    display: none;
  }
  .container {
    position: relative;
  }
  .file-container {
    display: flex;
    order: 2;
  }
  @media only screen and (max-width: 767px) {
    .container {
      padding: 0;
    }

    .preamble {
      margin-top: 0rem;
    }

    .content {
      display: block;
      padding-top: 1rem;
      padding-bottom: 0;
    }
    .pdf {
      position: relative;
      padding: 3rem 0.5rem 10rem;
      width: calc(100vw - 1rem);
      overflow-x: hidden;
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

  @media print {
    .print-hidden {
      display: none;
    }
  }
</style>
