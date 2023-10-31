<script>
  import { onDestroy, onMount } from "svelte";
  import NavBar from "../components/NavBar.svelte";
  import PageNavigation from "../components/PageNavigation.svelte";
  import BottomBar from "../components/BottomBar.svelte";
  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";
  import SwipeWrapper from "../components/SwipeWrapper.svelte";
  import {
    iacInitializeModel,
    iacModelSetRecipient,
    iacModelSetAssignment,
    iacModelSetEsignConsent,
    iacPrepareModelSubmission,
    iacModelDestroy,
    iacModelSetInputFaker,
    iacModelSetContents,
    iacPageFieldValidation,
    iacAllFieldValidation,
  } from "IAC/Model";
  import {
    getIacDocument,
    iacGetEsignConsent,
    iacSaveForm,
    iacSubmitForm,
    iacDelEsign,
    iacGetPreviewPDF,
  } from "BoilerplateAPI/IAC";
  import { iacRender, IAC_MODE } from "IAC/Render";
  import { iacMakeFillable, iacMakeFillableAsRequestor } from "IAC/Fill";
  import { getTemplate } from "BoilerplateAPI/Template";
  import { storeSignatureFields, inputBoxClicked } from "../../store";
  import { getRecipient } from "BoilerplateAPI/Recipient";
  import { sendUpdatedDocumentEmailNotification } from "../../api/email";
  import {
    searchParamObject,
    capitalizeFirstLetter,
    isAndroidMobile,
    savePDF,
    isNullOrUndefined,
  } from "../../helpers/util";
  import Loader from "Components/Loader.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";
  import { assignContents } from "BoilerplateAPI/Assignment";
  import { getDocumentCompletion } from "../../api/RecipientPortal";
  import PdfPageNavigation from "../components/PdfPageNavigation.svelte";
  import { getDateObject, iacGetDateString } from "Helpers/dateUtils";
  import FAIcon from "../atomic/FAIcon.svelte";
  import ReturnModal from "../components/Requestor/Review/ReturnModal.svelte";
  import { getIACFillChannel } from "../../webChannels";
  import {
    isRecipientInFillMode,
    isRequestorInEditMode,
    isRequestorInReviewMode,
  } from "../../store";

  export let iacDocId = 0;
  export let recipientId;
  export let assignmentId;
  export let contentsId = 0;
  export let assigneeId;
  export let finishCallback = () => {};
  export let customizationId;
  let docId;
  export let editableDoc = false;

  export let fillType = "recipient";
  export let isDirectSend = false;
  export let fromSetup = false;
  let disableRecipientFill = false;
  let disableRequestorReviewProcess = false;
  let isRecipientOnline = false;
  let socketToolTipMessage =
    fillType === "recipient"
      ? "Requestor is actively updating the document!"
      : "Recipient is actively editing the document";

  // Single Entry Form Filling mode? Don't send, just generate the PDF and be happy.
  export let sesMode = false;
  export let tcId = 0; // true contents id, the base package contents id, not the internal package used for IACfill

  // Requestor update and resend the iac document
  export let editMode = false;
  let checkAndroidWarningDialogStatus = JSON.parse(
    localStorage.getItem("dontShowAndroidWarning")
  );

  let checkSkipPagesWarningDialogBoxStatus = true;
  let checkSkipPagesWarningOnceDialogBoxStatus = true;
  let isRsdcType;
  let assignmentContentsId;
  let emptyFieldCheckBoxStatus;
  let checkEmptyFieldBoxStatusPages = {};

  let mounted = false;
  let loaded = false;
  let reason = "";

  /* from iacModel */
  let doNextPage,
    doPrevPage,
    doSaveForm,
    doCancelForm,
    doFinishForm,
    doPageForwarder;
  let pageCount, currentPage;
  let iacDocument = getIacDocument(iacDocId);
  let iacModel = null;
  let showCancelConfirmationDialog = false;
  let showFinishFieldValidationDialog = false;
  let showPageEmptyFieldsConfirmationDialog = false;
  let showNotLastPageConfirmationDialog = false;
  let showReasonDialog = false;
  let fieldIds = [];
  let isIACRendered = false;
  let isFinishedIAC = false;
  let fields = [];
  let currentFieldIndex = null;
  let hasPrevField = false;
  let hasNextField = false;
  let pageLoading = false;
  let file_name;
  let templateName;
  let width = window.innerWidth;
  let selectedModel = undefined;
  let showAndroidWarning = false;
  let skipPagesWarningDialogBox = false;
  let nextFieldConfirmation = false;
  let rawDocumentId;
  let showUpdateNoteAddOption = false;
  let updateNote = "";
  let showRefereshButton = false;

  const closeModal = () => (showUpdateNoteAddOption = false);

  const checkWindowResize = () => {
    width = window.innerWidth;
  };
  window.addEventListener("resize", checkWindowResize);
  let checkNotLastPageConfirmationDialogStatus = JSON.parse(
    localStorage.getItem("dontShowNotLastPageConfirmationDialog")
  );
  let showCounterSignSuccessDialog = false;
  let counterSignSuccessDialogStatus = JSON.parse(
    localStorage.getItem("dontShowCounterSignSuccessDialog")
  );
  const reassignFieldChecks = () => {
    hasNextField =
      currentPage === pageCount - 1
        ? false
        : fields.findIndex((field) => field.pageNumber > currentPage) >= 0;
    hasPrevField =
      currentPage === 0
        ? false
        : fields.findIndex((field) => field.pageNumber < currentPage) >= 0;
  };

  function recipientChannelConnect(channelConnect, fillId, fillType) {
    if (!channelConnect) return;
    isRecipientOnline = true;
    recipientChannel = getIACFillChannel(fillId, {
      fillType,
    });

    recipientChannel.on("requestor_edit_complete", () => {
      console.log("requestor edit mode complete ...");
      showRefereshButton = true;
      disableRecipientFill = false;
    });
  }

  function requestorChannelConnect(channelConnect, fillId, fillType) {
    if (!channelConnect) return;
    requestorChannel = getIACFillChannel(fillId, {
      fillType,
    });

    requestorChannel.on("recipient_fill_complete", () => {
      showRefereshButton = true;
      disableRequestorReviewProcess = false;
    });
  }

  let openRequestorFillSocketChannel = editMode || fillType === "review";

  function init(channelConnect = true) {
    // iacRenderLoadingScreen(canvas);
    iacModel = iacDocument
      .then(async (doc) => {
        file_name = doc?.file_name;
        templateName = doc?.doc_name;
        isRsdcType =
          doc?.document_type === "raw_document_customized" ? true : false;
        assignmentContentsId = doc?.contents_id;
        customizationId = doc?.customization_id;
        rawDocumentId = isRsdcType ? doc.template_id : doc.document_id;

        if (fillType == "recipient") {
          recipientChannelConnect(
            channelConnect,
            doc?.iac_assigned_form_id,
            fillType
          );
          return iacMakeFillable(doc, recipientId, assignmentId);
        }

        if (fillType == "review" || fillType == "requestor") {
          if (openRequestorFillSocketChannel) {
            requestorChannelConnect(
              channelConnect,
              doc?.iac_assigned_form_id,
              fillType
            );
          }
          return iacMakeFillableAsRequestor(doc, recipientId, contentsId);
        }

        return doc;
      })
      .then((doc) => {
        let targetOperationMode =
          fillType == "recipient"
            ? IAC_MODE.RECIPIENT_FILL
            : fillType == "review"
            ? IAC_MODE.REVIEW
            : IAC_MODE.REQUESTOR_FILL;
        let x = iacInitializeModel(doc, targetOperationMode, sesMode);
        const { fieldState } = x;
        fields = x.fill.orderedSpecs
          .map((spec) => ({ pageNumber: spec[6], id: spec[4], location: spec }))
          .filter((field) => fieldState[field.id].editable);
        console.log(fields);
        if (currentFieldIndex) currentFieldIndex = 0;

        // pass the SES (Single Entry System) mode to the model
        x.sesMode = sesMode;
        x.editMode = editMode;
        if (sesMode) {
          console.log("[IAC/SES] SES mode enabled");
        }

        if (targetOperationMode == IAC_MODE.RECIPIENT_FILL) {
          iacModelSetInputFaker(x, iacInputFaker);
          iacModelSetRecipient(x, recipientId);
          iacModelSetAssignment(x, assignmentId);
          iacModelSetEsignConsent(
            x,
            iacGetEsignConsent(recipientId, "recipient")
          );
        } else if (
          targetOperationMode == IAC_MODE.REQUESTOR_FILL ||
          targetOperationMode == IAC_MODE.REVIEW
        ) {
          iacModelSetInputFaker(x, iacInputFaker);
          iacModelSetRecipient(x, recipientId);
          iacModelSetContents(x, contentsId);
          iacModelSetEsignConsent(x, iacGetEsignConsent(0, "requestor"));
        }

        window.iacModel = x; // Easy access for debug purposes.

        selectedModel = x;

        doPrevPage = (pageNumber = null) => {
          if (currentPage == 0) {
            return;
          } else {
            let previousCP = x.multipage.currentPage;
            x.multipage.currentPage =
              x.multipage.currentPage == 0
                ? x.multipage.currentPage
                : pageNumber !== null
                ? pageNumber
                : x.multipage.currentPage - 1;
            currentPage = x.multipage.currentPage;
            pageCount = x.multipage.pageCount;
            currentFieldIndex = fields.findIndex(
              (field) => field.pageNumber === currentPage
            );
            reassignFieldChecks();

            if (previousCP != x.multipage.currentPage) {
              // dislodge the textmarker
              x.fill.activeField = null;
              x.fill.currentTabIndex = -1;
              iacRender(x, x.render.canvas);
            }
            window.scrollTo(0, 0);
          }
        };

        doNextPage = (pageNumber = null) => {
          if (currentPage != pageCount - 1) {
            let previousCP = x.multipage.currentPage;
            x.multipage.currentPage =
              x.multipage.currentPage == x.multipage.pageCount - 1
                ? x.multipage.currentPage
                : pageNumber !== null
                ? pageNumber
                : x.multipage.currentPage + 1;
            currentPage = x.multipage.currentPage;
            pageCount = x.multipage.pageCount;
            currentFieldIndex = fields.findIndex(
              (field) => field.pageNumber === currentPage
            );
            reassignFieldChecks();
            if (previousCP != x.multipage.currentPage) {
              // dislodge the textmarker
              x.fill.activeField = null;
              x.fill.currentTabIndex = -1;
              iacRender(x, x.render.canvas);
            }
            window.scrollTo(0, 0);
          } else {
            doFinishForm();
          }
        };

        doPageForwarder = (pageNumber) => {
          if (
            typeof pageNumber == "number" &&
            (pageNumber == 0 || pageNumber) &&
            pageNumber < pageCount
          ) {
            let previousCP = x.multipage.currentPage;
            x.multipage.currentPage = pageNumber;
            currentPage = x.multipage.currentPage;
            pageCount = x.multipage.pageCount;
            currentFieldIndex = fields.findIndex(
              (field) => field.pageNumber === currentPage
            );
            reassignFieldChecks();
            if (previousCP != x.multipage.currentPage) {
              // dislodge the textmarker
              x.fill.activeField = null;
              x.fill.currentTabIndex = -1;
              iacRender(x, x.render.canvas);
            }
            window.scrollTo(0, 0);
          }
        };

        doFinishForm = async () => {
          /* Finish, submit the IAC form */
          let submission_data = iacPrepareModelSubmission(x);

          if (targetOperationMode == IAC_MODE.RECIPIENT_FILL) {
            iacSaveForm(submission_data)
              .then(() => {
                if (!sesMode) {
                  return iacSubmitForm(x.assignmentId, x.iacDocument.id);
                } else {
                  showToast(
                    `Success! Document is being processed and will be presented for download..`,
                    1000,
                    "default",
                    "MM"
                  );
                  // In SES do not submit the form, just present it for download
                  let pdfUrl = iacGetPreviewPDF(
                    x.iacDocument.id,
                    contentsId,
                    tcId
                  );
                  console.log(`[8289] pdfUrl: ${pdfUrl}`);
                  savePDF(`/n/api/v1/dproxy/${pdfUrl}`, "test");
                  return Promise.resolve(pdfUrl);
                }
              })
              .then(() => {
                recipientChannel.push("recipient_submission");
                showToast(
                  `Success! ${fillType != 'recipient' ? 'Text inputs have been saved.' : 'Document submitted.'}`,
                  1000,
                  "default",
                  "MM"
                );
                setTimeout(() => {
                  window.location = `/n/recipient#dashboard?a=${x.assignmentId}`;
                }, 1000); // wait a second before changing screen.
              });
          } else if (targetOperationMode == IAC_MODE.REQUESTOR_FILL) {
            iacSaveForm(submission_data).then(() => {
              if (isDirectSend) {
                // direct send checklist
                assignContents({
                  id: contentsId,
                  requestorUniqueIdentifier: null,
                })
                  .then(() => {
                    showToast(
                      `Success! Template sent. The other party will receive a link in an email to complete. If you need to view this request, go to the dashboard`,
                      1000,
                      "default",
                      "MM"
                    );
                    setTimeout(
                      () => (window.location.href = `#directsend`),
                      1500
                    );
                  })
                  .catch((error) => {
                    console.error(error.message);
                    showToast(
                      `Success! Error while sending the templates`,
                      1000,
                      "error",
                      "MM"
                    );
                  });
              } else {
                if (editMode) {
                  requestorChannel.push("requestor_update");
                  // send email notification
                  sendUpdatedDocumentEmailNotification(
                    x.iacDocument.id,
                    updateNote
                  );
                  showToast(
                    `Success! Document updated and send. The other party will get an email with a link to the updated document.`,
                    1000,
                    "default",
                    "MM"
                  );

                  setTimeout(() => {
                    window.history.go(-1);
                  }, 1500);
                  return;
                }
                if (sesMode) {
                  showToast(
                    `Success! Document is being generated..`,
                    1000,
                    "default",
                    "MM"
                  );
                  // In SES do not submit the form, just present it for download
                  let pdfUrl = iacGetPreviewPDF(
                    x.iacDocument.id,
                    contentsId,
                    tcId
                  );
                  pdfUrl
                    .then((x) => x.json())
                    .then(async (res) => {
                      let info = await documentInformation(
                        x.iacDocument,
                        recipientId
                      );
                      return {
                        info: info,
                        res: res,
                      };
                    })
                    .then((x) => {
                      let res = x.res;
                      let info = x.info;
                      console.log(`[8289] pdfUrl: ${res.fn}`);
                      let final_name = info.rName.replaceAll(" ", "_");
                      let final_doc_name = info.docName.replaceAll(" ", "_");
                      const currentDate = new Date();
                      const dateObj = getDateObject(currentDate);
                      const date_str = iacGetDateString(dateObj);
                      savePDF(
                        `/n/api/v1/dproxy/${res.fn}`,
                        `${final_name}_${final_doc_name}_${date_str}`
                      );
                      setTimeout(() => {
                        window.location = `/n/requestor#recipient/${recipientId}/details/data`;
                      }, 1000); // wait a second before changing screen.
                    });
                  return;
                } else {
                  showToast(
                    `Success! ${fillType != 'recipient' ? 'Text inputs have been saved.' : 'Document submitted.'}`,
                    1000,
                    "default",
                    "MM"
                  );
                  setTimeout(() => {
                    if (assigneeId != -1) {
                      // IAC fill was routed from the IAC setup process. In future, if need to have a different url to go; use redirect url in query params
                      window.location.href = `#recipient/${recipientId}/assign/${assigneeId}`;
                    } else {
                      window.history.go(-1);
                    }
                  }, 1000); // wait a second before changing screen.
                }
              }
            });
          } else if (targetOperationMode == IAC_MODE.REVIEW) {
            iacSaveForm(submission_data).then(() => {
              counterSignSuccessDialogStatus = JSON.parse(
                localStorage.getItem("dontShowCounterSignSuccessDialog")
              );
              if (counterSignSuccessDialogStatus) {
                if (finishCallback) {
                  finishCallback();
                  return;
                }
                window.history.go(-1);
              } else {
                showCounterSignSuccessDialog = true;
              }
            });
          }
        };

        doCancelForm = () => {
          fieldIds = Array.from($storeSignatureFields);
          if (fieldIds.length > 0 || $inputBoxClicked) {
            showCancelConfirmationDialog = true;
          } else {
            console.log("go back");
            window.history.go(-1);
          }
        };

        doSaveForm = () => {
          let submission_data = iacPrepareModelSubmission(x);
          isFinishedIAC = true;
          if (targetOperationMode == IAC_MODE.RECIPIENT_FILL) {
            /* Finish, submit the IAC form */
            iacSaveForm(submission_data).then(() => {
              showToast(
                `Success! Changes saved, but document not submitted yet.`,
                1000,
                "default",
                "MM"
              );
              setTimeout(() => {
                window.location = `/n/recipient#dashboard?a=${x.assignmentId}`;
              }, 1000); // wait a second before changing screen.
            });
          } else if (targetOperationMode == IAC_MODE.REQUESTOR_FILL) {
            iacSaveForm(submission_data).then(() => {
              showToast(
                `Success! Changes saved, but document not submitted yet.`,
                1000,
                "default",
                "MM"
              );
              setTimeout(() => {
                window.history.go(-1);
              }, 1000); // wait a second before changing screen.
            });
          }
          isFinishedIAC = false;
        };

        // find empty tables
        if (x.sesMode) {
          let params = searchParamObject();
          console.log(params);
          if (params.empty != undefined) {
            if (params.empty.includes(",")) {
              x.tables.empty = params.empty.split(",");
            } else {
              x.tables.empty = [params.empty];
            }
          }
        }

        // render it
        iacRender(x, canvas).then(() => {
          pageCount = x.multipage.pageCount;
          currentPage = x.multipage.currentPage;
          showAndroidWarning = isAndroidMobile();
          console.log(`pageCount = ${pageCount} currentPage = ${currentPage}`);
          isIACRendered = true;
          reassignFieldChecks();
        });
        return x;
      });
  }

  function pdfJsLoaded() {
    console.log("pdfjs loaded");
    loaded = true;
    if (mounted) {
      init();
    }
  }

  function onCancelChanges(customMessage = "") {
    iacDelEsign(iacDocId, fieldIds, fillType).then(() => {
      showToast(`Changes Discarded. ${customMessage}`, 1000, "default", "MM");
      setTimeout(() => window.history.go(-1), 1000);
    });
  }

  function decodeQueryParam(p) {
    return decodeURIComponent(p.replace(/\+/g, " "));
  }

  function setReason() {
    let location = window.location.href;
    console.log(location);
    let queryParams = location.split("?")[1]?.split("&");
    if (queryParams) {
      for (let i = 0; i < queryParams.length; i++) {
        let param = queryParams[i].split("=");
        if (param[0] == "reason") {
          reason = decodeQueryParam(param[1]);
          break;
        }
      }
    }
  }

  $: {
    if (pageCount) {
      for (let i = 0; i < pageCount; i++) {
        checkEmptyFieldBoxStatusPages[i] = false;
      }
    }
  }

  let windowInnerWidth, elmWidth;
  onMount(() => {
    let body = document.querySelector("body");
    body.style.margin = "0px";
    console.log("iac mounted");
    windowInnerWidth = window.innerWidth;
    mounted = true;
    if (loaded) {
      init();
    }

    setReason();
  });

  $: {
    if (isIACRendered && reason) {
      showReasonDialog = true;
    }
  }

  let requestorChannel, recipientChannel;
  const leaveChannel = (fillType) => {
    switch (fillType) {
      case "recipient":
        return recipientChannel.leave();
      case "requestor":
        if (editMode) requestorChannel.leave();
        return;
      default:
        return;
    }
  };

  onDestroy(() => {
    storeSignatureFields.set([]); // reset state
    inputBoxClicked.set(false);
    iacModel.then((x) => iacModelDestroy(x));

    leaveChannel(fillType);
  });

  let isDownloadReady = false;

  async function documentInformation(iacDoc, rId) {
    //IACDoc has document_id and template_id which both represents the raw_document on different scenarios

    // document id is the unique id for that raw document when we creates a template or swap a template
    // when we creates a template the document_id is the raw_document_id in iacDocuments table
    // when swapped for that document, the template_id is of the original raw_document is added in rawdocument_id column
    // when its swapped, the original raw document id is the template_id
    docId = iacDoc.template_id > 0 ? iacDoc.template_id : iacDoc.document_id;
    let doc;
    let recipientUser;
    try {
      const client = fillType === "recipient" ? "recipient" : "requestor";
      doc = await getTemplate(docId, client);
      recipientUser = await getRecipient(rId);

      let docName = doc.name ? doc.name : "Document Name Unavailable";
      isDownloadReady = true;
      return {
        docName: capitalizeFirstLetter(docName),
        docDescription: capitalizeFirstLetter(doc.description),
        rName: capitalizeFirstLetter(recipientUser.name),
        rMail: recipientUser.email,
        rCompany: recipientUser.company,
      };
    } catch (e) {
      console.error("error getting recipient document Information");
      console.error(e);
    }
  }

  let canvas;
  let iacInputFaker;

  const handleNextField = () => {
    const lastFieldIndex = fields.length - 1;
    if (lastFieldIndex === currentFieldIndex) return;
    const nextFieldIndex = fields.findIndex(
      (field) => field.pageNumber > currentPage
    );
    currentFieldIndex = nextFieldIndex;
    if (nextFieldIndex === -1) return;
    const { pageNumber } = fields[nextFieldIndex];
    if (currentPage !== pageNumber) doNextPage(pageNumber);
  };

  const handlePrevField = () => {
    if (currentFieldIndex === 0 && currentFieldIndex < 0) return;
    const prevFieldIndex = fields.findIndex(
      (field) => field.pageNumber < currentPage
    );
    currentFieldIndex = prevFieldIndex;
    if (prevFieldIndex === -1) return;
    const { pageNumber } = fields[prevFieldIndex];
    if (currentPage !== pageNumber) doPrevPage(pageNumber);
  };
  // export let checklistName = "";
  // export let reference = "";

  $: {
    if (fillType === "requestor" && editMode)
      isRecipientOnline = $isRecipientInFillMode;
    if (fillType === "recipient") {
      disableRecipientFill = $isRequestorInEditMode;
      window.temp_disable_recipient_fill = $isRequestorInEditMode;
    }
    if (fillType === "review") {
      isRecipientOnline = $isRecipientInFillMode;
      disableRequestorReviewProcess = $isRecipientInFillMode;
      window.temp_disable_review_fill = disableRequestorReviewProcess;
    }
  }

  function autoReloadOption() {
    showToast(
      "Content Updated by recipient, Refreshing broswer page",
      1500,
      "default",
      "MM"
    );
    window.location.reload();
    return;
  }
