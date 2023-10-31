<script>
  import { FORM_EDITABLE_STATES } from "BoilerplateAPI/Form";
  import { convertTime } from "Helpers/util";
  import NavBar from "../../components/NavBar.svelte";
  import DocumentRequestView from "../../components/RecipientDashboardHelpers/DocumentRequestView.svelte";
  import FileRequestView from "../../components/RecipientDashboardHelpers/FileRequestView.svelte";
  import Button from "../../atomic/Button.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import DashboardStatus from "../../components/DashboardStatus.svelte";
  import { status_to_buttontext } from "../../util/StatusIcons.svelte";
  import { featureEnabled } from "Helpers/Features";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import {
    markFileRequestMissing,
    uploadMultipleFileRequest,
    uploadRequestAsSeparateFileRequests,
    submitFileRequest,
    uploadDocument,
    uploadTaskConfirmationDocument,
    uploadFilledRequest,
    markAsDone,
    sendUploadedAdditionalFiles,
    requestExpirationInfo,
  } from "BoilerplateAPI/RecipientPortal";
  import { convertUTCToLocalDateString } from "../../../helpers/dateUtils";
  import UploadFileModal from "../../modals/RecipientUploadFileModal.svelte";
  import { getAssignments } from "BoilerplateAPI/Assignment";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import { getQueryParams } from "../../../helpers/getQueryParams.js";
  import { reportCrash } from "BoilerplateAPI/CrashReporter";
  import printJS from "print-js";
  import RepeatChecklist from "./RepeatChecklist.svelte";
  import { onMount } from "svelte";
  import {
    recipientDashboardDownloadUrl,
    allowedIACFileTypes,
    allowedIACImageTypes,
  } from "../../../helpers/fileHelper";
  import { getCompanies } from "BoilerplateAPI/Recipient";
  import ChecklistCompleteModal from "../../modals/ChecklistCompleteModal.svelte";
  import { isBrowserTypeSafari } from "Helpers/util";
  import { editSendChecklist } from "BoilerplateAPI/Checklist";
  import { isMobile, requestorDashboardStatus } from "../../../helpers/util";
  import AddExpirationDate from "../../components/AddExpirationDate.svelte";
  import RecipientHeader from "../../components/RecipientHeader.svelte";
  import DocStatusSm from "../../atomic/molecules/DocStatusSm.svelte";
  import ClickButton from "../../atomic/ClickButton.svelte";
  import Loader from "../../components/Loader.svelte";
  import { getDocumentCompletion } from "../../../api/RecipientPortal";

  let missing_reasons = [
    { t: "Can't Locate", i: "map-marker-question" },
    { t: "Doesn't Exist", i: "file-times" },
    { t: "Expired", i: "exclamation" },
    { t: "Decline To Provide", i: "times-octagon" },
    { t: "Prefer Hard Copy", i: "hand-holding" },
    { t: "Not Applicable / Other", i: "comment-alt-times" },
  ];

  let guidePoints = [
    "We're a secure portal used by your requester to collect documentation and e-signatures.",
    "Follow the buttons on the screen to access and complete each item. If a file requests is unavailable, use the unavailable button and select a reason. Your requester will be automatically notified of your submissions. After they've reviewed, you'll get an email if there are any revision requests",
    "If you'd like copies of your documents, please download from the portal after completion. Future availability is set by your requester and may be limited for security purposes.",
    "If a document requires a countersignature after you've submitted, you'll be notified once they have signed and get a link to download a copy of the document from your Boilerplate account. It will be available for a limited time set by your requester. ",
    "Questions about the request contents should go to your requester, but you can use the chat bot in the bottom right for any technical issues.",
  ];
  let showClientGuideDialog = false;
  let checkClientGuideStatus = JSON.parse(
    localStorage.getItem("dontshowClientGuideDialog")
  );
  let showOnceClientGuideDialog = JSON.parse(
    window.sessionStorage?.getItem("showOnceClientGuideDialog")
  );
  let numCompanies;
  let organization = "";
  let elements = [];
  let chevron_state;
  let filereq_edit = -1;
  const isSafari = isBrowserTypeSafari();
  const EXTRAFILEUPLOADSDEFAULTNAME = "+ Add additional files (optional)";
  const EXTRAFILEUPLOADSDEFAULTDESCRIPTION =
    "Use to submit files that were not line items in checklist";
  const statusText = {
    "0": "Open",
    "1": "In Progress",
    "2": "Ready for review",
    "3": "Returned for updates",
    "4": "Submitted",
    "5": "Unavailable",
    "6": "Unavailable",
    "7": "In progress",
    undefined: "UNKNOWN",
  };
  let uploadAdditionalFiles = false;

  let taskToBeViewed = null;
  let showTaskDetails = false;
  let showTaskConfirmation = false;
  let dataRequestFocus = false;
  function findA() {
    var result = -1,
      tmp = [];
    if (location.hash.includes("?")) {
      location.hash
        .split("?")[1]
        .split("&")
        .forEach(function (item) {
          tmp = item.split("=");
          if (tmp[0] === "a") result = parseInt(decodeURIComponent(tmp[1]), 10);
        });
    }
    console.log(`findA = ${result}`);
    return result;
  }
  function getQueryStrings(assignment) {
    const name = `name=${encodeURIComponent(assignment?.name)}`;
    const ref = assignment.recipient_reference
      ? `&ref=${encodeURIComponent(assignment.recipient_reference)}`
      : "";

    return `${name}${ref}`;
  }
  let defaultOpenAssignment;
  let taskConfirmationFIleSubmitMessage = "";
  let checklistCompletedDialog = false;
  let currentSubmittedAssignment;
  let currentAssignmentID;
  let focusStatus = false;
  function isChecklistComplete(assignments) {
    if (currentAssignmentID) {
      currentSubmittedAssignment = assignments.find(function (item) {
        return currentAssignmentID == item.id;
      });
      if (currentSubmittedAssignment) {
        let {
          state: { status },
        } = currentSubmittedAssignment;
        if (status == 2 || status == 4) {
          checklistCompletedDialog = true;
        }
      }
    }
  }
  //we want to expand the unfilled checklists by default when it is created
  onMount(() => {
    const params = getQueryParams();
    if (params.a) {
      currentAssignmentID = parseInt(params.a, 10);
    }

    //getting assingments promise
    getAssignments()
      .then(async (assignments) => {
        //checking the items that have status 0 (unfilled lists)
        isChecklistComplete(assignments);

        assignments.forEach((item, i) => {
          if (!item.state.status) {
            //disable the main start button
            document
              .querySelector(`#checklist-toggle-${i}`)
              .querySelector("button")
              .classList.add("disabled");
          }

          //we want to expand if any tasks are completed
          if (item.file_requests.length != 0) {
            const { file_requests } = item;

            const taskFile = file_requests.filter(
              (file) => file.type === "task" && file.state.status == 2
            );

            //dont need to iterate over all of one because if one element is true need to expand the whole checklist
            if (taskFile.length != 0) {
              //disable the main start button
              document
                .querySelector(`#checklist-toggle-${i}`)
                .querySelector("button")
                .classList.add("disabled");
            }

            //expand checklist if a file marked as unavailable
            const unavailableFiles = file_requests.filter(
              (file) =>
                file.type === "file" &&
                (file.state.status == 5 || file.state.status == 6)
            );

            if (unavailableFiles.length != 0) {
              //disable the main start button
              document
                .querySelector(`#checklist-toggle-${i}`)
                .querySelector("button")
                .classList.add("disabled");
            }
          }

          //expand if one of a secured file was viwed
          if (item.document_requests.length != 0) {
            const { document_requests } = item;
            const docsStatus = document_requests.filter(
              (doc) => doc.state.status == 4
            );

            if (docsStatus.length != 0) {
              //disable the main start button
              document
                .querySelector(`#checklist-toggle-${i}`)
                .querySelector("button")
                .classList.add("disabled");
            }
          }
        });
      })
      .catch((error) => console.log(error));

    showClientGuideDialog = true;
    getCompanies().then((ci) => {
      numCompanies = ci?.recipient_companies;
      organization = ci?.current_recipient_company_name || "";
      elements = numCompanies.map((c) => {
        return { ret: c.id, text: c.name };
      });
    });
  });

  function dropdownClickFile(assignment, actionId, request, type) {
    if (request.state.status != 2) {
      console.log("assignment", assignment);
      window.sessionStorage.setItem("recipientRecentChecklist", assignment.id);
    }
    console.log(
      `dropdownClickFile: actionId ${actionId} request ${request} type ${type}`
    );

    if (actionId != 6) {
      markFileRequestMissing(
        assignment,
        request,
        missing_reasons[actionId].t
      ).then(async () => {
        assignments = await getAssignments();
        currentAssignmentID = assignment.id;
        isChecklistComplete(assignments);
      });
    } else if (actionId == 6) {
      currentAssignment = assignment;
      currentFR = request;
      showUploadFRModal = true;
    }
  }

  /**
   * @description dropdown handler for completed file requests
   * @param assignment
   * @param actionId
   * @param request
   * @param type unused
   */
  function handleCompletedFileRequestDropDown(
    assignment,
    actionId,
    request,
    type = "file"
  ) {
    switch (actionId) {
      case 11:
        window.location.href = `#submission/view/2/${assignment.id}/${request.completion_id}`;
        break;
      case 12:
        window.location = `/completedrequest/${assignment.id}/${request.completion_id}/download/completed`;
        break;
      case 17:
        showExpirationTrackEditBox = true;
        reqEditingExpirationInfo = request;
        break;
    }
  }

  let showExpirationTrackEditBox = false;
  let reqEditingExpirationInfo = null;
  let isEditable = false;
  async function dropdownClick(assignment, actionId, request, type = null) {
    console.log(
      `dropdownClick: actionId ${actionId} request ${request} type ${type}`
    );
    if (type === "file" && actionId !== 16) {
      dropdownClickFile(assignment, actionId, request, type);
      return;
    } else if (type === "data" && actionId !== 16) {
      markFileRequestMissing(
        assignment,
        request,
        "Not Applicable / Other"
      ).then(async () => {
        assignments = await getAssignments();
      });
    }
    switch (actionId) {
      case 995 /* impersonate only regenerate */:
        console.log({ request });

        if (request.state.status != 2) {
          alert("Cannot regenerate an already approved termplate!");
          break;
        }
        fetch(
          `/n/api/v1/internal/iac/regenerate?aid=${assignment.id}&rid=${assignment.recipient_id}&tid=${request.iac_document_id}`,
          {
            method: "POST",
            credentials: "include",
            body: JSON.stringify({
              aid: assignment.id,
              rid: assignment.recipient_id,
              tid: request.id,
            }),
          }
        ).then((_x) => alert(`done: ${_x.status}`));
        break;
      case 1 /* view */:
        if (type === "template") {
          window.location.href = `#submission/view/1/${assignment.id}/${request.completion_id}`;
        }
        break;

      case 3 /* print */:
        if (type === "template") {
          const downloadUrl = recipientDashboardDownloadUrl(
            assignment,
            request
          );
          printJS(downloadUrl);
        }
        break;

      case 4 /* download */:
        if (type === "template") {
          const downloadUrl = recipientDashboardDownloadUrl(
            assignment,
            request
          );
          window.location = downloadUrl;
        }
        break;

      case 2 /* edit */:
        if (type === "template") {
        } else if (request.type !== "data") {
          currentFR = request;
          currentlyStarted = request;
          currentAssignment = assignment;
          showUploadModal = true;
        }
        break;

      case 16 /* upload */:
        if (type === "file") {
          currentAssignment = assignment;
          currentFR = request;
          showUploadFRModal = true;
        }
        break;

      case 6:
        if (type === "task") {
          const { has_confirmation_file_uploaded } = request;
          uploadConfirmation = !has_confirmation_file_uploaded;
          currentAssignment = assignment;
          taskToBeViewed = request;
          showTaskConfirmation = true;
        }
        break;

      case 7:
        if (type === "task") {
          taskToBeViewed = request;
          showTaskDetails = true;
        }
        break;
      case 8:
        if (type === "task") {
          const { has_confirmation_file_uploaded } = request;
          uploadConfirmation = !has_confirmation_file_uploaded;
          taskConfirmationFIleSubmitMessage = has_confirmation_file_uploaded
            ? "This will submit the uploaded confirmation file."
            : "";
          showTaskConfirmation = true;
          taskToBeViewed = request;
        } else if (type === "data") {
          saveDataRequest(assignment, request);
        }
        break;
      case 15:
        const { iac_document_id, name, completion_id } = request;
        // Edge case:(Race condition)
        // when recipient tries to Edit document from dropdown but the requestor has completed the review from requestor dashboard
        getDocumentCompletion(1, assignment.id, completion_id).then(
          (docUpdated) => {
            if (docUpdated.status === 1) {
              window.location.hash = `#iac/fill/${iac_document_id}/${
                assignment.id
              }?name=${name}&edit=${true}&docId=${completion_id}`;
            }
            isEditable = false;
            showToast(
              "Document Already Reviewed by Requestor",
              1500,
              "default",
              "MM"
            );
          }
        );
        break;
      case 17:
        showExpirationTrackEditBox = true;
        reqEditingExpirationInfo = request;
        break;
    }
  }

  const disablePrintOption = ({ base_filename }) => {
    return (
      isSafari ||
      !(
        allowedIACFileTypes.exec(base_filename) ||
        allowedIACImageTypes.exec(base_filename)
      ) ||
      isMobile()
    );
  };

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
        assignments = await getAssignments();
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

  const getDropdownOptionsForTemplate = (x) => {
    const defaultTemplateActions = [
      {
        text: "View",
        icon: "eye",
        iconStyle: "solid",
        ret: 1,
        disabled: x.state.status !== 4,
      },
      {
        text: "Print",
        icon: "print",
        iconStyle: "solid",
        ret: 3,
        disabled: disablePrintOption(x) || isMobile(),
      },
      {
        text: "(Impersonate Only) Regenerate",
        icon: "print",
        iconStyle: "solid",
        ret: 995,
        disabled: window.__boilerplate_roleimp == "false",
      },
      {
        text: "Download",
        icon: "download",
        iconStyle: "solid",
        ret: 4,
      },
    ];

    if (x.state.status == 2) {
      isEditable = true;
      return [
        {
          text: "Edit",
          icon: "edit",
          iconStyle: "solid",
          blocked: !isEditable,
          ret: 15,
          showTooltip: !isEditable,
          disabled: !x.is_iac,
          tooltipMessage:
            "Item already reviewed by requestor. Please contact them to request a change.",
        },
        ...defaultTemplateActions,
      ];
    }
    return defaultTemplateActions;
  };

  const getRowLevelOptions = ({ state }) => {
    if (state.status == 1) {
      return [
        {
          text: "Replace",
          icon: "exchange",
          iconStyle: "solid",
          ret: 6,
          disabled: isSafari || state.status !== 1,
        },
      ];
    }
    return missing_reasons.map((x, y) => {
      return {
        text: x.t,
        icon: x.i,
        iconStyle: "solid",
        ret: y,
      };
    });
  };

  const getDropdownOptionForData = (y) => {
    switch (y) {
      case "Update":
        return [{ text: "Update", ret: 8 }];
      default:
        return [];
    }
  };

  const getDropdownOptionForTasks = (y) => {
    switch (y) {
      case "markAsDone":
        return [
          {
            text: "Mark as Done",
            ret: 6,
            icon: "check",
            iconStyle: "solid",
          },
        ];
      case "details":
        return [{ text: "Details", ret: 7 }];
      case "Returndetails":
        return [{ text: "Details", ret: 8 }];
      default:
        return [];
    }
  };

  const getDropdownOptionsForFiles = (file, y) => {
    const defaultOptions = [
      { text: "View", icon: "eye", iconStyle: "solid", ret: 11 },
      {
        text: "Download",
        icon: "download",
        iconStyle: "solid",
        ret: 12,
      },
    ];
    switch (y) {
      case "upload":
        return [
          { text: "Upload", icon: "upload", iconStyle: "solid", ret: 16 },
        ];
      default:
        return [
          ...defaultOptions,
          {
            text: "Edit Expiration",
            icon: "edit",
            iconStyle: "solid",
            ret: 17,
            disabled:
              file.state.status === 3 ||
              file.state.status === 1 ||
              file.state.status === 6 ||
              file.state.status == 0 ||
              file?.type === "task" ||
              file?.type === "data",
          },
        ];
    }
  };

  let checklistActions = (cl, type, x, y) => {
    let options = [];
    switch (type) {
      case "file":
        options = getDropdownOptionsForFiles(x, y);
        break;
      case "data":
        options = getDropdownOptionForData(y);
        break;
      case "task":
        options = getDropdownOptionForTasks(y);
        break;
      default:
        break;
    }

    return options;
  };

  const sortRequests = (req) => {
    return req.sort((a, b) => a.name.localeCompare(b.name));
  };

  function handleChevronClick(_assignment, index) {
    const newChevronState = !chevron_state[index];
    focusStatus = newChevronState;
    if (newChevronState) {
      const buttons = document
        .querySelector(`#checklist-toggle-${index}`)
        .querySelectorAll("button");
      buttons.forEach((element) => {
        element.classList.add("disabled");
      });
    } else {
      const buttons = document
        .querySelector(`#checklist-toggle-${index}`)
        .querySelectorAll("button");
      buttons.forEach((element) => {
        element.classList.remove("disabled");
      });
    }
    chevron_state[index] = newChevronState;
  }

  export let avatarInitials;
  let final_initials = "XY";
  $: Promise.resolve(avatarInitials).then((i) => (final_initials = i));
  export let assignments;
  console.log(assignments, "assignments");
  let search_value = "";
  let currentAssignment = undefined;
  let showUploadModal = false;
  let showFillModal = false;
  let currentlyStarted = undefined;
  let currentDRText = "";
  let showUploadFRModal = false;
  let currentFR = undefined;
  const ff_useFillPopup = featureEnabled("recipient_use_fill_popup");
  function clickDocumentButton(assignment, docreq) {
    currentlyStarted = docreq;

    if (
      (docreq.state.status == 0 || docreq.state.status == 3) &&
      docreq.is_iac == false
    ) {
      currentAssignment = assignment;
      showUploadModal = true;
    }
  }

  async function processDocUpload(evt) {
    let detail = evt.detail;
    let assign = currentAssignment;
    try {
      let reply = await uploadDocument(
        currentlyStarted,
        assign.recipient_id,
        assign.id,
        detail.file
      );
      if (!reply.ok) throw new Error();
      showToast(
        `Congrats! ${currentlyStarted.name} submitted successfully.`,
        1500,
        "success",
        "MM"
      );
      assignments = await getAssignments();

      currentAssignmentID = assign.id;

      isChecklistComplete(assignments);
    } catch (err) {
      showToast(
        `Sorry! Could not upload ${currentlyStarted.name}.`,
        1500,
        "error",
        "MM"
      );
      reportCrash("processDocUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
    }
    assignments = getAssignments();
    showUploadModal = false;
  }

  async function processAdditionalUploads(evt) {
    let detail = evt.detail;
    const { name, file, middleButtonPressed } = detail;
    let assign = currentAssignment;
    let reply = await sendUploadedAdditionalFiles(
      currentFR.id,
      assign.recipient_id,
      assign.id,
      name,
      file
    );
    uploadAdditionalFiles = false;
    if (reply.ok) {
      assignments = await getAssignments();
      let x = Array.from([...assignments]).filter((a) => a.id == assign.id)[0];
      showUploadFRModal = false;
      if (middleButtonPressed) {
        uploadAdditionalFiles = true;
        currentFR = await reply.json();
      } else {
        currentFR = undefined;
      }
      return x;
    } else {
      showUploadFRModal = false;
      currentFR = undefined;
      reportCrash("processFRUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
      alert("Failed to upload this file request");
    }
  }

  async function processFRUpload(evt) {
    let detail = evt.detail;
    let assign = currentAssignment;
    let reply = await uploadMultipleFileRequest(
      currentFR,
      assign.recipient_id,
      assign.id,
      detail.file
    );
    console.log(reply);

    if (reply.ok) {
      // get just uploaded doc
      const resp = await reply.json();
      if (resp.isSubmitted) {
        showToast(`Congrats! Submitted successfully.`, 1500, "default", "MM");
        window.location.reload();
      } else {
        window.location.href = `#submission/view/2/${assign.id}/${resp.id}`;
      }
    } else {
      showUploadFRModal = false;
      currentFR = undefined;
      reportCrash("processFRUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
      alert("Failed to upload this file request");
    }
  }

  async function processSeparateFRUpload(evt) {
    let detail = evt.detail;
    let assign = currentAssignment;
    let reply = await uploadRequestAsSeparateFileRequests(
      currentFR,
      assign.recipient_id,
      assign.id,
      detail.file
    );
    console.log(currentFR);

    if (reply.ok) {
      showToast(`Congrats! submitted successfully.`, 1500, "default", "MM");
      window.location.reload();
    } else {
      showUploadFRModal = false;
      currentFR = undefined;
      reportCrash("processFRUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
      alert("Failed to upload this file request");
    }
  }

  let tempSelectedID;
  $: tempSelectedID, (selectedFocusID = tempSelectedID);

  async function submitDR(assign, filereq, callbackFocusID, flag) {
    const currentPosition = document.documentElement.scrollTop;
    if (!currentDRText.trim()) return;
    try {
      let reply = await uploadFilledRequest(
        filereq,
        assign.recipient_id,
        assign.id,
        currentDRText
      );
      if (!reply.ok) throw new Error();
      filereq_edit = -1;

      assignments = await getAssignments();
      currentAssignmentID = assign.id;

      isChecklistComplete(assignments);
      currentDRText = "";
    } catch (err) {
      console.log("err", err);
      showToast(
        `Sorry! We could not submit ${filereq.name}.`,
        1500,
        "error",
        "MM"
      );
    }
  }

  function fileRequestLineClick(filereq) {
    filereq_edit = filereq.id;
    currentFR = filereq;
  }

  assignments.then((ass) => {
    defaultOpenAssignment = findA();
    chevron_state = Array.from(ass).map((x, idx) => {
      let val = x.id == defaultOpenAssignment;
      console.log(
        `idx ${idx} x.id ${x.id} doa ${defaultOpenAssignment} val ${val}`
      );
      return val;
    });
  });

  async function handleDRMsg(event) {
    currentDRText = event.detail.text;
    await submitDR(currentAssignment, currentFR);
    currentFR = undefined;
    showFillModal = false;
  }

  let selectedFocusID;
  let t = [];
  function focusHelper(id, assmnt = "_", fileReq = "_") {
    enterTyped = false;
    if (id == true) {
      currentDRText = fileReq.value;
      submitDR(assmnt, fileReq);
      currentFR = undefined;
    } else {
      t.push(id);
      selectedFocusID = tempSelectedID ? tempSelectedID : t[0];
    }
  }

  let enterTyped = false;

  let sortType1 = 1; // Checklists
  let sortType2 = 1; // Sent By
  let sortType3 = 1; // Status
  let sortType4 = 1; // Date
  function sortState(array, type) {
    let sortedArray;
    if (type == 1) {
      switch (sortType1) {
        case 1 /* Switching to ABC */:
          sortType1 = 2;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          break;
        case 2 /* Switching to ZXY */:
          sortType1 = 3;
          sortedArray = array.sort((b, a) => a.name.localeCompare(b.name));
          break;
        case 3 /* Switching to Original Array */:
          sortType1 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          console.log(sortedArray);
          break;
      }
    } else if (type == 2) {
      //Sent by
      switch (sortType2) {
        case 1 /* Switching to ABC */:
          sortType2 = 2;
          sortedArray = array.sort((a, b) =>
            a.sender.name.localeCompare(b.sender.name)
          );
          break;
        case 2 /* Switching to ZXY */:
          sortType2 = 3;
          sortedArray = array.sort((b, a) =>
            a.sender.name.localeCompare(b.sender.name)
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType2 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          console.log(sortedArray);
          break;
      }
    } else if (type == 3) {
      // Status
      switch (sortType3) {
        case 1 /* Switching to ABC */:
          sortType3 = 2;
          sortedArray = array.sort((a, b) =>
            status_to_buttontext(a.state.status).localeCompare(
              status_to_buttontext(b.state.status)
            )
          );
          break;
        case 2 /* Switching to ZXY */:
          sortType3 = 3;
          sortedArray = array.sort((b, a) =>
            status_to_buttontext(a.state.status).localeCompare(
              status_to_buttontext(b.state.status)
            )
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType3 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          console.log(sortedArray);
          break;
      }
    } else if (type == 4) {
      // Date
      switch (sortType4) {
        case 1 /* Switching to ABC */:
          sortType4 = 2;
          sortedArray = array.sort((a, b) =>
            a.state.date.localeCompare(b.state.date)
          );
          break;
        case 2 /* Switching to ZXY */:
          sortType4 = 3;
          sortedArray = array.sort((b, a) =>
            a.state.date.localeCompare(b.state.date)
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType4 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          console.log(sortedArray);
          break;
      }
    }
    assignments = Promise.resolve(sortedArray);
  }

  const saveDataRequest = (assignment, filereq, callbackFocusID) => {
    dataRequestFocus = true;
    currentDRText = filereq.value;
    submitDR(assignment, filereq, callbackFocusID, false);
  };

  const handleMarkAsDone = async () => {
    showTaskConfirmation = false;
    try {
      await markAsDone(currentAssignment, taskToBeViewed);
      assignments = await getAssignments();

      currentAssignmentID = currentAssignment.id;

      isChecklistComplete(assignments);
    } catch (err) {
      alert("Something went wrong");
      console.log("Err", err);
    }
    currentAssignment = null;
    taskToBeViewed = null;
  };

  let showFileUploadSubmitConfirmationBox = false;
  let fileUploadedId;
  let fileRequestId;

  async function processSubmitFileRequest() {
    let reply = await submitFileRequest(fileUploadedId, fileRequestId);

    if (reply.ok) {
      showFileUploadSubmitConfirmationBox = false;
      showToast(
        `Congrats! Request submitted successfully.`,
        1500,
        "white",
        "MM"
      );
      assignments = getAssignments();
    } else {
      showToast(`Sorry! Could not submit File request.`, 1500, "error", "MM");
    }
  }

  const handleProgressEvent = (evt, assignment, filereq) => {
    const { buttonClicked } = evt.detail;
    fileUploadedId = filereq.completion_id;
    fileRequestId = filereq.id;
    console.log(assignment, filereq);
    if (buttonClicked === "submit") {
      console.log("submitted");

      showFileUploadSubmitConfirmationBox = true;
    } else if (buttonClicked === "preview") {
      console.log("preview mode");
      window.location.href = `#submission/view/2/${assignment.id}/${fileUploadedId}`;
    } else {
      console.log("No event registered");
    }
  };
  let showChecklistEditNameOptionBox = false;
  let toEditChecklistName = "";
  let toEditChecklistId = -1;

  async function processChecklistEdit(evt) {
    // editSendChecklist
    console.log(evt.detail);
    const { text } = evt.detail;
    if (text.trim() !== "") {
      const reply = await editSendChecklist(toEditChecklistId, text);
      showChecklistEditNameOptionBox = false;
      if (reply.ok) {
        showToast(`Success! Checklist Name Edited.`, 400, "default", "MM");
        setTimeout(() => {
          window.location.reload();
        }, 500);
      } else {
        showToast(
          `Couldn't edit checklist name. Please try again later.`,
          1000,
          "error",
          "MM"
        );
      }
    } else {
      showToast(`Checklist Name cannot be empty`, 1500, "warning", "MM");
    }
  }

  let actions = [
    {
      evt: "upload",
      description: "Upload Confirmation.",
      icon: "upload",
    },
  ];
  let uploadConfirmation = true;
  let isConfirmationRequired = false;
  let showUploadConfirmationModal = false;

  async function processConfimationUpload(evt) {
    uploadConfirmation = false;

    const reply = await uploadTaskConfirmationDocument(
      taskToBeViewed,
      currentAssignment.id,
      evt.detail.file
    );
    showUploadConfirmationModal = false;
    if (reply.id) {
      window.location.href = `#submission/view/2/${currentAssignment.id}/${reply.id}`;
    } else {
      showToast(`Error uploading confirmation file`, 1500, "error", "MM");
    }
  }

  function markup_date(st, time) {
    return `${st.date?.split(" ")[0]} ${
      time !== undefined ? convertTime(st.date?.split(" ")[0], time) : ""
    }`;
  }

  let focus_fields = [];
  let focus_index = 0;
  function getAllDataRequestsIDs() {
    if (
      currentAssignment.file_requests &&
      currentAssignment.file_requests.length
    ) {
      focus_fields = currentAssignment.file_requests.filter(
        ({ type, state: { status } }) => {
          return type === "data" && status == 0;
        }
      );
    }
  }

  $: {
    if (currentAssignment) {
      getAllDataRequestsIDs();
    }
  }
</script>

{#if featureEnabled("internal_development")}
  <NavBar
    backLink="(INTERNAL ONLY) Requestor Portal"
    backLinkHref="/n/requestor"
    imageSrc="images/phoenix.png"
    windowType="recipient"
    isOnline={true}
    avatarInitials={final_initials}
  />
{:else}
  <NavBar
    backLink=""
    backLinkHref=""
    imageSrc="images/phoenix.png"
    windowType="recipient"
    avatarInitials={final_initials}
    leftText={organization}
    isOnline={true}
    leftBottomText=""
    elements={elements?.length > 1 ? elements : null}
  />
{/if}

{#await assignments}
  <Loader loading />
{:then final_assignments}
  <section class="main">
    <section class="header">
      <RecipientHeader
        title="Assigned Checklists"
        title_classes=""
        searchPlaceholder="Search Checklists"
        bind:search_value
        has_mobile_page_header={true}
        client_new_ui={featureEnabled("new_ui_test")}
        client_portal={!featureEnabled("new_ui_test")}
      >
        <span style="margin: 0.5rem 0 0 1rem;" slot="client-action">
          <RepeatChecklist contents={final_assignments} />
        </span>

        <div class="client-portal" slot="client_new_ui">
          <h3>Your Checklists, served fresh & hot.</h3>
        </div>
      </RecipientHeader>
      {#if final_assignments.length != 0}
        <div class="checklist-tr checklist-th">
          <div class="td chevron" />
          <div class="td checklist">
            <div
              class="sortable {sortType1 === 2 || sortType1 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(final_assignments, 1);
              }}
            >
              &nbsp; Checklist &nbsp;
              {#if sortType1 == 1}
                <div>
                  <FAIcon iconStyle="solid" icon="sort" />
                </div>
              {:else if sortType1 == 2}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-up" />
                </div>
              {:else if sortType1 == 3}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-down" />
                </div>
              {/if}
              &nbsp;
            </div>
          </div>
          <div class="td requestor">
            <div
              class="sortable {sortType2 === 2 || sortType2 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(final_assignments, 2);
              }}
            >
              &nbsp; Sent by &nbsp;
              {#if sortType2 == 1}
                <div>
                  <FAIcon iconStyle="solid" icon="sort" />
                </div>
              {:else if sortType2 == 2}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-up" />
                </div>
              {:else if sortType2 == 3}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-down" />
                </div>
              {/if}
              &nbsp;
            </div>
          </div>
          <div class="td status">
            <div
              class="sortable {sortType3 === 2 || sortType3 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(final_assignments, 3);
              }}
            >
              &nbsp; Status &nbsp;

              {#if sortType3 == 1}
                <div>
                  <FAIcon iconStyle="solid" icon="sort" />
                </div>
              {:else if sortType3 == 2}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-up" />
                </div>
              {:else if sortType3 == 3}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-down" />
                </div>
              {/if}
              &nbsp;
            </div>

            <div
              class="sortable {sortType4 === 2 || sortType4 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(final_assignments, 4);
              }}
            >
              &nbsp; Date &nbsp;
              {#if sortType4 == 1}
                <div>
                  <FAIcon iconStyle="solid" icon="sort" />
                </div>
              {:else if sortType4 == 2}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-up" />
                </div>
              {:else if sortType4 == 3}
                <div>
                  <FAIcon iconStyle="solid" icon="sort-down" />
                </div>
              {/if}
              &nbsp;
            </div>
          </div>
          <div class="td actions"><div>Actions</div></div>
        </div>
      {/if}
    </section>
    {#if final_assignments.length == 0}
      <div>
        <p
          style="color: #76808b;
          font-family: 'Lato', sans-serif;
          font-size: 16px;"
        >
          Currently no assigned or completed checklists to be viewed. If you
          feel this is in error, please contact your requestor, or
          <a href="mailto:support@boilerplate.co">support@boilerplate.co</a>.
        </p>
      </div>
    {/if}
    <div class="table">
      {#each final_assignments as assignment, i}
        {@debug assignment}
        {#if assignment.name.toLowerCase().includes(search_value.toLowerCase())}
          <div
            class="outer-border"
            class:greenShade={assignment.state.status == 2 ||
              assignment.state.status == 4}
          >
            <div
              class="checklist-tr"
              data-chevron-idx={i}
              on:click={(e) => {
                handleChevronClick(assignment, i);

                if (chevron_state[i]) {
                  currentAssignment = assignment;
                } else {
                  currentAssignment = null;
                  focus_fields = [];
                  focus_index = 0;
                }
              }}
            >
              <div class="td chevron" data-chevron-idx={i} style="display: flex; justify-content: center;">
                <div class="inner-chevron">
                  {#if chevron_state[i]}
                    <span style="color: #000;">
                      <FAIcon color={true} icon="minus" />
                    </span>
                  {:else}
                    <span style="color: #000;">
                      <FAIcon color={true} icon="plus" />
                    </span>
                  {/if}
                </div>
              </div>
              <div class="td checklist b">
                <div class="checklist-table-checklist">
                  <span
                    class="checklist-table-name truncate"
                    style="white-space: normal;"
                  >
                    {assignment.name}
                  </span>
                  {#if assignment.recipient_reference}
                    <span class="checklist-table-requestid truncate">
                      <span
                        ><b>Reference:</b>
                        {assignment.recipient_reference || ""}
                      </span>
                    </span>
                  {/if}
                  {#if assignment.requestor_reference}
                    <span class="checklist-table-requestid truncate">
                      <span style="padding-right: 10px;"
                        ><b>Requestor-Ref:</b>
                        {assignment.requestor_reference || ""}
                      </span>
                    </span>
                  {/if}
                  <span class="checklist-table-requestid truncate">
                    {#if assignment.state.status == 2 || assignment.state.status == 4}
                      <span class="mobile">
                        {requestorDashboardStatus(assignment.state.status)}: {markup_date(
                          assignment.state,
                          assignment?.received_date?.time
                        )}
                      </span>
                    {:else if Object.keys(assignment.due_date).length !== 0}
                      <span class="mobile">
                        Due: {convertUTCToLocalDateString(
                          assignment.due_date.date
                        )}
                      </span>
                    {:else}
                      <span class="mobile">
                        <b>Status: </b>{requestorDashboardStatus(
                          assignment.state.status
                        )}
                      </span>
                    {/if}
                    <span class="desktop">Request ID: #{assignment.id}</span>
                  </span>
                </div>
                <div class="mobile start-button">
                  {#if assignment.state.status !== 4}
                    <ClickButton
                      text="Start"
                      color={"secondary"}
                      disabled={chevron_state[i]}
                      on:click={(e) => {
                        if (!chevron_state[i]) {
                          currentAssignment = null;
                          focus_fields = [];
                          focus_index = 0;
                        }
                      }}
                    />
                  {/if}
                </div>
              </div>
              <div class="td requestor">
                <span class="checklist-table-sentby">
                  <span class="checklist-table-sender">
                    {assignment.sender.name}
                  </span>
                  <span class="checklist-table-org">
                    {assignment.sender.organization}
                  </span>
                </span>
              </div>

              <div class="td status">
                <DashboardStatus
                  recipient={true}
                  state={assignment.state}
                  dueDate={assignment.due_date}
                  time={assignment?.received_date?.time}
                />
              </div>
              <div
                class="td actions actions-btn parent-action sm-hide"
                id={`checklist-toggle-${i}`}
                on:click|self={() => handleChevronClick(assignment, i)}
              >
                {#if status_to_buttontext(assignment.state.status) == "View"}
                  <Button
                    color="white"
                    text={status_to_buttontext(assignment.state.status)}
                  />
                {:else}
                  <span class="hide_element"><Button /></span>
                  <Button
                    color="secondary"
                    disabled={chevron_state[i]}
                    text={status_to_buttontext(assignment.state.status)}
                  />
                {/if}
              </div>
            </div>
            {#if chevron_state[i]}
              {#each assignment.document_requests as docreq}
                <DocumentRequestView
                  {docreq}
                  {assignment}
                  checklistActions={getDropdownOptionsForTemplate}
                  {dropdownClick}
                  {clickDocumentButton}
                  on:doc_req_click={() => {
                    if (window.innerWidth < 768) {
                      window.location = `#submission/view/1/${assignment.id}/${docreq.completion_id}`;
                    }
                    currentlyStarted = docreq;
                    if (docreq.is_info) {
                      window.location.hash = `#view/${assignment.id}/${docreq.id}`;
                    } else if (
                      (docreq.state.status == 0 || docreq.state.status == 3) &&
                      docreq.is_iac == false
                    ) {
                      currentAssignment = assignment;
                      showUploadModal = true;
                    } else if (
                      docreq.is_iac &&
                      (docreq.state.status == 0 || docreq.state.status == 3)
                    ) {
                      window.location.hash = `#iac/fill/${
                        docreq.iac_document_id
                      }/${assignment.id}?${getQueryStrings(assignment)}`;
                    }
                  }}
                />
              {/each}
              {#if assignment.file_requests.length != 0}
                {#each assignment.file_requests as filereq}
                  {#if filereq.flags !== 4}
                    <FileRequestView
                      bind:filereq
                      {assignment}
                      {EXTRAFILEUPLOADSDEFAULTNAME}
                      {EXTRAFILEUPLOADSDEFAULTDESCRIPTION}
                      {checklistActions}
                      fileActionButtons={getRowLevelOptions}
                      {dropdownClick}
                      {ff_useFillPopup}
                      {handleCompletedFileRequestDropDown}
                      focused={focus_fields.length && !focusStatus
                        ? focus_fields[focus_index]
                        : null}
                      textFieldfocused={filereq.id == selectedFocusID
                        ? dataRequestFocus
                        : focusHelper(filereq.id)}
                      on:handleEnterKeyDown={() => {
                        if (focus_fields.length) {
                          focusStatus = false;
                          focus_index = focus_index + 1;
                          if (focus_index >= focus_fields.length) {
                            focus_index = 0;
                          }
                        }
                        saveDataRequest(assignment, filereq);
                      }}
                      on:handleFocusIndex={() => {
                        if (focus_fields.length) {
                          focus_index = focus_fields.findIndex(({ id }) => {
                            return id == filereq.id;
                          });
                        }
                      }}
                      on:file_req_click={() => {
                        if (window.innerWidth < 768) {
                          let type = filereq.type,
                            status = filereq.state.status;
                          if (
                            type === "file" &&
                            (status === 2 || status === 4)
                          ) {
                            window.location.href = `#submission/view/2/${assignment.id}/${filereq.completion_id}`;
                          }
                          // window.location = `#submission/view/1/${assignment.id}/${docreq.completion_id}`;
                        }
                        tempSelectedID = filereq.id;
                        currentFR = filereq;
                        currentAssignment = assignment;
                        if (filereq.type == "data") {
                          if (
                            (filereq.state.status != 5 &&
                              filereq.value == "") ||
                            (filereq.state.status == 2 &&
                              currentDRText != filereq.value)
                          ) {
                            showFillModal = true;
                          }
                        }
                      }}
                      on:fileRequestLineClick={() => {
                        fileRequestLineClick(filereq);
                      }}
                      on:show_modal={() => {
                        currentFR = filereq;
                        currentAssignment = assignment;
                        let type = filereq.type;
                        if (type == "file") {
                          if (filereq.state.status == 0) {
                            showUploadFRModal = true;
                          }
                        } else if (type == "data") {
                          if (
                            filereq.value == "" ||
                            (filereq.state.status == 2 &&
                              currentDRText != filereq.value)
                          ) {
                            showFillModal = true;
                          }
                        } else {
                          taskToBeViewed = filereq;
                          showTaskDetails = true;
                        }
                      }}
                      on:saveDataRequest={() => {
                        console.log("saveDataRequest");
                        saveDataRequest(assignment, filereq);
                      }}
                      on:onProgressEvent={(evt) =>
                        handleProgressEvent(evt, assignment, filereq)}
                      on:handleFileClick={() => {
                        focusStatus = false;
                        currentFR = filereq;
                        currentAssignment = assignment;
                        let type = filereq.type,
                          status = filereq.state.status;
                        if (type === "file") {
                          if (status == 2 || status == 4) {
                            window.location.href = `#submission/view/2/${assignment.id}/${filereq.completion_id}`;
                          } else if (filereq.flags === 4 && status == 0) {
                            currentAssignment = assignment;
                            uploadAdditionalFiles = true;
                          } else {
                            currentAssignment = assignment;
                            showUploadFRModal = true;
                          }
                        } else if (type === "task") {
                          if (status == 0 || status == 3) {
                            const {
                              has_confirmation_file_uploaded,
                              is_confirmation_required,
                            } = filereq;
                            uploadConfirmation =
                              !has_confirmation_file_uploaded;
                            isConfirmationRequired = is_confirmation_required;
                            if (isConfirmationRequired) {
                              actions[0].description = "Upload Confirmation.";
                            } else {
                              actions[0].description =
                                "Upload Confirmation. If any";
                            }
                            console.log({
                              isConfirmationRequired,
                              actions,
                            });
                            taskConfirmationFIleSubmitMessage =
                              has_confirmation_file_uploaded
                                ? "This will submit the uploaded confirmation file."
                                : "";
                            showTaskConfirmation = true;
                            taskToBeViewed = filereq;
                          } else {
                            taskToBeViewed = filereq;
                            showTaskDetails = true;
                            return;
                          }
                        } else {
                          if (
                            filereq.value == "" ||
                            (status == 2 && currentDRText != filereq.value)
                          ) {
                            showFillModal = true;
                          } else {
                            console.log("444");
                            saveDataRequest(assignment, filereq);
                          }
                        }
                      }}
                    />
                  {/if}
                {/each}
              {/if}
              {#if assignment.forms.length != 0}
                {#each assignment.forms as form}
                  <div
                    on:click={() => {
                      const assignmentId = assignment.id;
                      const formId = form.id;
                      if (FORM_EDITABLE_STATES.includes(form.state.status)) {
                        const hash = `#form/fill/${formId}/${assignmentId}`;
                        window.location.hash = hash;
                        console.log(hash);
                      } else {
                        // view only
                        const hash = `#form/view/${formId}/${assignmentId}`;
                        console.log(hash);
                        window.location.hash = hash;
                      }
                    }}
                    class="checklist-tr child outer-border"
                    class:greenShade={form.state.status === 2 ||
                      form.state.status === 4 ||
                      form.state.status === 5 ||
                      form.state.status === 6}
                    class:red-shade={form.state.status == 3}
                  >
                    <div class="td chevron" />
                    <div class="td checklist">
                      <div
                        class="filerequest checklist-icon"
                        style="cursor: pointer;"
                      >
                        <span class="document-icon">
                          <div>
                            <FAIcon icon="rectangle-list" iconStyle="regular" />
                          </div>
                        </span>
                        <div class="filerequest-name">
                          <div>{form.title}</div>
                          <div class="truncate">
                            {form.description ? form.description : ""}
                          </div>
                          <DocStatusSm
                            status={form.state.status}
                            date={form.state.date}
                          />
                        </div>
                      </div>
                    </div>
                    <div class="td requestor" />

                    <div class="td status">
                      <DashboardStatus
                        recipient={true}
                        state={form.state}
                        time={form.state.time}
                      />
                    </div>

                    <!-- {#if due_dates_enabled} -->
                    <!-- <div class="td"> -->
                    <!-- </div> -->
                    <!-- {/if} -->
                    <div class="td actions actions-btn sm-hide">
                      {#if FORM_EDITABLE_STATES.includes(form.state.status)}
                        {#if form.state.status == 2}
                          <Button text="View/Edit" color="gray" />
                        {:else}
                          <Button text="Fill" />
                        {/if}
                      {:else}
                        <Button text="View" color="gray" />
                      {/if}
                    </div>
                  </div>
                {/each}
              {/if}
              {#if assignment.file_requests.length != 0}
                {#each assignment.file_requests as filereq}
                  {#if filereq.flags === 4}
                    <FileRequestView
                      bind:filereq
                      {assignment}
                      {EXTRAFILEUPLOADSDEFAULTNAME}
                      {EXTRAFILEUPLOADSDEFAULTDESCRIPTION}
                      {checklistActions}
                      fileActionButtons={getRowLevelOptions}
                      {dropdownClick}
                      {ff_useFillPopup}
                      {handleCompletedFileRequestDropDown}
                      focused={focus_fields.length && !focusStatus
                        ? focus_fields[focus_index]
                        : null}
                      textFieldfocused={filereq.id == selectedFocusID
                        ? dataRequestFocus
                        : focusHelper(filereq.id)}
                      on:handleEnterKeyDown={() => {
                        if (focus_fields.length) {
                          focusStatus = false;
                          focus_index = focus_index + 1;
                          if (focus_index >= focus_fields.length) {
                            focus_index = 0;
                          }
                        }
                        saveDataRequest(assignment, filereq);
                      }}
                      on:handleFocusIndex={() => {
                        if (focus_fields.length) {
                          focus_index = focus_fields.findIndex(({ id }) => {
                            return id == filereq.id;
                          });
                        }
                      }}
                      on:file_req_click={() => {
                        tempSelectedID = filereq.id;
                        currentFR = filereq;
                        currentAssignment = assignment;
                        if (filereq.type == "data") {
                          if (
                            (filereq.state.status != 5 &&
                              filereq.value == "") ||
                            (filereq.state.status == 2 &&
                              currentDRText != filereq.value)
                          ) {
                            showFillModal = true;
                          }
                        }
                      }}
                      on:fileRequestLineClick={() => {
                        fileRequestLineClick(filereq);
                      }}
                      on:show_modal={() => {
                        currentFR = filereq;
                        currentAssignment = assignment;
                        let type = filereq.type;
                        if (type == "file") {
                          if (filereq.state.status == 0) {
                            showUploadFRModal = true;
                          }
                        } else if (type == "data") {
                          if (
                            filereq.value == "" ||
                            (filereq.state.status == 2 &&
                              currentDRText != filereq.value)
                          ) {
                            showFillModal = true;
                          }
                        } else {
                          taskToBeViewed = filereq;
                          showTaskDetails = true;
                        }
                      }}
                      on:saveDataRequest={() => {
                        console.log("saveDataRequest");
                        saveDataRequest(assignment, filereq);
                      }}
                      on:onProgressEvent={(evt) =>
                        handleProgressEvent(evt, assignment, filereq)}
                      on:handleFileClick={() => {
                        focusStatus = false;
                        currentFR = filereq;
                        currentAssignment = assignment;
                        let type = filereq.type,
                          status = filereq.state.status;
                        if (type === "file") {
                          if (status == 2 || status == 4) {
                            window.location.href = `#submission/view/2/${assignment.id}/${filereq.completion_id}`;
                          } else if (filereq.flags === 4 && status == 0) {
                            currentAssignment = assignment;
                            uploadAdditionalFiles = true;
                          } else {
                            currentAssignment = assignment;
                            showUploadFRModal = true;
                          }
                        } else if (type === "task") {
                          if (status == 0 || status == 3) {
                            const {
                              has_confirmation_file_uploaded,
                              is_confirmation_required,
                            } = filereq;
                            uploadConfirmation =
                              !has_confirmation_file_uploaded;
                            isConfirmationRequired = is_confirmation_required;
                            if (isConfirmationRequired) {
                              actions[0].description = "Upload Confirmation.";
                            } else {
                              actions[0].description =
                                "Upload Confirmation. If any";
                            }
                            console.log({
                              isConfirmationRequired,
                              actions,
                            });
                            taskConfirmationFIleSubmitMessage =
                              has_confirmation_file_uploaded
                                ? "This will submit the uploaded confirmation file."
                                : "";
                            showTaskConfirmation = true;
                            taskToBeViewed = filereq;
                          } else {
                            taskToBeViewed = filereq;
                            showTaskDetails = true;
                            return;
                          }
                        } else {
                          if (
                            filereq.value == "" ||
                            (status == 2 && currentDRText != filereq.value)
                          ) {
                            showFillModal = true;
                          } else {
                            console.log("444");
                            saveDataRequest(assignment, filereq);
                          }
                        }
                      }}
                    />
                  {/if}
                {/each}
              {/if}
            {/if}
          </div>
        {/if}
      {/each}
    </div>
  </section>
{:catch error}
  <p>An error occured fetching the current assignments</p>
{/await}

{#if showUploadModal}
  <UploadFileModal
    on:close={() => {
      showUploadModal = false;
    }}
    on:extraClicked={() => {
      window.location = `/document/${currentAssignment.id}/${currentlyStarted.id}/download`;
    }}
    on:done={processDocUpload}
    extraButton="Download"
    uploadHeaderText="Download, fill offline, save, upload below"
  />
{/if}

{#if showUploadFRModal}
  <UploadFileModal
    on:close={() => {
      showUploadFRModal = false;
      currentFR = undefined;
    }}
    on:done={processFRUpload}
    on:SeparateUploads={processSeparateFRUpload}
    uploadHeaderText={currentFR?.name}
    uploadSubHeaderText={currentFR?.description}
    specialText={`Locate, scan, or take a picture of the requested file and upload it below.`}
  />
{/if}

{#if uploadAdditionalFiles}
  <UploadFileModal
    isAdditionalUploads={true}
    on:close={() => {
      uploadAdditionalFiles = false;
      currentFR = undefined;
    }}
    on:done={processAdditionalUploads}
    on:SeparateUploads={processAdditionalUploads}
    specializedFor="additionalFileUploads"
    specialText={`Please attach the additional files and upload them.`}
  />
{/if}

{#if showUploadConfirmationModal}
  <UploadFileModal
    requireIACwarning={false}
    multiple={false}
    on:close={() => {
      showTaskConfirmation = false;
      showUploadConfirmationModal = false;
    }}
    on:done={processConfimationUpload}
    specialText={`Please find confirmation file and upload it.`}
  />
{/if}

{#if showFillModal}
  <ConfirmationDialog
    title={currentFR?.name ? currentFR?.name + ":" : ""}
    responseBoxEnable="true"
    responseBoxDemoText="Enter Data Input Here"
    responseBoxText={currentFR?.value}
    requiresResponse={true}
    yesText="Submit"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    on:message={handleDRMsg}
    on:yes={""}
    on:close={() => {
      currentFR = undefined;
      showFillModal = false;
    }}
  />
{/if}

{#if checklistCompletedDialog}
  <ChecklistCompleteModal
    bind:checklistCompletedDialog
    {currentSubmittedAssignment}
  />
{/if}

{#if showFileUploadSubmitConfirmationBox}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`This will submit the file. Are you Sure?`}
    yesText="Yes"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    on:yes={processSubmitFileRequest}
    on:close={() => {
      showFileUploadSubmitConfirmationBox = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
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

{#if showTaskConfirmation}
  <ConfirmationDialog
    title={taskToBeViewed.name}
    question="Have you completed the task?"
    details={taskConfirmationFIleSubmitMessage != ""
      ? taskConfirmationFIleSubmitMessage
      : null}
    yesText={`${isConfirmationRequired ? "Yes, upload" : "Yes"}`}
    noText="No"
    yesColor="secondary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => {
      showTaskConfirmation = false;
    }}
    on:yes={() => {
      if (isConfirmationRequired) {
        showTaskConfirmation = false;
        showUploadConfirmationModal = true;
        isConfirmationRequired = false;
      } else {
        handleMarkAsDone();
      }
    }}
  />
{/if}

{#if showClientGuideDialog}
  {#if checkClientGuideStatus !== true}
    {#if showOnceClientGuideDialog !== true}
      <ConfirmationDialog
        title={"Welcome to Boilerplate."}
        hideText={"Continue"}
        hideColor={"secondary"}
        hideStyle={"grid-area: a/a/a/c;"}
        checkBoxEnable={"enable"}
        checkBoxText={"Don't ask me this again"}
        guidePointsEnable={"enable"}
        {guidePoints}
        on:yes={""}
        on:close={(event) => {
          if (event?.detail) {
            localStorage.setItem("dontshowClientGuideDialog", event?.detail);
          } else {
            localStorage.setItem("dontshowClientGuideDialog", false);
          }
          showClientGuideDialog = false;
          window.sessionStorage.setItem("showOnceClientGuideDialog", true);
        }}
        on:hide={(event) => {
          if (event?.detail) {
            localStorage.setItem("dontshowClientGuideDialog", event?.detail);
          } else {
            localStorage.setItem("dontshowClientGuideDialog", false);
          }
          showClientGuideDialog = false;
          window.sessionStorage.setItem("showOnceClientGuideDialog", true);
        }}
      />
    {/if}
  {/if}
{/if}

{#if showChecklistEditNameOptionBox}
  <ConfirmationDialog
    title={"Edit Checklist Name"}
    responseBoxEnable="true"
    responseBoxDemoText={toEditChecklistName}
    yesText="Edit"
    noText="Cancel"
    yesColor="primary"
    requiresResponse={true}
    on:message={processChecklistEdit}
    noColor="gray"
    on:yes={""}
    on:close={() => {
      showChecklistEditNameOptionBox = false;
    }}
  />
{/if}

{#if showExpirationTrackEditBox}
  <AddExpirationDate
    expirationInfo={reqEditingExpirationInfo.expiration_info}
    on:submit={async (evt) => {
      const documentExpirationInformation = evt.detail?.data;
      const { id, expiration_info } = reqEditingExpirationInfo;
      await handleEditExpirationInfo(
        id,
        documentExpirationInformation,
        expiration_info
      );
      showExpirationTrackEditBox = false;
      reqEditingExpirationInfo = null;
    }}
    on:close={() => {
      showExpirationTrackEditBox = false;
      reqEditingExpirationInfo = null;
    }}
  />
{/if}

<style>
  a {
    width: 250px;
    display: block;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  }

  .selectedBorder {
    border: 1px solid #76808b;
    border-radius: 5px;
  }
  .hide_element {
    display: none;
  }
  .greenShade {
    background: #d1fae5 !important;
  }

  .red-shade {
    border-color: #db5244 !important;
    border-width: 2px !important;
    border-style: dashed !important;
  }
  .sortable {
    cursor: pointer;
    left: 6px;
    top: 0px;
    position: relative;
    color: #76808b;
  }

  section.main {
    background-color: #fcfdff;
    padding-top: 1rem;
    padding-left: 2rem;
    padding-right: 2rem;
  }
  section.header {
    position: sticky;
    padding-top: 0;
    top: 64px;
    z-index: 10;
    background: #ffffff;
    padding-bottom: 0.5rem;
  }
  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    /* border-top: 0.5px solid #b3c1d0; */
    /* margin-right: 4rem; */
    margin: 0 auto;
    /* padding-top: 0.5rem; */
    position: relative;
  }
  .checklist-tr.checklist-th {
    display: none;
  }
  .checklist-th > .td {
    white-space: normal;
    justify-content: left;
    flex-direction: row;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    align-self: center;
    height: 37px;
  }
  .td {
    font-family: "Nunito", sans-serif;
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0px;
    color: var(--text-secondary);
  }
  .checklist-tr {
    /* width: 100%; */
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    position: relative;
  }
  .checklist-tr:not(.checklist-th) {
    display: grid;
    grid-template-columns: 30px 1fr 1fr;
    grid-template-areas:
      "a b b"
      ". e e";
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #2a2f34;
    padding: 0.5rem;
    padding-bottom: 0;
    position: relative;

    row-gap: 0.3rem;
    align-items: center;
  }
  .checklist-tr.child {
    width: 85%;
    margin: 0.5rem auto;
    padding: 0.5rem;
    display: grid;
    grid-template-columns: 30px 1fr 1fr;
    grid-template-areas:
      "b b b"
      ". e e";
    font-style: normal;
  }
  .td.chevron {
    place-items: center;
    height: 100%;
    margin-left: 5px;
    grid-area: a;
  }
  .td.checklist {
    grid-area: b;
  }
  .td.requestor {
    display: none;
    grid-area: c;
  }
  .td.status {
    display: none;
    grid-area: d;
  }
  .td.actions {
    /* width: max-content; */
    grid-area: e;
    display: flex;
    justify-content: flex-end;
    display: flex;
    align-items: center;
    margin-left: 20px;
  }
  .actions-btn :global(button) {
    margin-bottom: 0;
  }
  .checklist-tr.child .td.actions {
    width: 86%;
    display: grid;
    grid-template-columns: 1fr 20px;
    column-gap: 0.3rem;
    justify-items: center;
    justify-self: center;
    margin-left: 0.5rem;
  }

  .filerequest {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
  }
  .filerequest > span {
    margin-bottom: 0;
    width: 30px;
  }
  .filerequest:nth-child(1) {
    font-size: 24px;
    /* align-items: end; */
    color: #606972;
    /* background: tomato; */
  }
  .filerequest-name {
    font-family: "Nunito", sans-serif;
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
    width: 90%;
  }
  .filerequest-name > *:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 13px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #2a2f34;
  }
  .filerequest-name > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }
  .filerequest-name > *:nth-child(3) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }
  .checklist-table-checklist {
    width: 95%;
    flex-flow: column wrap;
    flex-grow: 8;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .checklist-table-sentby {
    flex-flow: column wrap;
    flex-grow: 8;
    flex-basis: 8;
  }
  .checklist-table-sender {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    display: flex;
    flex-basis: 4;
    /* identical to box height, or 171% */
    /* Black */
    color: var(--text-dark);
  }
  .checklist-table-org {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    display: flex;
    flex-basis: 4;
    /* identical to box height, or 171% */
    /* Grey/100 */
    color: #7e858e;
  }
  .checklist-table-name {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 18px;
    line-height: 24px;
    /* identical to box height, or 133% */
    letter-spacing: 0.15px;
    display: flex;
    /* Black */
    color: var(--text-dark);
  }
  .checklist-table-requestid {
    /* Body 2 */
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.25px;
    display: flex;
    /* Gray 900 */
    color: #4a5158;
  }
  .outer-border {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    padding-top: 0.5rem;
    padding-bottom: 1rem;
    border-radius: 10px;
    margin-bottom: 1rem;
  }

  .client-portal {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .client-portal h3 {
    margin: 0;
    color: #76808b;
    font-family: "Lato", sans-serif;
  }
  .mobile {
    display: none;
  }

  @media only screen and (max-width: 786px) {
    .desktop {
      display: none;
    }
    .mobile {
      display: block;
    }

    .td.actions {
      width: 80%;
    }

    .main {
      padding: 1rem !important;
    }

    .checklist-tr.child {
      grid-template-areas: "b b b" "e e e";
      width: 92%;
    }

    .client-portal {
      justify-content: flex-start;
    }
    .client-portal h3 {
      font-size: 14px;
      font-weight: 700;
    }

    .header span {
      font-size: 12px;
      margin: 0;
      padding: 0;
      line-height: 14px;
    }

    .td.actions.actions-btn.sm-hide,
    .checklist-tr.child .td.actions.sm-hide {
      display: none;
    }
    .checklist-tr:not(.checklist-th) {
      gap: 0;
    }
    section.header {
      position: inherit;
    }
    .mobile.start-button {
      display: flex;
      align-items: center;
    }
    .checklist-table-checklist {
      width: 100%;
    }
  }

  @media only screen and (min-width: 640px) {
    .checklist-tr.child .td.actions {
      width: 57%;
      margin-left: 1rem;
    }
  }
  @media only screen and (min-width: 768px) {
    .filerequest-name {
      width: 80%;
    }
    .td.requestor {
      display: flex;
      width: 95%;
    }
    .td.status {
      display: flex;
    }
    .checklist-tr.checklist-th {
      border-top: 0.5px solid #b3c1d0;
      display: grid;
      grid-template-columns: 30px 1.7fr 1fr 2fr 160px;
      grid-template-areas: "a b c d e";
      background: #ffffff;
      width: 100%;
    }
    .checklist-tr.checklist-th .td.actions > div {
      width: 67%;
    }
    .checklist-tr:not(.checklist-th) {
      display: grid;
      grid-template-columns: 30px 1.7fr 1fr 2fr 160px;
      grid-template-areas: "a b c d e";
      cursor: pointer;
    }
    .checklist-tr.child {
      width: 99%;
      grid-template-columns: 30px 1.7fr 1fr 2fr 160px;
      grid-template-areas: "a b c d e";
    }
    .checklist-tr.child .td.actions {
      min-width: 80%;

      max-width: 100%;
      padding-right: 2.5rem;
      margin-left: 0;
    }
  }
  @media only screen and (max-width: 425px) {
    .td.actions {
      align-items: center;
      margin-left: unset;
    }
  }
</style>