</script>

<svelte:head>
  <script
    src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.9.359/pdf.min.js"
    on:load={pdfJsLoaded}></script>
</svelte:head>

{#await iacDocument then doc}
  {#await documentInformation(doc, recipientId) then contactInformation}
    <NavBar
      navbar_spacer_classes="navbar_spacer_pb1_desktop navbar_spacer_pb1"
      middleText={`${contactInformation.docName}`}
      middleSubText={fillType === "review"
        ? `Countersign/Fill: ${contactInformation.rName} (${contactInformation.rMail})`
        : `${contactInformation.docDescription || ""}`}
      windowType={fillType == "recipient" ? fillType : "requestor"}
      showLogo={false}
      longLeft={true}
      isOnline={isRecipientOnline}
      showCompanyLogo={false}
      backLink={fillType != "review" ? "" : " "}
      backLinkHref="javascript: window.history.go(-1);"
      renderOnlyIcon={!editMode && !fromSetup && fillType != "review"
        ? true
        : false}
      showTooltip={true}
      tooltipMessage="Back arrow will save changes but not submit/ complete the document."
      on:arrowClicked={editableDoc
        ? () => {
            window.location = `/n/recipient#dashboard`;
          }
        : doSaveForm()}
    />
  {/await}
{/await}

<SwipeWrapper
  on:swipeLeft={() => {
    if (currentPage != pageCount - 1) {
      pageLoading = true;
      setTimeout(() => {
        doNextPage();
        pageLoading = false;
      }, 200);
    }
  }}
  on:swipeRight={() => {
    if (currentPage != 0) {
      pageLoading = true;
      setTimeout(() => {
        doPrevPage();
        pageLoading = false;
      }, 200);
    }
  }}
>
  {#if !isIACRendered || isFinishedIAC || pageLoading}
    <Loader loading absoluteLoader={isFinishedIAC} />
  {/if}
  <div class="container">
    <PageNavigation
      {currentPage}
      {pageCount}
      pageLoading={!isIACRendered || isFinishedIAC || pageLoading}
      on:doPrevPage={() => {
        pageLoading = true;
        setTimeout(() => {
          doPrevPage();
          pageLoading = false;
        }, 200);
      }}
      on:doNextPage={() => {
        pageLoading = true;
        setTimeout(() => {
          doNextPage();
          pageLoading = false;
        }, 200);
      }}
    />

    <div class:iac={isIACRendered} class:hidden={pageLoading}>
      <canvas bind:this={canvas} id="bp-iac-canvas" />
    </div>

    <input
      type="text"
      tabindex="-1"
      class="iac-input-faker"
      bind:this={iacInputFaker}
    />
  </div>
</SwipeWrapper>

<div class="desktop-only">
  <BottomBar
    IACDoc={true}
    leftButtons={[
      {
        button: "Cancel",
        color: "white",
        disabled: false,
        ignore: !isIACRendered || fillType != "recipient",
        evt: "cancel",
      },
      {
        button: "Previous Field",
        color: "white",
        disabled: !hasPrevField,
        ignore: !isIACRendered,
        evt: "prevField",
      },
      {
        button: "<< Previous Page",
        color: "white",
        disabled: currentPage == 0,
        ignore: !isIACRendered,
        evt: "prev",
      },
      {
        button: "Download",
        evt: "download",
        color: "white",
        icon: "download",
        disabled: !isDownloadReady,
        ignore: !file_name || sesMode || fillType == "recipient",
      },
    ]}
    rightButtons={[
      {
        button: "Next Page with fields",
        color: "white",
        disabled: !hasNextField,
        ignore: !isIACRendered,
        evt: "nextField",
      },
      {
        button: "Next Page >>",
        color: "white",
        loading: currentPage == pageCount - 1,
        disabled: false,
        ignore: !isIACRendered || currentPage == pageCount - 1,
        evt: "next",
      },
      {
        button: isDirectSend
          ? "Send"
          : editableDoc
          ? "Update"
          : sesMode
          ? "Download & Finish"
          : editMode
          ? "Update & resend"
          : showRefereshButton
          ? "Refresh"
          : fillType == "requestor"
          ? "Continue"
          : "Finish",
        color:
          editableDoc || currentPage == pageCount - 1
            ? "primary"
            : editMode
            ? "secondary"
            : "white",
        disabled:
          isFinishedIAC ||
          disableRecipientFill ||
          disableRequestorReviewProcess,
        showTooltip: disableRecipientFill || disableRequestorReviewProcess,
        tooltipMessage: socketToolTipMessage,
        ignore:
          !isIACRendered ||
          (fillType === "recipient" && currentPage != pageCount - 1),
        evt: showRefereshButton ? "refreshPage" : "finish",
      },
    ]}
    centerButtons={[]}
    on:save={doSaveForm}
    on:refreshPage={() => {
      showRefereshButton = false;
      window.location.reload();
    }}
    on:prev={() => doPrevPage()}
    on:next={() => {
      if (
        iacPageFieldValidation(selectedModel) &&
        !checkEmptyFieldBoxStatusPages[currentPage]
      ) {
        showPageEmptyFieldsConfirmationDialog = true;
      } else {
        doNextPage();
      }
    }}
    on:finish={() => {
      iacModel.then((model) => {
        // removes active state listener for text field
        model.fill.activeField = null;

        if (iacAllFieldValidation(selectedModel)) {
          showFinishFieldValidationDialog = true;
          return;
        }
        if (editMode) {
          showUpdateNoteAddOption = true;
          return;
        }
        isFinishedIAC = true;
        doFinishForm();
      });
    }}
    on:nextField={() => {
      if (
        iacPageFieldValidation(selectedModel) &&
        !checkEmptyFieldBoxStatusPages[currentPage]
      ) {
        showPageEmptyFieldsConfirmationDialog = true;
        nextFieldConfirmation = true;
      } else {
        handleNextField();
      }
    }}
    on:prevField={handlePrevField}
    on:cancel={doCancelForm}
    on:download={() => {
      if (isRsdcType && (fillType == "recipient" || fillType == "requestor")) {
        window.location = `/package/customize/${assignmentContentsId}/${recipientId}/${customizationId}/download`;
      } else if (fillType == "requestor") {
        window.location = `/rawdocument/${rawDocumentId}/download`;
      } else {
        window.location = `/document/${assignmentId}/${docId}/download`;
      }
    }}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      doPageForwarder(pageNumber);
    }}
    hasPageNavigation
    {windowInnerWidth}
    {currentPage}
    {pageCount}
  >
    <span slot="right-slot-start">
      {#if isIACRendered && reason}
        <span
          on:click={() => {
            showReasonDialog = true;
          }}
          style="color: red; cursor: pointer;"
          ><FAIcon icon="exclamation-circle" iconStyle="solid" iconSize="2x" />
        </span>
      {/if}
    </span>
  </BottomBar>
</div>

<div class="mobile-only">
  <BottomBar
    containerClasses="h-3 px-1 container-flex-end"
    navbarClasses="p-0 gap-0"
    IACDoc={true}
    rightButtons={[]}
    leftButtons={[
      {
        button: "<< Previous Page",
        color: "white",
        disabled: currentPage == 0,
        ignore: !isIACRendered,
        evt: "prev",
      },
      {
        button: "Next Page >>",
        color: "white",
        loading: currentPage == pageCount - 1,
        disabled: false,
        ignore: !isIACRendered || currentPage == pageCount - 1,
        evt: "next",
      },
      {
        button: isDirectSend
          ? "Send"
          : editableDoc
          ? "Update"
          : showRefereshButton
          ? "Refresh"
          : fillType == "requestor"
          ? "Continue"
          : "Submit",
        color: editableDoc
          ? "primary"
          : currentPage == pageCount - 1
          ? "primary"
          : "white",
        disabled: disableRecipientFill || disableRequestorReviewProcess,
        showTooltip: disableRecipientFill || disableRequestorReviewProcess,
        tooltipMessage: socketToolTipMessage,
        ignore:
          !isIACRendered ||
          (fillType === "recipient" && currentPage != pageCount - 1),
        evt: showRefereshButton ? "refreshPage" : "finish",
      },
    ]}
    on:refreshPage={() => {
      showRefereshButton = false;
      window.location.reload();
    }}
    on:save={doSaveForm}
    on:finish={() => {
      if (iacAllFieldValidation(selectedModel)) {
        showFinishFieldValidationDialog = true;
        return;
      }
      if (editMode) {
        showUpdateNoteAddOption = true;
        return;
      }
      isFinishedIAC = true;
      doFinishForm();
    }}
    on:nextField={() => {
      skipPagesWarningDialogBox = true;
      checkSkipPagesWarningDialogBoxStatus = JSON.parse(
        localStorage.getItem("dontShowSkipPagesWarningDialogBox")
      );
      if (
        checkSkipPagesWarningDialogBoxStatus ||
        !checkSkipPagesWarningOnceDialogBoxStatus
      ) {
        handleNextField();
      }
    }}
    on:prevField={handlePrevField}
    on:prev={() => doPrevPage()}
    on:next={() => {
      if (
        iacPageFieldValidation(selectedModel) &&
        !checkEmptyFieldBoxStatusPages[currentPage]
      ) {
        showPageEmptyFieldsConfirmationDialog = true;
      } else {
        doNextPage();
      }
    }}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      doPageForwarder(pageNumber);
    }}
    hasPageNavigation
    {windowInnerWidth}
    {currentPage}
    {pageCount}
  />
</div>

{#if showUpdateNoteAddOption}
  <ReturnModal
    modaltitle={"Update Notes"}
    placeholderText={"Update notes for Contact"}
    customButtonText={"Finish & send"}
    {closeModal}
    doReturnIt={(comment) => {
      updateNote = comment;
      // TODO: move this flag to doFinishIAC function
      isFinishedIAC = true;
      doFinishForm();
      showUpdateNoteAddOption = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showCancelConfirmationDialog}
  <ConfirmationDialog
    title="Warning!"
    question="Changes will be lost, cancel anyway?"
    yesText="Yes, cancel"
    noText="No, I'll stay"
    yesColor="primary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => (showCancelConfirmationDialog = false)}
    on:yes={onCancelChanges}
  />
{/if}

{#if showFinishFieldValidationDialog}
  <ConfirmationDialog
    title="Warning! Empty Fields"
    question="There are still open fields on this document you have not completed. They are highlighted with a red box around them. If possible, please complete before submitting. "
    yesText="Close and finish anyway"
    noText="Back to edit"
    yesColor="white"
    noColor="secondary"
    noLeftAlign={true}
    on:close={() => (showFinishFieldValidationDialog = false)}
    on:yes={() => {
      showFinishFieldValidationDialog = false;
      if (editMode) {
        showUpdateNoteAddOption = true;
        return;
      }
      isFinishedIAC = true;
      doFinishForm();
    }}
  />
{/if}

{#if showPageEmptyFieldsConfirmationDialog}
  <ConfirmationDialog
    title="Warning!"
    question="There are unfilled fields on this page. Proceed anyway?"
    yesText="Yes, proceed"
    noText="No, stay and fill "
    yesColor="primary"
    noColor="white"
    noLeftAlign={true}
    checkBoxEnable={"enable"}
    checkBoxText={"Don't ask me again for this page"}
    bind:CheckBoxStatus={emptyFieldCheckBoxStatus}
    on:close={() => {
      showPageEmptyFieldsConfirmationDialog = false;
      nextFieldConfirmation = false;
    }}
    on:no={() => {
      showPageEmptyFieldsConfirmationDialog = false;
      nextFieldConfirmation = false;
    }}
    on:yes={() => {
      checkEmptyFieldBoxStatusPages[currentPage] = emptyFieldCheckBoxStatus;
      emptyFieldCheckBoxStatus = false;
      showPageEmptyFieldsConfirmationDialog = false;
      if (nextFieldConfirmation) {
        handleNextField();
      } else {
        doNextPage();
      }
      nextFieldConfirmation = false;
    }}
  />
{/if}

{#if showNotLastPageConfirmationDialog}
  {#if checkNotLastPageConfirmationDialogStatus !== true}
    <ConfirmationDialog
      title="Confirmation"
      question="You have not reached the last page of this document, finish anyway?"
      yesText="Yes, finish"
      noText="No, cancel"
      yesColor="primary"
      noColor="white"
      noLeftAlign={true}
      checkBoxEnable={"enable"}
      checkBoxText={"Don't ask me this again"}
      on:close={() => {
        showNotLastPageConfirmationDialog = false;
      }}
      on:yes={(event) => {
        if (event?.detail === true) {
          localStorage.setItem(
            "dontShowNotLastPageConfirmationDialog",
            event?.detail
          );
        } else {
          localStorage.setItem("dontShowNotLastPageConfirmationDialog", false);
        }
        showNotLastPageConfirmationDialog = false;
        isFinishedIAC = true;
        doFinishForm();
      }}
    />
  {/if}
{/if}

{#if showAndroidWarning}
  {#if checkAndroidWarningDialogStatus !== true}
    <ConfirmationDialog
      title="Android Warning!"
      question="Some online form filling features may be unavailable for a small number of Android mobile devices and tablets, or you may experience odd behavior. If you have any issues, please try on another device. We apologize for any inconvenience."
      hideText="Got it"
      hideColor="white"
      noLeftAlign={true}
      checkBoxEnable={"enable"}
      checkBoxText={"Don't ask me this again"}
      on:close={() => (showAndroidWarning = false)}
      on:hide={(event) => {
        if (event?.detail === true) {
          localStorage.setItem("dontShowAndroidWarning", event?.detail);
        } else {
          localStorage.setItem("dontShowAndroidWarning", false);
        }
        showAndroidWarning = false;
      }}
    />
  {/if}
{/if}
{#if showReasonDialog}
  <ConfirmationDialog
    title="Reason for Return"
    on:close={() => (showReasonDialog = false)}
  >
    <div class="reason-container">
      {@html reason}
    </div>
  </ConfirmationDialog>
{/if}

{#if skipPagesWarningDialogBox}
  {#if checkSkipPagesWarningDialogBoxStatus !== true}
    {#if checkSkipPagesWarningOnceDialogBoxStatus}
      <ConfirmationDialog
        title="Skipping pages warning!"
        question="You are still responsible for all the contents of a document, even if you choose to skip pages to reach the next fillable field."
        yesText="Agree and continue"
        yesColor="white"
        noText="Cancel"
        noColor="white"
        noLeftAlign={true}
        checkBoxEnable={"enable"}
        checkBoxText={"Don't ask me this again"}
        on:close={(event) => {
          if (event?.detail === true) {
            localStorage.setItem(
              "dontShowSkipPagesWarningDialogBox",
              event?.detail
            );
          } else {
            localStorage.setItem("dontShowSkipPagesWarningDialogBox", false);
          }
          skipPagesWarningDialogBox = false;
        }}
        on:yes={(event) => {
          if (event?.detail === true) {
            localStorage.setItem(
              "dontShowSkipPagesWarningDialogBox",
              event?.detail
            );
          } else {
            localStorage.setItem("dontShowSkipPagesWarningDialogBox", false);
          }
          handleNextField();
          checkSkipPagesWarningOnceDialogBoxStatus = false;
          skipPagesWarningDialogBox = false;
        }}
      />
    {/if}
  {/if}
{/if}

{#if showCounterSignSuccessDialog}
  {#if counterSignSuccessDialogStatus !== true}
    <ConfirmationDialog
      title={"Countersign successful"}
      details={"The other party will get an email notification to access the completed document."}
      hideText={"Close"}
      hideColor={"white"}
      checkBoxEnable={"enable"}
      checkBoxText={"Don't show this again"}
      on:close={(event) => {
        if (event?.detail) {
          localStorage.setItem(
            "dontShowCounterSignSuccessDialog",
            event?.detail
          );
        } else {
          localStorage.setItem("dontShowCounterSignSuccessDialog", false);
        }
        showCounterSignSuccessDialog = false;
        console.log(disableRequestorReviewProcess);
        if (disableRequestorReviewProcess || showRefereshButton) {
          autoReloadOption();
          return;
        }
        if (finishCallback) {
          finishCallback();
          return;
        }
        window.history.go(-1);
      }}
      on:hide={(event) => {
        if (event?.detail) {
          localStorage.setItem(
            "dontShowCounterSignSuccessDialog",
            event?.detail
          );
        } else {
          localStorage.setItem("dontShowCounterSignSuccessDialog", false);
        }
        showCounterSignSuccessDialog = false;

        if (disableRequestorReviewProcess || showRefereshButton) {
          autoReloadOption();
          return;
        }
        if (finishCallback) {
          finishCallback();
          return;
        }
        window.history.go(-1);
      }}
    />
  {/if}
{/if}

<style>
  .iac {
    padding-left: 10%;
    padding-right: 10%;
    padding-top: 2rem;
  }
  .hidden {
    visibility: hidden;
  }

  .iac > canvas {
    border: 1px solid black;
    margin-bottom: 4rem;
    z-index: 1;
  }

  .iac-input-faker {
    opacity: 0;
    position: fixed;
    top: 0;
    left: 0;
    z-index: 0;
  }
  .mobile-only {
    display: none;
  }
  .container {
    display: flex;
    align-items: flex-start;
    position: relative;
    padding: 2rem 1rem;
  }
  .reason-container {
    font-family: "Nunito", sans-serif;
  }
  @media only screen and (max-width: 767px) {
    .iac {
      padding: 1rem 0.5rem;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
    .container {
      padding: 3rem 0rem;
    }
  }
</style>
