<script>
  import Switch from "Components/Switch.svelte";
  import DashboardStatus from "../../components/DashboardStatus.svelte";
  import DashboardMobileView from "../../components/DashboardHelpers/DashboardMobileView.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import Dropdown from "../../components/Dropdown.svelte";
  import BackgroundPageHeader from "../../components/BackgroundPageHeader.svelte";
  import Modal from "../../components/Modal.svelte";
  import TextField from "../../components/TextField.svelte";
  import TablePager from "../../components/TablePager.svelte";
  import TableSorter from "../../components/TableSorter.svelte";
  import Radio from "../../components/Radio.svelte";
  import {
    loadDashboardMetadata,
    loadDashboardCSV,
    getRecipient,
    loadDashboardForRecipient,
    SHOW_DELETED_RECIPIENT_KEY,
  } from "BoilerplateAPI/Recipient";
  import {
    archiveAssignment,
    unsendAssignment,
    deleteCompleteItem,
    unsendRecipientAssignments,
    SORT_FIELDS,
  } from "BoilerplateAPI/Assignment";
  import { deleteFormSubmission } from "BoilerplateAPI/Form";
  import {
    remindNowV2,
    checklistRescindRequest,
    checklistRescindTemplate,
    SHOW_DELETED_CHECKLIST_KEY,
  } from "BoilerplateAPI/Checklist";
  import { deleteRecipientCabinetId } from "../../../api/Cabinet";
  import Button from "../../atomic/Button.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import EmailFaultDialog from "../../components/EmailFaultDialog.svelte";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import EmptyDefault from "../../util/EmptyDefault.svelte";
  import Loader from "../../components/Loader.svelte";
  import {
    isImage,
    getFileDownloadUrl,
    getDocumentDownloadUrl,
    getRequestorOpenDocPreviewLink,
    printOptionMenu,
    getChecklistDownloadUrl,
    getRecipientChecklistDownloadUrl,
  } from "../../../helpers/fileHelper";
  import { unsendForm } from "BoilerplateAPI/Form";
  import {
    markFileRequestMissing,
    requestExpirationInfo,
  } from "BoilerplateAPI/RecipientPortal";
  import {
    fileRequestManualUpload,
    returnExpiredItem,
    hasExpirationValueChanged,
  } from "BoilerplateAPI/FileRequest";
  import { templateManualUpload, getTemplate } from "BoilerplateAPI/Template";
  import ChooseChecklistModal from "../../modals/ChooseChecklistModal.svelte";
  import ChooseTemplateModal from "../../modals/ChooseTemplateModal.svelte";
  import { uploadCabinet } from "BoilerplateAPI/Cabinet";
  import { deleteRecipient, hideRecipient } from "BoilerplateAPI/Recipient";
  import { showErrorMessage } from "Helpers/Error";
  import RecipientTaskDescription from "Components/Recipient/RecipientTaskDescription.svelte";
  import {
    isBrowserTypeSafari,
    createQueryParams,
    isMobile,
    saveCSV,
    savePDF,
    getValidUrlLink,
    getLocalStorage,
    setLocalStorage,
  } from "Helpers/util";
  import { postIACSESFill, iacSESGetTargets } from "BoilerplateAPI/IAC";
  import { getDateObject, getDateString } from "Helpers/dateUtils";
  import { onMount, onDestroy } from "svelte";
  import qs from "qs";
  import {
    sessionStorageGet,
    sessionStorageHas,
    sessionStorageSave,
  } from "../../../helpers/sessionStorageHelper";
  import {
    FILTERSTRINGSESSIONKEY,
    SORTKEYSESSIONKEY,
  } from "../../../helpers/constants";
  import AddExpirationDate from "../../components/AddExpirationDate.svelte";
  import {
    getNextStatusForTemplates,
    getNextEventForStatus,
    getNextStatusForReq,
  } from "../../../nextEventData";
  import Tag from "../../atomic/Tag.svelte";
  import { DELETECONFIRMATIONTEXT } from "../../../constants";
  import { convertUTCToLocalDateString } from "../../../helpers/dateUtils";
  import { resetRequestorSignatureFields } from "../../../helpers/Requester/Dashboard";
  import ListView from "../../components/ListView.svelte";

  const show_deleted_recipients = getLocalStorage(SHOW_DELETED_RECIPIENT_KEY);
  let showItemPopUp = false;
  let showUploadModal = false;
  let manualUploadData = {};
  let itemToBeViewed;
  let unsendThis;
  let showUnsendPromt;
  let archiveThis;
  let showArchivePromt;
  let showSelectChecklistModal = false;
  let showCabinentUploadModal = false;
  let search_value = "";
  let showMissingReason = false;
  let delete_data;
  let showConfirmationDeleteItem = false;
  const isSafari = isBrowserTypeSafari();

  const sessionSortKey = sessionStorageGet(SORTKEYSESSIONKEY);
  // pagination stuff starts
  let pageNumber = 1;
  let hasNext = false;
  let assignmentsData = [];
  let loading = true;
  let totalPages = 1;
  let sort = sessionSortKey?.sort || SORT_FIELDS.LAST_ACTIVITY_DATE;
  let sortDirection = sessionSortKey?.sortDirection || "desc";
  let deliveryfaultData;
  let handleDeliveryFault = false;

  const getDashboardForRecipient = async (recipient_id) => {
    const filterStr = getFiltersApplied();
    let reply = await loadDashboardForRecipient(recipient_id, {
      ...filterStr,
      show_deleted_checklists,
    });
    return reply;
  };

  const handleNextPage = () => {
    if (hasNext) loadPaginatedAssignments(pageNumber + 1);
  };

  const handlePrevPage = () => {
    if (pageNumber > 1) loadPaginatedAssignments(pageNumber - 1);
  };

  let totalRequestsCount = 0;

  const loadPaginatedAssignments = async (targetPage = 1) => {
    loading = true;
    const filterStr = getFiltersApplied();
    const scrollY = window.scrollY;
    try {
      const query = createQueryParams({
        page: targetPage,
        search: search_value,
        sort,
        sort_direction: sortDirection,
      });
      sessionStorageSave(SORTKEYSESSIONKEY, { sort, sortDirection });
      const { data, page, has_next, total_pages } = await loadDashboardMetadata(
        {
          ...filterStr,
          show_deleted_checklists,
          show_deleted_recipients,
        },
        query
      );
      assignmentsData = data.filter((x) => x.checklist_count > 0);

      totalRequestsCount = assignmentsData.reduce(
        (previousValue, currentObj) =>
          previousValue +
            (currentObj?.document_count + currentObj?.file_request_count) || 0,
        0
      );
      pageNumber = page;
      hasNext = has_next;
      totalPages = total_pages;
      setTimeout(() => {
        console.log("[dashboard] loaded!");
        console.log(assignmentsData);
        loading = false;
      }, 100);

      // if scrolled Y found then go back to previous position after rendering.
      if (scrollY > 0) {
        setTimeout(() => {
          window.scroll(0, scrollY);
        }, 1000);
      }
    } catch (err) {
      console.error(err);
      assignmentsData = [];
      pageNumber = 1;
      hasNext = false;
      totalPages = 1;
      loading = false;
    }
  };

  let csvLoading = false;
  let showChooseTemplateModal = false;
  let sesTemplates = Promise.resolve([]);
  let sesData = {};

  const handleExportCSV = async () => {
    const filterStr = getFiltersApplied();
    csvLoading = true;
    try {
      const query = createQueryParams({
        search: search_value,
        sort,
        sort_direction: sortDirection,
      });
      const { data, filename } = await loadDashboardCSV(filterStr, query);
      showToast("Download will start now!", 3000, "default", "MM");
      saveCSV(data, filename);
      csvLoading = false;
    } catch (err) {
      console.error(err);
      showToast(
        "Error occurred while exporting CSV. Try again or contact support.",
        1500,
        "error",
        "MM"
      );
      csvLoading = false;
    }
  };

  let timer;
  onMount(async () => {
    firstLoad = false;
    try {
      // to reduce nav bar load time
      const hasFilterParams = window.location.hash.split("?")[1] !== undefined;
      if (!hasFilterParams) {
        const queryString = sessionStorageHas(FILTERSTRINGSESSIONKEY)
          ? sessionStorageGet(FILTERSTRINGSESSIONKEY)
          : "";
        const hash = window.location.hash.split("?")[0];
        window.location.hash = `${hash}${queryString ? `?${queryString}` : ""}`;
      }
      timer = setTimeout(async () => {
        await loadPaginatedAssignments();
      }, 1);
    } catch (err) {
      console.error(err);
    }
  });

  onDestroy(() => {
    clearTimeout(timer);
  });

  const sortAssignmentData = (_targetSort = SORT_FIELDS.LAST_ACTIVITY_DATE) => {
    // direction change
    if (sort === _targetSort)
      sortDirection = sortDirection === "asc" ? "desc" : "asc";
    else {
      // sort change
      sort = _targetSort;
      sortDirection = "asc";
    }

    loadPaginatedAssignments();
  };
  // pagination stuff ends

  let missing_reasons = [
    { t: "Can't Locate", i: "map-marker-question" },
    { t: "Doesn't Exist", i: "file-times" },
    { t: "Decline To Provide", i: "times-octagon" },
    { t: "Expired", i: "exclamation" },
    { t: "No Longer Required", i: "hand-holding" },
    { t: "Not Applicable / Other", i: "comment-alt-times" },
  ];
  let missingReasonOther = missing_reasons.length - 1;

  const getFiltersApplied = () => {
    const search = window.location.hash.split("?")[1];
    const urlData = qs.parse(search);
    return urlData && Object.keys(urlData).length === 0
      ? {}
      : { filterStr: [urlData] };
  };

  const loadFilteredAssignments = async () => {
    return await loadPaginatedAssignments();
  };

  let missingChecklist;
  let missingFile;
  let missingReasonIndex = 0;
  let missingReason = "";
  let showIACSignatureResetConfirmation = false;
  let showDocumentVersionHistory = false;
  let DocumentVersionData = {};
  let iacFilldata = {};
  function handleMissingResponse(_event) {
    showMissingReason = false;
    if (missingReasonIndex != missingReasonOther) {
      missingReason = missing_reasons[missingReasonIndex].t;
    }
    markFileRequestMissing(
      missingChecklist,
      missingFile,
      missingReason,
      true
    ).then(() => {
      loadPaginatedAssignments(pageNumber);
    });
  }

  let showExpirationTrackEditBox = false;
  let reqEditingExpirationInfo;

  const handleEditExpirationInfo = async (
    id,
    newExpiration,
    currentExpirationInfo
  ) => {
    if (!hasExpirationValueChanged(newExpiration, currentExpirationInfo)) {
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
        window.location.reload();
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

  function handleRequestDropdownClick(checklist, file, ret) {
    if (ret == 0) {
      if (file.state.status == 4) {
        delete_data = {
          assignment_id: checklist.id,
          contents_id: checklist.contents_id,
          target_id: file.id,
          target_type: "request",
          isComplete: true,
          completion_id: file.completion_id,
        };
        showConfirmationDeleteItem = true;
      } else if (file.state.status != 0) {
        showToast(
          `You can't unsend an item that's already completed or in-progress.`,
          1500,
          "error",
          "MM"
        );
      } else {
        showConfirmationDeleteItem = true;
        delete_data = {
          assignment_id: checklist.id,
          contents_id: checklist.contents_id,
          target_id: file.id,
          target_type: "request",
        };
      }
    } else if (ret == 2) {
      // Manual Upload
      manualUploadData = {
        type: "request",
        assignId: checklist.id,
        id: file.id,
      };
      showUploadModal = true;
    } else if (ret == 3) {
      // Print
      const { value } = file;
      printOptionMenu(`/n/api/v1/dproxy/${value}`, value);
    } else if (ret == 4) {
      //download
      const downloadUrl = getFileDownloadUrl({
        specialId: 2,
        parentId: checklist.id,
        documentId: file.completion_id,
      });
      window.location = downloadUrl;
    } else if (ret === 8) {
      showExpirationTrackEditBox = true;
      reqEditingExpirationInfo = file;
    } else {
      showMissingReason = true;
      missingChecklist = checklist;
      missingFile = file;
      missingReason = "";
    }
  }

  async function handleAssignmentDropdownClick(
    assignment,
    ret,
    request = "Oops"
  ) {
    console.log(request);
    if (ret == 1) {
      /* Archive */
      archiveThis = assignment;
      showArchivePromt = true;
    } else if (ret == 2 && request == "Oops") {
      /* Unsend / Delete */
      unsendThis = assignment;
      showUnsendPromt = true;
    } else if (ret == 2) {
      delete_data = {
        assignment_id: assignment.id,
        contents_id: assignment.contents_id,
        target_id: request.id,
        target_type: "document",
        isComplete: request.state.status == 4, // checks if the request is completed
        completion_id: request.completion_id,
      };
      showConfirmationDeleteItem = true;
    } else if (ret == 3) {
      //print
      const downloadUrl = getDocumentDownloadUrl(assignment, request);
      printJS(downloadUrl);
    } else if (ret == 4) {
      //download
      const downloadUrl = getDocumentDownloadUrl(assignment, request);
      window.location = downloadUrl;
    } else if (ret == 5) {
      // Manual Upload
      manualUploadData = {
        type: "document",
        assignId: assignment.id,
        id: request.id,
      };
      showUploadModal = true;
    } else if (ret == 7 || ret == 8) {
      if (request != "Oops" && request.state.status == 0) {
        const doc_id = request.is_rspec
          ? request.customization.customization_id
          : request.id;
        const specialId = request.is_rspec ? 6 : 5;
        console.log({ doc_id });
        const hash = `#submission/view/${specialId}/${assignment.id}/${doc_id}`;
        window.location.hash = hash;
        return;
      }
      let valid_targets_resp = await iacSESGetTargets(assignment.package_id);
      let valid_targets = await valid_targets_resp.json();
      let templates = valid_targets.map((x) => getTemplate(x));
      sesTemplates = Promise.resolve(await Promise.all(templates));
      console.log(assignment);
      let inner_data = [];
      if (assignment.forms.length > 0) {
        // if there are forms, add the data from there too
        for (let formIdx in assignment.forms) {
          let form = assignment.forms[formIdx];
          if (form.has_repeat_entries) {
            let repeat_form_data = [];
            for (let entryIdx in form.entries) {
              let entry = form.entries[entryIdx];
              // loop through the objecy keys, matching them to the formFields
              // push the entry to the repeat_data and eventually to the repeat_strct
              let entry_data = [];
              for (const entryKey in entry) {
                // find the name of this entry
                let entryField = form.formFields.find((e) => e.id == entryKey);
                if (entryField == undefined) {
                  console.error(
                    `[repeat_struct/${form.id}/${entryKey}] invalid entry key, no field found.`
                  );
                  continue;
                }
                entry_data.push({
                  name: entryField.title,
                  value: entry[entryKey],
                });
              }
              repeat_form_data.push(entry_data);
            }
            let repeat_struct = {
              type: "repeat",
              formId: form.id,
              data: repeat_form_data,
            };
            // we're done, push the form's repeat_struct
            inner_data.push(repeat_struct);
          } else {
            for (let fieldIdx in form.formFields) {
              let field = form.formFields[fieldIdx];
              let target_field = 0;
              let value = field.value;
              let split_label = field.label.split("/");
              let index;
              switch (field.type) {
                case "number":
                  value = `${field.value}`;
                case "shortAnswer":
                  target_field = parseInt(field.label);
                  if (
                    !(Array.isArray(value) && value.length == 0) &&
                    !isNaN(target_field)
                  ) {
                    inner_data.push({
                      type: "text",
                      target_field: target_field,
                      target_label: null,
                      value: value,
                    });
                  } else if (isNaN(target_field)) {
                    // this might be an IAC label
                    inner_data.push({
                      type: "text",
                      target_field: 0,
                      target_label: field.label,
                      value: value,
                    });
                  }
                  break;
                case "radio":
                  // find the value in the options array
                  index = field.options.findIndex((x) => x == field.value);
                  // now find the target field in the label;
                  target_field = parseInt(split_label[index]);
                  if (!isNaN(target_field)) {
                    console.log(
                      `radio: fieldId: ${field.id}, index = ${index}, label = ${field.label}, target_field = ${target_field}`
                    );
                    inner_data.push({
                      type: "checkbox",
                      target_field: target_field,
                      target_label: null,
                      checked: true,
                    });
                  } else {
                    // this might be an IAC label
                    inner_data.push({
                      type: "checkbox",
                      target_field: 0,
                      field_value: field.value,
                      target_label: field.label,
                      checked: true,
                    });
                  }
                  break;
                case "checkbox":
                  // in this case the value is NULL, so use the values array in the formfield
                  let values = field.values;
                  // find the targets
                  for (let valIdx = 0; valIdx < values.length; valIdx++) {
                    index = field.options.findIndex((x) => x == values[valIdx]);
                    target_field = parseInt(split_label[index]);
                    if (!isNaN(target_field)) {
                      console.log(
                        `checkbox: valIdx = ${valIdx}, fieldId: ${field.id}, index = ${index}, label = ${field.label}, target_field = ${target_field}`
                      );
                      inner_data.push({
                        type: "checkbox",
                        target_field: target_field,
                        target_label: null,
                        checked: true,
                      });
                    } else {
                      // this might be an IAC label
                      inner_data.push({
                        type: "checkbox",
                        target_field: 0,
                        target_label: field.label,
                        field_value: field.values[valIdx],
                        checked: true,
                      });
                    }
                  }
                  break;
              } // switch
            } // for fields
          } // repeat entries
        }
      }
      sesData = {
        checklist: assignment.package_id,
        recipient: assignment.recipient_id,
        contents: assignment.contents_id,
        raw_document_id: 0,
        type: "autoprefill",
        mapsource: ret == 8 ? "exportable" : "db",
        data: inner_data,
      };
      console.log(sesData);
      showChooseTemplateModal = true;
      return;
    } else if (ret == 6 && request == "Oops") {
      // Grab the list of templates that can be used by this checklist
      let valid_targets_resp = await iacSESGetTargets(assignment.package_id);
      console.log(valid_targets_resp);
      let inner_data = assignment.file_requests.map((x) => {
        return { key: x.name, val: x.value };
      });
      //console.log("assignment =>");
      //console.log(assignment);
      if (assignment.forms.length > 0) {
        //console.log("assignment.forms =>");
        //console.log(assignment.forms);
        // if there are forms, add the data from there too
        for (let formIdx in assignment.forms) {
          let form = assignment.forms[formIdx];
          //console.log("form =>");
          //console.log(form);
          for (let fieldIdx in form.formFields) {
            let field = form.formFields[fieldIdx];
            let key = field.title;
            let value = field.value;

            inner_data.push({ key: key, val: value });
          }
        }
      }
      console.log("inner_data  =>");
      console.log(inner_data);
      if (valid_targets_resp.ok) {
        let valid_targets = await valid_targets_resp.json();

        let templates = valid_targets.map((x) => getTemplate(x));

        console.log(await Promise.all(templates));
        sesTemplates = Promise.resolve(await Promise.all(templates));
        console.log(sesTemplates);
        sesData = {
          checklist: assignment.package_id,
          recipient: assignment.recipient_id,
          raw_document_id: 0,
          type: "select",
          data: inner_data,
        };
        showChooseTemplateModal = true;
        return;
      } else {
        console.log("!!! 8289/SES/8508 failed to get valid targets");
        console.log(valid_targets_resp);
        return;
      }
      // 8289 hack: generate associated PDF
      console.log("!!! Begin IAC/SES data");
      console.log(assignment);

      let data = {
        checklist: assignment.package_id,
        recipient: assignment.recipient_id,
        type: "nonselect",
        data_source: "inner",
        data: inner_data,
      };

      console.log(data);
      let res = await postIACSESFill(data);
      let res2 = await res.json();
      console.log(res2);
      console.log("!!! End IAC/SES data");
      if (res2.type == "fillnow") {
        let recpname = await getRecipient(assignment.recipient_id);
        let final_name = recpname.name.replaceAll(" ", "_");
        let final_doc_name = res2.doc_name.replaceAll(" ", "_");
        const currentDate = new Date();
        const dateObj = getDateObject(currentDate);
        savePDF(
          `/n/api/v1/dproxy/${res2.fn}`,
          `${final_name}_${final_doc_name}_${getDateString(dateObj)}`
        );
      } else {
        let iacDocId = res2.iac_doc_id;
        let contentsId = res2.contents_id;
        let recipientId = assignment.recipient_id;
        window.location.hash = `#iac/fill/${iacDocId}/${contentsId}/${recipientId}?sesMode=true`;
      }
    } else if (ret == 8) {
      const hash = getRequestorOpenDocPreviewLink(assignment, request);
      window.open(hash, "_blank");
    } else if (ret == 9) {
      showErrorMessage("iac_ses", "review_first");
    } else if (ret === 10) {
      iacFilldata = {
        iacDocId: request.iac_document_id,
        contentsId: assignment.contents_id,
        recipientId: assignment.recipient_id,
      };
      showIACSignatureResetConfirmation = true;
    } else if (ret === 15) {
      showDocumentVersionHistory = true;
      DocumentVersionData = {
        history: request.document_history,
        metadata: { ...request, assignmentId: assignment.id },
      };

      // Document history Modal View
    } else if (ret === 11) {
      window.location = getChecklistDownloadUrl(4, assignment.id);
    } else {
      alert("Option not available");
    }
  }

  const handleFormDropDown = async (ret, form, assignment, data) => {
    switch (ret) {
      // review
      case 1:
        window.location.hash = `#review/${assignment.contents_id}/form/${form.id}`;
        break;
      // remind
      case 2:
        tryRemindNow(
          assignment.id,
          assignment.recipient.id,
          assignment.last_reminder_info
        );
        break;
      // unsend
      case 3:
        // Form unsend
        if (form.state.status == 0 || form.state.status == 4) {
          delete_data = {
            assign_id: assignment.id,
            target_id: form.state.status == 0 ? form.id : form.submission_id,
            target_type: "form",
            action: form.state.status == 0 ? "unsend" : "delete",
          };
          showConfirmationDeleteItem = true;
        } else {
          showToast(
            `You can't unsend an item that's already completed or in-progress.`,
            1500,
            "error",
            "MM"
          );
        }
        break;
      case 10:
        let showText = `${form.title}`;
        window.location.hash = `#recipient/${data.recipient.id}/details/data?filter=fs&fs=${form.submission_id}&showText=${showText}`;
        break;
      default:
        alert("Dropdown Fault");
        break;
    }
  };

  let recipient_chevron = {};
  let checklist_chevron = {};
  let cabinet_chevron = {};
  let showConfirmationDialog = false;
  let ifConfirmed = undefined;
  let remindMsg = "";
  let pid = null;
  let rid = null;
  let fillViewModal = false;
  let fillText = "";
  let fillName = "";
  let CabinetRecipientId = 0;
  let showContactDeleteConfirmationBox = false;
  let showContactDeleteOptions = false;
  let showFilter = false;
  let reminderInfo = {};

  function tryRemindNow(checklistId, recipientId, lastReminder) {
    showConfirmationDialog = true;
    pid = checklistId;
    rid = recipientId;
    reminderInfo = lastReminder;
  }

  const EXPIREDDOCUMENTRETURNTEXT = "Expired";
  async function returnExpiredDoc(
    requestId,
    type,
    comment = EXPIREDDOCUMENTRETURNTEXT
  ) {
    loading = true;
    const reply = await returnExpiredItem(requestId, type, comment);
    if (reply.ok) {
      showToast(`File send back to recipient`, 3000, "default", "MM");
      await loadPaginatedAssignments();
    } else {
      showToast(
        `Error! Somthing went wrong. Please try again later`,
        3000,
        "default",
        "MM"
      );
    }
    loading = false;
  }

  let assigning_for_id = null;

  function tryAssignFor(id) {
    window.scrollTo(0, 0); // Quick way of scrolling to the top
    assigning_for_id = id;
    showSelectChecklistModal = true;
  }

  function assignPackage(evt) {
    let detail = evt.detail;
    let packageId = detail.checklistId;

    window.location.hash = `#recipient/${assigning_for_id}/assign/${packageId}`;
  }

  async function handleRemindMessage(event) {
    remindMsg = event?.detail?.text;
    if (pid != null && rid != null && pid != "ALL") {
      await remindNowV2(pid, rid, remindMsg);
      showConfirmationDialog = false;
      showToast(`Reminder email has been sent`, 3000, "default", "MM");
    } else if (pid == "ALL") {
      await remindNowV2("ALL", rid, remindMsg);
      showConfirmationDialog = false;
      showToast(`Reminder email has been sent`, 3000, "default", "MM");
    } else {
      showConfirmationDialog = false;
      alert(pid);
      alert(rid);
      alert("Critical Error with Remind");
      console.log(
        "Remind now email could not send pid = " + pid + "rid = " + rid
      );
      throw new Error("reminder send error");
    }
  }

  function decideView(Item) {
    //Document Not
    //Document Compleated
    window.location.href = `#submission/view/1/${assignment.id}/${request.completion_id}`; //Template Compleated
    //File Request Not
    //File Request Compleated
    window.location.href = `#submission/view/2/${assignment.id}/${filereq.completion_id}`; //File Request Compleated
    //Data Request Not
    //Data Request Compleated
  }

  async function tryDeleteRecipient(event) {
    const { text: deleteTextMessage } = event.detail;
    if (DELETECONFIRMATIONTEXT != deleteTextMessage.toLowerCase()) {
      showToast(`Please type ${DELETECONFIRMATIONTEXT}!`, 1000, "error", "MM");
      return;
    }

    showContactDeleteConfirmationBox = false;
    let reply = await deleteRecipient(deleteRecipientId, "dashBoardDelete");
    if (reply.ok) {
      loadPaginatedAssignments(pageNumber);
      showToast(`Success! Contact deleted.`, 1500, "default", "MM");
    } else {
      let error = await reply.json();
      showErrorMessage("recipient", error.error);
    }
  }

  async function tryhideRecipient(recipient_id) {
    showContactHideConfirmationBox = false;
    let reply = await hideRecipient(recipient_id);
    if (reply.ok) {
      loadPaginatedAssignments(pageNumber);
    } else {
      let error = await reply.json();
      showErrorMessage("recipient", error.error);
    }
  }

  let deleteRecipientId = -1;
  let hideRecipientId = -1;
  let showContactHideConfirmationBox = false;
  function handleContactLevelDropDown(ret, data) {
    switch (ret) {
      case 1:
        window.location.hash = `#recipient/${data.recipient.id}`;
        break;
      case 2:
        recipient_chevron[data.recipient.id] =
          !recipient_chevron[data.recipient.id];
        break;
      case 3:
        tryRemindNow("ALL", data.recipient.id);
        break;
      case 4:
        tryAssignFor(data.recipient.id);
        break;
      case 5:
        (showCabinentUploadModal = true),
          (CabinetRecipientId = data.recipient.id);
        break;
      case 6:
        deleteRecipientId = data.recipient.id;
        // change here
        showContactDeleteOptions = true;
        break;
      case 7:
        hideRecipientId = data.recipient.id;
        showContactHideConfirmationBox = true;
        break;
      case 8:
        window.location.hash = `#recipient/${data.recipient.id}/details/user`;
        break;
      case 9:
        window.location.hash = `#reviews`;
        break;
      case 10:
        window.location.hash = `#recipient/${data.recipient.id}/details/data`;
        break;
      case 11:
        window.location = getRecipientChecklistDownloadUrl(
          4,
          data.recipient.id
        );
        break;
      default:
        showToast(`Unknown option`, 1500, "error", "MM");
    }
  }
  function hideContactOnDashboard(id) {
    hideRecipientId = id;
    showContactDeleteConfirmationBox = false;
    showContactHideConfirmationBox = true;
  }

  let scrollY;

  const handleServerSearch = () => {
    console.log("searching now");
    loadPaginatedAssignments();
  };

  const isChecklistInFullReview = ({ document_requests, file_requests }) => {
    const doc_status = document_requests.map((x) => x.state.status);
    const req_status = file_requests.map((x) => x.state.status);

    const status = doc_status.concat(req_status);
    return status.every((x) => x === 2);
  };

  //#region Clicking Internal Filing Cabinet Dropdown Options

  //vars
  let showCabinetFileDeleteConfirmationDialogBox = false;
  let cabibetFileToDelete;
  //vars

  /**
   * @description Handle click on any option from the dropdown
   * @param {Object} document
   * @param {number} ret
   */
  const handleCabinetClick = async (document, ret) => {
    switch (ret) {
      case 1:
        cabibetFileToDelete = document;
        showCabinetFileDeleteConfirmationDialogBox = true;
        break;
      default:
        showToast("No such options", 1500, "error", "MM");
    }
  };
  /**
   * @description Handle click on any option from the dropdown
   * @param {Object} document
   */
  const deleteCabinetFile = async ({ id, name, recipientId }) => {
    const reply = await deleteRecipientCabinetId(recipientId, id);
    if (reply.ok) {
      showToast(
        `Cabinet document "${name}" has been deleted.`,
        1500,
        "default",
        "MM"
      );
      await loadPaginatedAssignments();
    } else {
      showToast(
        "Something went wrong while uploading this file",
        1500,
        "error",
        "MM"
      );
    }
  };

  let show_deleted_checklists = getLocalStorage(SHOW_DELETED_CHECKLIST_KEY);
  let showDeletedVal = getLocalStorage(SHOW_DELETED_CHECKLIST_KEY);
  let firstLoad = true;

  const handleShowDelete = (show) => {
    if (firstLoad) return;
    setLocalStorage(SHOW_DELETED_CHECKLIST_KEY, show);
    show_deleted_checklists = show;
    loadPaginatedAssignments();
  };

  $: handleShowDelete(showDeletedVal);

  const getLatestCabinetDate = (cabinetData) => {
    const allCabinetStatus = cabinetData.map((cabinet) => cabinet["status"]);
    const maxTimeStamp = Math.max(
      ...allCabinetStatus.map((element) => {
        return new Date(element.date);
      })
    );

    return convertUTCToLocalDateString(new Date(maxTimeStamp));
  };

  async function handleDeliveryFaultPopup(recipient) {
    deliveryfaultData = recipient;
    handleDeliveryFault = true;
  }

  //#endregion
</script>

<svelte:window bind:scrollY />

<BackgroundPageHeader {scrollY} />

<div class="page-header">
  <RequestorHeaderNew
    icon="tasks"
    title="Dashboard"
    bind:search_value
    searchPlaceholder="Search Dashboard"
    enable_search_bar={!loading}
    headerBtn="true"
    btnText="Filter"
    btnIcon="filter"
    bind:showFilter
    contactCount={totalRequestsCount}
    btnAction={() => {
      showFilter = !showFilter;
    }}
    btnDisabled={loading}
    showExportCSVBtn={true}
    ExportCSVBtnText="Export to CSV"
    ExportCSVBtnIcon="file-export"
    ExportCSVBtnAction={handleExportCSV}
    ExportCSVBtnDisabled={csvLoading}
    loadAssignment={true}
    {loadFilteredAssignments}
    {handleServerSearch}
  >
    <span slot="show-delete" style="margin-left:14px">
      <Switch
        bind:checked={showDeletedVal}
        text="Show Deleted"
        marginBottom={false}
      />
    </span>
  </RequestorHeaderNew>
</div>

<section class="container">
  <div class="table">
    {#if loading}
      <span class="loader-container">
        <Loader loading />
      </span>
    {:else if assignmentsData.length}
      <div class="tr th">
        <div class="td chevron" />
        <div class="td name name-head">
          <div
            class="sortable {sort == SORT_FIELDS.RECIPIENT_NAME
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click|stopPropagation={() => {
              sortAssignmentData(SORT_FIELDS.RECIPIENT_NAME);
            }}
          >
            &nbsp; Name &nbsp;
            <TableSorter
              column={SORT_FIELDS.RECIPIENT_NAME}
              {sort}
              {sortDirection}
            />
            &nbsp;
          </div>
          &nbsp;
          <div
            class="sortable {sort == SORT_FIELDS.RECIPIENT_ORG
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click|stopPropagation={() => {
              sortAssignmentData(SORT_FIELDS.RECIPIENT_ORG);
            }}
          >
            &nbsp; Org &nbsp;
            <TableSorter
              column={SORT_FIELDS.RECIPIENT_ORG}
              {sort}
              {sortDirection}
            />
            &nbsp;
          </div>
          &nbsp;
        </div>
        <div class="td status status-head" style="display: flex;">
          <div
            class="sortable {sort == SORT_FIELDS.STATUS
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click|stopPropagation={() => {
              sortAssignmentData(SORT_FIELDS.STATUS);
            }}
          >
            &nbsp; Status &nbsp;
            <TableSorter column={SORT_FIELDS.STATUS} {sort} {sortDirection} />
            &nbsp;
          </div>
          &nbsp;
          <div
            class="sortable {sort == SORT_FIELDS.LAST_ACTIVITY_DATE
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click|stopPropagation={() => {
              sortAssignmentData(SORT_FIELDS.LAST_ACTIVITY_DATE);
            }}
          >
            &nbsp; Date &nbsp;
            <TableSorter
              column={SORT_FIELDS.LAST_ACTIVITY_DATE}
              {sort}
              {sortDirection}
            />
            &nbsp;
          </div>
        </div>
        <div class="hidden md:flex td status status-head ">
          <div
            class="sortable {sort == SORT_FIELDS.NEXT_STATUS
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click|stopPropagation={() => {
              sortAssignmentData(SORT_FIELDS.NEXT_STATUS);
            }}
          >
            &nbsp; Next &nbsp;
            <TableSorter
              column={SORT_FIELDS.NEXT_STATUS}
              {sort}
              {sortDirection}
            />
            &nbsp;
          </div>
          &nbsp;
        </div>
        <div class="td actions actions-head">Actions</div>
      </div>
      {#each assignmentsData as data}
        <!--Recipient Level-->
        <div
          class="recipient desktop"
          class:green-shade={data.recipient_state.status == 4}
          class:red-shade={data.recipient_state.status == 2}
          class:deleted-row={data.recipient_state.status == 11}
        >
          <div
            class="recipient-info clickable"
            class:active={recipient_chevron[data.recipient.id]}
            on:click|stopPropagation={() =>
              (recipient_chevron[data.recipient.id] =
                !recipient_chevron[data.recipient.id])}
          >
            <div
              class="td chevron"
              on:click|stopPropagation={() => {
                recipient_chevron[data.recipient.id] =
                  !recipient_chevron[data.recipient.id];
              }}
            >
              {#if recipient_chevron[data.recipient.id]}
                <span><FAIcon color={true} icon="minus" /></span>
              {:else}
                <span><FAIcon color={true} icon="plus" /></span>
              {/if}
            </div>
            <div class="td name">
              <div class="name-description clickable">
                <div class="name-name truncate">
                  {data.recipient.name} ({data.recipient.company})
                </div>
                <div class="name-desc truncate">
                  {data.recipient.email}
                </div>
                {#if data.tags}
                  <ul class="reset-style">
                    {#each data.tags as tag}
                      <Tag
                        isSmall={true}
                        tag={{ ...tag, selected: true }}
                        listTags={true}
                      />
                    {/each}
                  </ul>
                {/if}
              </div>
            </div>
            <div class="td  status">
              <DashboardStatus
                delivery_fault={data.recipient_state.delivery_fault}
                state={data.recipient_state}
                is_partial={data.recipient_state.status == 2 &&
                  !data.is_partial}
                latest_activity_date={data.latest_activity_date.split(" ")[0]}
              />
            </div>
            <div
              class="td  left_margin"
              style="font-size: 14px; line-height: 21px;"
            >
              {getNextEventForStatus(data)}
            </div>
            <div class="td actions actions-btn">
              {#if data.recipient_state.status != 2 && data.recipient_state.status != 4 && !data.recipient_state.delivery_fault}
                <span
                  on:click|stopPropagation={() => {
                    tryRemindNow("ALL", data.recipient.id);
                  }}
                >
                  <Button text="Remind" color="white" />
                </span>
              {/if}
              {#if data.recipient_state.delivery_fault}
                <span
                  on:click|stopPropagation={() => {
                    handleDeliveryFaultPopup(data.recipient);
                  }}
                >
                  <div class="learn-more-btn">
                    <Button text="Resolve" color="danger" />
                  </div>
                </span>
              {/if}
              {#if !data.recipient_state.delivery_fault && data.recipient_state.status == 2}
                <span
                  on:click|stopPropagation={() =>
                    (window.location.hash = `#reviews`)}
                >
                  <Button text="Review" />
                </span>
              {/if}
              {#if !data.recipient_state.delivery_fault && data.recipient_state.status == 4}
                <div class="view-btn">
                  <Button text="View" />
                </div>
              {/if}
              <div class="pad bg-tomato" />
              <!-- Contact Level Dropdown -->
              <Dropdown
                triggerType="vellipsis"
                clickHandler={(ret) => handleContactLevelDropDown(ret, data)}
                elements={[
                  {
                    ret: 1,
                    icon: "eye",
                    text: "View Documents",
                  },
                  {
                    ret: 2,
                    icon: "chevron-down",
                    text: "View / Expand",
                  },
                  {
                    ret: 9,
                    icon: "glasses",
                    text: "Review",
                    disabled: data.recipient_state.status !== 2,
                  },
                  {
                    ret: 11,
                    icon: "download",
                    text: "Download All",
                    disabled: !(
                      data.recipient_state.status === 2 ||
                      data.recipient_state.status === 4
                    ),
                  },
                  {
                    ret: 3,
                    icon: "bell",
                    text: "Remind",
                    blocked: !(
                      data.recipient_state.status != 2 &&
                      data.recipient_state.status != 4
                    ),
                  },
                  {
                    ret: 4,
                    icon: "paper-plane",
                    text: "Send New Request",
                  },
                  {
                    ret: 8,
                    icon: "info-circle",
                    text: "Contact Details",
                  },
                  {
                    ret: 5,
                    icon: "cabinet-filing",
                    text: "Add to Filing Cabinet",
                  },
                  {
                    ret: 7,
                    icon: "eye-slash",
                    text: "Hide contact",
                    iconStyle: "solid",
                  },
                  {
                    text: "View/ export data",
                    icon: "file-import",
                    iconStyle: "solid",
                    ret: 10,
                  },
                  {
                    text: "Delete",
                    icon: "trash",
                    iconStyle: "solid",
                    ret: 6,
                  },
                ]}
              />
            </div>
          </div>
          {#if !loading && recipient_chevron[data.recipient.id]}
            {#await getDashboardForRecipient(data.recipient.id)}
              <!-- TODO only display when the loading takes longer than 300ms -->
              <Loader loading={true} />
            {:then checklist_level}
              {#each checklist_level.checklists as checklist}
                <div class="checklist">
                  <div class="td chevron" />
                  <div
                    class="checklist-inner clickable"
                    class:green-shade={checklist.state.status == 4}
                    class:red-shade={checklist.state.status == 2}
                    class:deleted-row={checklist.state.status == 9 ||
                      checklist.state.status == 10}
                    on:click|stopPropagation={() => {
                      checklist_chevron[checklist.id] =
                        !checklist_chevron[checklist.id];
                    }}
                  >
                    <div class="checklist-info">
                      <div class="td name">
                        <span class="checklist-force-pad" />
                        <div
                          class="name-chevron"
                          on:click|stopPropagation={() => {
                            checklist_chevron[checklist.id] =
                              !checklist_chevron[checklist.id];
                          }}
                        >
                          {#if checklist_chevron[checklist.id]}
                            <span><FAIcon color={true} icon="minus" /></span>
                          {:else}
                            <span><FAIcon color={true} icon="plus" /></span>
                          {/if}
                        </div>
                        <div
                          class="name-description clickable"
                          on:click|stopPropagation={() =>
                            (checklist_chevron[checklist.id] =
                              !checklist_chevron[checklist.id])}
                        >
                          <div class="name-name truncate">
                            {checklist.name}
                            {#if checklist.recipient_reference}
                              <div style="margin-left: 5px;" class="name-desc">
                                [{checklist.recipient_reference}]
                              </div>
                            {/if}
                            {#if checklist.requestor_reference}
                              <div style="margin-left: 5px;" class="name-desc">
                                [{checklist.requestor_reference}]
                              </div>
                            {/if}
                          </div>
                          <div class="name-desc truncate">
                            {checklist.subject}
                          </div>
                          {#if checklist.tags}
                            <div class="name-desc truncate">
                              <ul class="reset-style">
                                {#each checklist.tags as tag}
                                  <Tag
                                    tag={{ ...tag, selected: true }}
                                    listTags={true}
                                  />
                                {/each}
                              </ul>
                            </div>
                          {/if}
                        </div>
                      </div>
                      <div class="td  status">
                        <DashboardStatus
                          delivery_fault={checklist.state.delivery_fault}
                          state={checklist.state}
                          time={checklist?.received_date?.time}
                          dueDate={checklist.due_date}
                          is_partial={!isChecklistInFullReview(checklist)}
                        />
                      </div>
                      <div class="td  left_margin">
                        <div class="text-xs text-primary">
                          {getNextEventForStatus(checklist)}
                        </div>
                      </div>
                      <div class="td actions actions-btn">
                        {#if checklist.state.delivery_fault}
                          <span
                            on:click|stopPropagation={() =>
                              handleDeliveryFaultPopup(data.recipient)}
                          >
                            <div class="learn-more-btn">
                              <Button text="Resolve" color="danger" />
                            </div>
                          </span>
                        {:else if checklist.state.status == 0 || checklist.state.status == 7}
                          <span
                            on:click|stopPropagation={() => {
                              tryRemindNow(
                                checklist.id,
                                data.recipient.id,
                                checklist.last_reminder_info
                              );
                            }}
                          >
                            <Button text="Remind" color="white" />
                          </span>
                        {:else if checklist.state.status == 1}
                          <span
                            on:click|stopPropagation={() => {
                              tryRemindNow(
                                checklist.id,
                                data.recipient.id,
                                checklist.last_reminder_info
                              );
                            }}
                          >
                            <Button text="Remind" color="white" />
                          </span>
                        {:else if checklist.state.status == 2}
                          <span
                            on:click|stopPropagation={() =>
                              (window.location.hash = `#review/${checklist.contents_id}`)}
                          >
                            <Button text="Review" />
                          </span>
                        {:else if checklist.state.status == 3}
                          <span
                            on:click|stopPropagation={() => {
                              tryRemindNow(
                                checklist.id,
                                data.recipient.id,
                                checklist.last_reminder_info
                              );
                            }}
                          >
                            <Button text="Remind" color="white" />
                          </span>
                        {:else if checklist.state.status == 4 || checklist.state.status == 9 || checklist.state.status == 10}
                          <span
                            class="view-btn"
                            on:click|stopPropagation={() => {
                              checklist_chevron[checklist.id] =
                                !checklist_chevron[checklist.id];
                            }}
                          >
                            <Button text="View" color="gray" />
                          </span>
                        {:else}
                          <Button text="_BUG_" />
                        {/if}
                        <!-- Checklist Level Dropdown -->
                        <Dropdown
                          triggerType="vellipsis"
                          clickHandler={(ret) => {
                            ret == 1 || ret == 2
                              ? handleAssignmentDropdownClick(checklist, ret)
                              : ret == 6
                              ? handleAssignmentDropdownClick(checklist, ret)
                              : ret == 7
                              ? handleAssignmentDropdownClick(checklist, ret)
                              : ret == 9
                              ? handleAssignmentDropdownClick(checklist, ret)
                              : ret == 8
                              ? handleAssignmentDropdownClick(checklist, ret)
                              : ret == 3
                              ? (checklist_chevron[checklist.id] =
                                  !checklist_chevron[checklist.id])
                              : ret == 4
                              ? tryRemindNow(
                                  checklist.id,
                                  data.recipient.id,
                                  checklist.last_reminder_info
                                )
                              : ret == 5
                              ? (window.location.hash = `#review/${checklist.contents_id}`)
                              : ret == 10
                              ? (window.location.hash = `#recipient/${data.recipient.id}/details/data?filter=cs&cs=${checklist.contents_id}&showText=${checklist.name} @ ${checklist.received_date.date}`)
                              : handleAssignmentDropdownClick(checklist, ret);
                          }}
                          elements={[
                            {
                              ret: 3,
                              icon: "chevron-down",
                              text: "View / Expand",
                            },
                            {
                              ret: 5,
                              icon: "glasses",
                              text: "Review",
                              disabled: checklist.state.status !== 2,
                            },
                            {
                              ret: 11,
                              icon: "download",
                              text: "Download",
                              disabled: !(
                                checklist.state.status === 2 ||
                                checklist.state.status === 4
                              ),
                            },
                            {
                              ret: 4,
                              icon: "bell",
                              text: "Remind",
                              blocked:
                                checklist.state.status === 2 ||
                                checklist.state.status === 9 ||
                                checklist.state.status === 10 ||
                                checklist.state.status === 4,
                            },
                            {
                              ret: 1,
                              icon: "archive",
                              text: "Archive",
                              disabled:
                                checklist.state.status === 9 ||
                                checklist.state.status === 10,
                            },
                            {
                              text: "View/ export data",
                              icon: "file-import",
                              iconStyle: "solid",
                              ret: 10,
                            },
                            {
                              ret: 2,
                              icon: "trash-alt",
                              text: "Unsend / Delete",
                              disabled:
                                checklist.state.status === 9 ||
                                checklist.state.status === 10,
                            },
                          ]}
                        />
                      </div>
                    </div>
                    {#if checklist_chevron[checklist.id]}
                      {#each checklist.document_requests as document}
                        <div class="document">
                          <div
                            class="document-inner"
                            class:green-shade={document.state.status === 4}
                            class:red-shade={document.state.status === 2}
                            class:deleted-row={document.state.status === 9 ||
                              document.state.status === 10}
                            on:click|stopPropagation={() => {
                              if (document.state.status == 4) {
                                window.location.hash = `#submission/view/1/${checklist.id}/${document.completion_id}`;
                              } else if (document.state.status == 2) {
                                window.location.hash = `#review/${checklist.contents_id}/document/${document.id}`;
                              } else {
                                showItemPopUp = true;
                                itemToBeViewed = document;
                              }
                            }}
                          >
                            <div class="td name">
                              <span class="document-force-pad" />
                              <div class="">
                                <div class="filerequest">
                                  <span style="position: relative;">
                                    {#if document.is_rspec}
                                      <FAIcon
                                        icon="file-user"
                                        iconStyle="regular"
                                      />
                                    {:else}
                                      <FAIcon
                                        icon="file-alt"
                                        iconStyle="regular"
                                      />
                                    {/if}
                                  </span>
                                  <div class="filerequest-name clickable">
                                    <span>{document.name}</span>
                                    <div>
                                      {document.description}
                                    </div>
                                    <div>
                                      {#if document.tags}
                                        <ul class="reset-style">
                                          {#each document.tags.values as tag}
                                            <Tag
                                              tag={{ ...tag, selected: true }}
                                              listTags={true}
                                            />
                                          {/each}
                                        </ul>
                                      {/if}
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div class="td status ">
                              <DashboardStatus
                                delivery_fault={checklist.state.delivery_fault}
                                state={document.state}
                              />
                            </div>
                            <div class="td  next">
                              <div class="text-xs text-primary">
                                {getNextStatusForTemplates(document, checklist)}
                              </div>
                            </div>
                            <div class="td border-end actions-btn request">
                              {#if checklist.state.delivery_fault}
                                <span
                                  on:click|stopPropagation={() =>
                                    handleDeliveryFaultPopup(data.recipient)}
                                >
                                  <div class="learn-more-btn">
                                    <Button text="Resolve" color="danger" />
                                  </div>
                                </span>
                              {:else if document.state.status == 0}
                                <div
                                  on:click|stopPropagation={() => {
                                    tryRemindNow(
                                      checklist.id,
                                      data.recipient.id,
                                      checklist.last_reminder_info
                                    );
                                  }}
                                >
                                  <Button text="Remind" color="white" />
                                </div>
                              {:else if document.state.status == 1}
                                <div
                                  on:click|stopPropagation={() => {
                                    tryRemindNow(
                                      checklist.id,
                                      data.recipient.id,
                                      checklist.last_reminder_info
                                    );
                                  }}
                                >
                                  <Button text="Remind" color="white" />
                                </div>
                              {:else if document.state.status == 2}
                                <div
                                  on:click|stopPropagation={() =>
                                    (window.location.hash = `#review/${checklist.contents_id}/document/${document.id}`)}
                                >
                                  <Button text="Review" />
                                </div>
                              {:else if document.state.status == 3}
                                <div
                                  on:click|stopPropagation={() => {
                                    tryRemindNow(
                                      checklist.id,
                                      data.recipient.id,
                                      checklist.last_reminder_info
                                    );
                                  }}
                                >
                                  <Button text="Remind" color="white" />
                                </div>
                              {:else if document.state.status == 4}
                                <div
                                  class="view-btn"
                                  on:click|stopPropagation={() => {
                                    window.location.hash = `#submission/view/1/${checklist.id}/${document.completion_id}`;
                                  }}
                                >
                                  <Button text="View" color="gray" />
                                </div>
                              {:else if document.state.status == 9 || document.state.status == 10}
                                <span class="view-btn">
                                  <Button
                                    disabled={true}
                                    text="View"
                                    color="gray"
                                  />
                                </span>
                              {:else}
                                <Button text="_BUG_" />
                              {/if}
                              <!-- Document Level Dropdown -->
                              <Dropdown
                                triggerType="vellipsis"
                                clickHandler={(ret) => {
                                  ret == 2 || ret == 8
                                    ? handleAssignmentDropdownClick(
                                        checklist,
                                        ret,
                                        document
                                      )
                                    : ret == 3
                                    ? handleAssignmentDropdownClick(
                                        checklist,
                                        ret,
                                        document
                                      )
                                    : ret == 4
                                    ? handleAssignmentDropdownClick(
                                        checklist,
                                        ret,
                                        document
                                      )
                                    : ret == 5
                                    ? handleAssignmentDropdownClick(
                                        checklist,
                                        ret,
                                        document
                                      )
                                    : ret == 6 // Change back to bring back details
                                    ? tryRemindNow(
                                        checklist.id,
                                        data.recipient.id,
                                        checklist.last_reminder_info
                                      )
                                    : ret == 7
                                    ? (window.location.hash = `#review/${checklist.contents_id}/document/${document.id}`)
                                    : handleAssignmentDropdownClick(
                                        checklist,
                                        ret,
                                        document
                                      );
                                }}
                                elements={[
                                  // { ret: , icon: "info-square", text: "Details" }, Needs more work Seperate Ticket
                                  {
                                    ret: 7,
                                    icon: "glasses",
                                    text: "Review",
                                    disabled: document.state.status !== 2,
                                  },
                                  {
                                    ret: 6,
                                    icon: "bell",
                                    text: "Remind",
                                    disabled:
                                      checklist.state.status === 2 ||
                                      document.state.status === 9 ||
                                      document.state.status === 10 ||
                                      checklist.state.status === 4,
                                  },
                                  {
                                    ret: 8,
                                    icon: "eye",
                                    text: "View",
                                    disabled: document.state.status !== 0,
                                  },
                                  {
                                    ret: 15,
                                    icon: "glasses",
                                    text: "Document history",
                                    disabled:
                                      document.document_history.length === 0,
                                  },
                                  {
                                    ret: 10,
                                    icon: "undo",
                                    text: "Update and resend",
                                    disabled:
                                      document.state.status !== 0 ||
                                      !document.is_rspec,
                                  },
                                  {
                                    ret: 3,
                                    icon: "print",
                                    text: "Print",
                                    disabled:
                                      isSafari ||
                                      isMobile() ||
                                      document.state.status === 9 ||
                                      document.state.status === 10,
                                  },
                                  {
                                    ret: 4,
                                    icon: "download",
                                    text: "Download",
                                    disabled:
                                      document.state.status === 9 ||
                                      document.state.status === 10,
                                  },
                                  {
                                    text: "Upload For Client",
                                    icon: "file-upload",
                                    iconStyle: "solid",
                                    disabled: document.state.status != 0,
                                    ret: 5,
                                  },
                                  {
                                    ret: 2,
                                    icon: "trash-alt",
                                    text: "Unsend / Delete",
                                    disabled:
                                      document.state.status === 9 ||
                                      document.state.status === 10,
                                  },
                                ]}
                              />
                            </div>
                          </div>
                        </div>
                      {/each}
                      {#each checklist.file_requests as file}
                        {#if file.flags !== 4}
                          <div class="document ">
                            <div
                              class:green-shade={file.state.status === 4 ||
                                file.state.status === 6}
                              class:red-shade={file.state.status === 5 ||
                                file.state.status === 2}
                              class:deleted-row={file.state.status === 9 ||
                                file.state.status === 10}
                              class="document-inner"
                              on:click|stopPropagation={() => {
                                if (file.state.status == 4) {
                                  if (file.type == "data") {
                                    fillViewModal = true;
                                    fillText = file.value;
                                  } else {
                                    window.location.hash = `#submission/view/2/${checklist.id}/${file.completion_id}`;
                                  }
                                } else if (
                                  file.state.status == 2 ||
                                  file.state.status == 5
                                ) {
                                  window.location.hash = `#review/${checklist.contents_id}`;
                                } else {
                                  showItemPopUp = true;
                                  itemToBeViewed = file;
                                }
                              }}
                            >
                              <div class="td name clickable">
                                <span class="document-force-pad" />
                                <div style="width: 90%;">
                                  <div class="filerequest">
                                    <span style="position: relative;">
                                      {#if file.type == "file" && file.flags == 2}
                                        <FAIcon
                                          icon="paperclip"
                                          iconStyle="regular"
                                          iconSize="small"
                                        />
                                      {:else if file.type == "file"}
                                        <FAIcon
                                          icon="paperclip"
                                          iconStyle="regular"
                                          iconSize="small"
                                        />
                                      {:else if file.type == "data"}
                                        <span style="margin-left: -0.5rem;">
                                          <FAIcon
                                            icon="font-case"
                                            iconStyle="regular"
                                            iconSize="small"
                                          />
                                        </span>
                                      {:else if file.type == "task"}
                                        <FAIcon
                                          icon="thumbtack"
                                          iconStyle="regular"
                                          iconSize="small"
                                        />
                                      {/if}
                                    </span>
                                    <div class="filerequest-name">
                                      <span class="truncate">{file.name}</span>
                                      {#if file.type == "task"}
                                        {#if !(file.state.status == 9 || file.state.status == 10)}
                                          <RecipientTaskDescription
                                            description={file.description}
                                          />
                                        {/if}
                                        {#if file.link && Object.keys(file.link).length !== 0 && file.link.url != ""}
                                          <div
                                            style="font-style: normal;
                                                  font-weight: normal;
                                                  font-size: 12px;
                                                  line-height: 24px;
                                                  color: #76808b;
                                                  margin-top: 0px;"
                                          >
                                            <a
                                              target="_blank"
                                              href={getValidUrlLink(
                                                file.link.url
                                              )}
                                            >
                                              {file.link.url}
                                            </a>
                                          </div>
                                        {/if}
                                      {:else if file.type == "file"}
                                        {#if file.flags == 2}
                                          <div>Additional File Uploads</div>
                                        {:else if file.description != ""}
                                          <div class="truncate">
                                            {file.description}
                                          </div>
                                        {/if}
                                      {:else if file.type == "data"}
                                        <div>
                                          {#if file.description != ""}
                                            <div class="truncate">
                                              {file.description}
                                            </div>
                                          {/if}
                                          <span
                                            class="truncate"
                                            on:copy={() => {
                                              showToast(
                                                `Copied to clipboard.`,
                                                1000,
                                                "default",
                                                "MM"
                                              );
                                            }}
                                            style="cursor: auto;"
                                            >{file.value}</span
                                          >
                                        </div>
                                      {:else if file.type == "data"}
                                        <div>Task</div>
                                      {/if}
                                    </div>
                                  </div>
                                </div>
                              </div>
                              <div class="td border-middle status">
                                <DashboardStatus
                                  delivery_fault={checklist.state
                                    .delivery_fault}
                                  missing_reason={file.missing_reason}
                                  state={file.state}
                                  expiration_info={file.expiration_info}
                                />
                              </div>
                              <div class="td  next">
                                <div class="text-xs text-primary">
                                  {getNextStatusForReq(file, checklist)}
                                </div>
                              </div>
                              <div class="td border-end actions-btn request">
                                {#if checklist.state.delivery_fault}
                                  <span
                                    on:click|stopPropagation={() =>
                                      handleDeliveryFaultPopup(data.recipient)}
                                  >
                                    <div class="learn-more-btn">
                                      <Button text="Resolve" color="danger" />
                                    </div>
                                  </span>
                                {:else if file.has_expired}
                                  <div
                                    on:click|stopPropagation={() => {
                                      returnExpiredDoc(
                                        file.completion_id,
                                        "request"
                                      );
                                    }}
                                  >
                                    <Button text="Expired" color="primary" />
                                  </div>
                                {:else if file.state.status == 0}
                                  <div
                                    on:click|stopPropagation={() => {
                                      tryRemindNow(
                                        checklist.id,
                                        data.recipient.id,
                                        checklist.last_reminder_info
                                      );
                                    }}
                                  >
                                    <Button text="Remind" color="white" />
                                  </div>
                                {:else if file.state.status == 1}
                                  <div
                                    on:click|stopPropagation={() => {
                                      tryRemindNow(
                                        checklist.id,
                                        data.recipient.id,
                                        checklist.last_reminder_info
                                      );
                                    }}
                                  >
                                    <Button text="Remind" color="white" />
                                  </div>
                                {:else if file.state.status == 2 || file.state.status == 5}
                                  {#if file.type == "file"}
                                    <div
                                      on:click|stopPropagation={() =>
                                        (window.location.hash = `#review/${checklist.contents_id}`)}
                                    >
                                      <Button text="Review" />
                                    </div>
                                  {:else}
                                    <div
                                      on:click|stopPropagation={() =>
                                        (window.location.hash = `#review/${checklist.contents_id}`)}
                                    >
                                      <Button text="Review" />
                                      <!-- {checklist.id} -->
                                    </div>
                                  {/if}
                                {:else if file.state.status == 3}
                                  <div
                                    on:click|stopPropagation={() => {
                                      tryRemindNow(
                                        checklist.id,
                                        data.recipient.id,
                                        checklist.last_reminder_info
                                      );
                                    }}
                                  >
                                    <Button text="Remind" color="white" />
                                  </div>
                                {:else if file.state.status == 4}
                                  {#if file.type == "data"}
                                    <span
                                      class="view-btn"
                                      on:click|stopPropagation={() => {
                                        fillViewModal = true;
                                        fillText = file.value;
                                      }}
                                    >
                                      <Button text="View" color="gray" />
                                    </span>
                                  {:else if file.type == "task" && file.has_confirmation_file_uploaded}
                                    <div
                                      class="view-btn"
                                      on:click|stopPropagation={() => {
                                        window.location.hash = `#submission/view/2/${checklist.id}/${file.task_confirmation_file_id}`;
                                      }}
                                    >
                                      <Button text="View" color="gray" />
                                    </div>
                                  {:else}
                                    <div
                                      class="view-btn"
                                      on:click|stopPropagation={() => {
                                        window.location.hash = `#submission/view/2/${checklist.id}/${file.completion_id}`;
                                      }}
                                    >
                                      <!-- <Button text="&nbsp;&nbsp;View&nbsp;&nbsp;" color="gray" /> -->

                                      <Button text="View" color="gray" />
                                    </div>
                                  {/if}
                                {:else if file.state.status == 9 || file.state.status == 10}
                                  <span class="view-btn">
                                    <Button
                                      disabled={true}
                                      text="View"
                                      color="gray"
                                    />
                                  </span>
                                {:else if file.state.status == 6}
                                  <span class="view-btn">
                                    <Button
                                      disabled={true}
                                      text="View"
                                      color="gray"
                                    />
                                  </span>
                                {:else}
                                  <Button text="_BUG_" />
                                {/if}
                                <!-- Request Level Dropdown -->
                                <Dropdown
                                  triggerType="vellipsis"
                                  clickHandler={(ret) => {
                                    ret == 3 || ret == 8
                                      ? handleRequestDropdownClick(
                                          checklist,
                                          file,
                                          ret
                                        )
                                      : ret == 4
                                      ? handleRequestDropdownClick(
                                          checklist,
                                          file,
                                          ret
                                        )
                                      : ret == 7
                                      ? (window.location.hash = `#review/${checklist.contents_id}`)
                                      : ret != 6
                                      ? handleRequestDropdownClick(
                                          checklist,
                                          file,
                                          ret
                                        )
                                      : tryRemindNow(
                                          checklist.id,
                                          data.recipient.id,
                                          checklist.last_reminder_info
                                        );
                                  }}
                                  elements={[
                                    {
                                      ret: 7,
                                      icon: "glasses",
                                      text: "Review",
                                      disabled: file.state.status !== 2,
                                    },
                                    {
                                      ret: 6,
                                      icon: "bell",
                                      text: "Remind",
                                      blocked:
                                        file.state.status === 2 ||
                                        file.state.status === 5 ||
                                        file.state.status === 4 ||
                                        file.state.status === 9 ||
                                        file.state.status === 10 ||
                                        file.state.status === 6,
                                    },
                                    {
                                      ret: 2,
                                      text: "Upload For Client",
                                      icon: "file-upload",
                                      iconStyle: "solid",
                                      disabled:
                                        file.state.status != 0 ||
                                        file.type == "data",
                                    },
                                    {
                                      ret: 1,
                                      text: "Mark Unavailable",
                                      icon: "xmark",
                                      iconStyle: "solid",
                                      disabled:
                                        file.state.status === 9 ||
                                        file.state.status === 10 ||
                                        file.state.status == 4 ||
                                        file.state.status == 2,
                                    },
                                    {
                                      ret: 3,
                                      text: "Print",
                                      icon: "print",
                                      iconStyle: "solid",
                                      disabled:
                                        file.state.status === 9 ||
                                        file.state.status === 10 ||
                                        file.state.status == 0 ||
                                        file.state.status == 1 ||
                                        file.type == "task" ||
                                        file.type == "data" ||
                                        isSafari ||
                                        isMobile(),
                                    },
                                    {
                                      ret: 4,
                                      text: "Download",
                                      icon: "download",
                                      iconStyle: "solid",
                                      disabled:
                                        file.state.status === 9 ||
                                        file.state.status === 10 ||
                                        file.state.status == 0 ||
                                        file.state.status == 1 ||
                                        file.type == "task" ||
                                        file.type == "data",
                                    },
                                    {
                                      ret: 0,
                                      text: "Delete / Unsend",
                                      icon: "trash-alt",
                                      iconStyle: "solid",
                                      disabled:
                                        file.state.status === 9 ||
                                        file.state.status === 10,
                                    },
                                    {
                                      text: "Edit Expiration",
                                      icon: "edit",
                                      iconStyle: "solid",
                                      ret: 8,
                                      disabled:
                                        file.state.status === 0 ||
                                        file.state.status === 1 ||
                                        file.state.status === 3 ||
                                        file.state.status === 5 ||
                                        file.state.status === 6 ||
                                        file.type === "task" ||
                                        file.type === "data",
                                    },
                                  ]}
                                />
                              </div>
                            </div>
                          </div>
                        {/if}
                      {/each}

                      {#each checklist.forms as form}
                        <div class="document">
                          <div
                            class="document-inner"
                            class:green-shade={form.state.status === 4}
                            class:red-shade={form.state.status === 2}
                            class:deleted-row={form.state.status === 9 ||
                              form.state.status === 10}
                            on:click|stopPropagation={() => {
                              if (form.state.status == 2) {
                                window.location.hash = `#review/${checklist.contents_id}/form/${form.id}`;
                              } else if (form.state.status == 4) {
                                window.location.hash = `#submission/view/8/${checklist.id}/${form.id}`;
                              }
                            }}
                          >
                            <div class="td name">
                              <span class="document-force-pad" />
                              <div class="">
                                <div class="filerequest">
                                  <span
                                    style="position: relative; margin-left: -0.5rem;"
                                  >
                                    <FAIcon
                                      icon="rectangle-list"
                                      iconStyle="regular"
                                    />
                                  </span>
                                  <div class="filerequest-name clickable">
                                    <span class="truncate">{form.title}</span>
                                    <div class="truncate">
                                      {form.description}
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div class="td status ">
                              <DashboardStatus
                                delivery_fault={checklist.state.delivery_fault}
                                state={form.state}
                              />
                            </div>
                            <div class="td  next">
                              <div class="text-xs text-primary">
                                {getNextStatusForTemplates(document, checklist)}
                              </div>
                            </div>
                            <div class="td border-end actions-btn request">
                              {#if checklist.state.delivery_fault}
                                <span
                                  on:click|stopPropagation={() =>
                                    handleDeliveryFaultPopup(data.recipient)}
                                >
                                  <div class="learn-more-btn">
                                    <Button text="Resolve" color="danger" />
                                  </div>
                                </span>
                              {:else if form.state.status == 0}
                                <div
                                  on:click|stopPropagation={() => {
                                    tryRemindNow(
                                      checklist.id,
                                      data.recipient.id,
                                      checklist.last_reminder_info
                                    );
                                  }}
                                >
                                  <Button text="Remind" color="white" />
                                </div>
                              {:else if form.state.status == 1}
                                <div
                                  on:click|stopPropagation={() => {
                                    tryRemindNow(
                                      checklist.id,
                                      data.recipient.id,
                                      checklist.last_reminder_info
                                    );
                                  }}
                                >
                                  <Button text="Remind" color="white" />
                                </div>
                              {:else if form.state.status == 2}
                                <div
                                  on:click|stopPropagation={() =>
                                    (window.location.hash = `#review/${checklist.contents_id}/form/${form.id}`)}
                                >
                                  <Button text="Review" />
                                </div>
                              {:else if form.state.status == 3}
                                <div
                                  on:click|stopPropagation={() => {
                                    tryRemindNow(
                                      checklist.id,
                                      data.recipient.id,
                                      checklist.last_reminder_info
                                    );
                                  }}
                                >
                                  <Button text="Remind" color="white" />
                                </div>
                              {:else if form.state.status == 4}
                                <div
                                  class="view-btn"
                                  on:click|stopPropagation={() => {
                                    window.location.hash = `#submission/view/8/${checklist.id}/${form.id}`;
                                  }}
                                >
                                  <Button text="View" color="gray" />
                                </div>
                              {:else if form.state.status == 9 || form.state.status == 10}
                                <span class="view-btn">
                                  <Button
                                    disabled={true}
                                    text="View"
                                    color="gray"
                                  />
                                </span>
                              {:else}
                                <Button text="_BUG_" />
                              {/if}
                              <!-- Form Level Dropdown -->
                              <Dropdown
                                triggerType="vellipsis"
                                clickHandler={(ret) =>
                                  handleFormDropDown(
                                    ret,
                                    form,
                                    checklist,
                                    data
                                  )}
                                elements={[
                                  {
                                    ret: 1,
                                    icon: "glasses",
                                    text: "Review",
                                    disabled: checklist.state.status !== 2,
                                  },
                                  {
                                    ret: 2,
                                    icon: "bell",
                                    text: "Remind",
                                    disabled:
                                      checklist.state.status === 2 ||
                                      form.state.status === 9 ||
                                      form.state.status === 10 ||
                                      checklist.state.status === 9 ||
                                      checklist.state.status === 10 ||
                                      checklist.state.status === 4,
                                  },
                                  {
                                    text: "View/ export data",
                                    icon: "file-import",
                                    iconStyle: "solid",
                                    ret: 10,
                                  },
                                  {
                                    ret: 3,
                                    icon: "trash-alt",
                                    text: "Unsend / Delete",
                                    disabled:
                                      form.state.status === 9 ||
                                      form.state.status === 10,
                                  },
                                ]}
                              />
                            </div>
                          </div>
                        </div>
                      {/each}
                    {/if}
                  </div>
                </div>
              {/each}
              {#if checklist_level.cabinet && checklist_level.cabinet.length != 0}
                <div class="checklist">
                  <div class="td chevron" />
                  <div class="checklist-inner">
                    <div class="checklist-info">
                      <div class="td name">
                        <span class="checklist-force-pad" />
                        <div
                          class="name-chevron"
                          on:click|stopPropagation={() => {
                            cabinet_chevron[data.recipient.id] =
                              !cabinet_chevron[data.recipient.id];
                          }}
                        >
                          {#if cabinet_chevron[data.recipient.id]}
                            <span><FAIcon color={true} icon="minus" /></span>
                          {:else}
                            <span><FAIcon color={true} icon="plus" /></span>
                          {/if}
                        </div>
                        <div
                          class="name-description clickable"
                          on:click|stopPropagation={() => {
                            cabinet_chevron[data.recipient.id] =
                              !cabinet_chevron[data.recipient.id];
                          }}
                        >
                          <div class="name-name truncate">
                            Internal Filing Cabinet
                          </div>
                          <div class="name-desc truncate">
                            Manually added documents for {data.recipient.name}
                          </div>
                        </div>
                      </div>
                      <div class="td  status">
                        <DashboardStatus
                          state={{
                            type: "manually_added",
                            status: 4,
                            date: getLatestCabinetDate(checklist_level.cabinet),
                          }}
                        />
                        <div />
                      </div>
                      <div class="td  next" />
                      <div class="td actions actions-btn">
                        <span
                          on:click|stopPropagation={() => {
                            cabinet_chevron[data.recipient.id] =
                              !cabinet_chevron[data.recipient.id];
                          }}
                        >
                          <Button color="white" text="View" />
                        </span>
                      </div>
                    </div>
                    {#if cabinet_chevron[data.recipient.id]}
                      {#each checklist_level.cabinet as document}
                        <div class="document">
                          <div
                            class="document-inner"
                            on:click|stopPropagation={() => {
                              itemToBeViewed = document;
                              showItemPopUp = true;
                            }}
                          >
                            <div class="td name">
                              <span class="document-force-pad" />
                              <div>
                                <div class="filerequest">
                                  <span>
                                    <FAIcon
                                      icon="file-alt"
                                      iconStyle="regular"
                                    />
                                  </span>
                                  <div
                                    class="filerequest-name clickable"
                                    on:click|stopPropagation={() => {
                                      itemToBeViewed = document;
                                      showItemPopUp = true;
                                      console.log(document);
                                      // window.location = `#submission/view/3/${data.recipient.id}/${document.id}`
                                    }}
                                  >
                                    <span class="truncate">{document.name}</span
                                    >
                                  </div>
                                </div>
                              </div>
                            </div>
                            <div class="td  status">
                              <DashboardStatus state={document.status} />
                            </div>
                            <div class="td next ">
                              <div />
                            </div>
                            <div class="td border-end actions-btn cabinet">
                              <span
                                on:click|stopPropagation={() => {
                                  const specialId = 3;
                                  if (isImage) {
                                    window.location = `#submission/view/${specialId}/${data.recipient.id}/${document.id}`;
                                  } else {
                                    window.location = getFileDownloadUrl({
                                      specialId,
                                      parentId: data.recipient.id,
                                      documentId: document.id,
                                    });
                                  }
                                }}
                              >
                                <Button color="white" text="View" />
                              </span>
                              <!-- Cabinent Level Dropdown Will be added in 4273 -->
                              <Dropdown
                                triggerType="vellipsis"
                                clickHandler={(ret) => {
                                  handleCabinetClick(
                                    {
                                      id: document.id,
                                      recipientId: data.recipient.id,
                                      name: document.name,
                                    },
                                    ret
                                  );
                                }}
                                elements={[
                                  {
                                    ret: 1,
                                    icon: "trash-alt",
                                    text: "Delete",
                                  },
                                ]}
                              />
                            </div>
                          </div>
                        </div>
                      {/each}
                    {/if}
                  </div>
                </div>
              {/if}
            {/await}
          {/if}
        </div>
        <div class="mobile-recipient">
          <DashboardMobileView
            {data}
            {tryRemindNow}
            {handleContactLevelDropDown}
            {handleRequestDropdownClick}
            {handleAssignmentDropdownClick}
            {handleFormDropDown}
            on:showItemDetails={({ detail: { itemData } }) => {
              itemToBeViewed = itemData;
              showItemPopUp = true;
            }}
          />
        </div>
      {/each}
      <TablePager
        page={pageNumber}
        {totalPages}
        {handleNextPage}
        {handlePrevPage}
      />
    {:else if search_value != "" && !assignmentsData.length}
      <EmptyDefault
        cancelButton={true}
        defaultHeader="No Search results!"
        defaultMessage="No results for this search on this screen"
        on:close={() => {
          search_value = "";
          loadPaginatedAssignments();
        }}
      />
    {:else}
      <EmptyDefault
        defaultHeader="Nothing to track!"
        defaultMessage="Seems like you have nothing to track, start now by assigning some checklists to some contacts"
      />
    {/if}
  </div>
</section>

{#if handleDeliveryFault}
  <EmailFaultDialog
    email={deliveryfaultData.email}
    user_name={deliveryfaultData.name}
    company={deliveryfaultData.company}
    recipient_id={deliveryfaultData.id}
    on:close={() => {
      handleDeliveryFault = false;
      deliveryfaultData = null;
    }}
  />
{/if}

{#if showConfirmationDeleteItem}
  <ConfirmationDialog
    question="Are you sure you want to unsend this item? The recipient will no longer be able to complete it. This cannot be undone."
    yesText="Yes, Delete"
    noText="No, Keep It"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      if (delete_data.target_type == "request") {
        if (delete_data.isComplete) {
          const params = {
            assignment_id: delete_data.assignment_id,
            id: delete_data.target_id,
            type: "request",
            completion_id: delete_data.completion_id,
          };

          console.log(delete_data);
          // return;
          deleteCompleteItem(params)
            .then(() => loadFilteredAssignments())
            .catch(() => {
              showToast(
                "Error occurred while exporting CSV. Try again or contact support.",
                1500,
                "error",
                "MM"
              );
            });
        } else {
          checklistRescindRequest(
            delete_data.assignment_id,
            delete_data.contents_id,
            delete_data.target_type,
            delete_data.target_id
          ).then(() => {
            loadPaginatedAssignments(pageNumber);
          });
        }
      } else if (delete_data.target_type == "document") {
        if (delete_data.isComplete) {
          const params = {
            assignment_id: delete_data.assignment_id,
            id: delete_data.target_id,
            type: "document",
            completion_id: delete_data.completion_id,
          };

          console.log(delete_data);
          // return;
          deleteCompleteItem(params)
            .then(() => loadFilteredAssignments())
            .catch(() => {
              showToast(
                "Error occured while deleting the document. Try again or contact support.",
                1500,
                "error",
                "MM"
              );
            });
        } else {
          checklistRescindTemplate(
            delete_data.assign_id,
            delete_data.contents_id,
            delete_data.target_type,
            delete_data.target_id
          ).then(() => {
            loadPaginatedAssignments(pageNumber);
          });
        }
      } else if (delete_data.target_type == "form") {
        if (delete_data.action == "delete") {
          deleteFormSubmission(delete_data.target_id)
            .then(() => {
              loadPaginatedAssignments(pageNumber);
            })
            .catch((err) => {
              showToast(
                "Error occurred while deleting the form",
                1500,
                "error",
                "MM"
              );
              console.error(err);
            });
        } else if (delete_data.action == "unsend") {
          unsendForm(delete_data.assign_id, delete_data.target_id)
            .then(() => {
              loadPaginatedAssignments(pageNumber);
            })
            .catch((err) => {
              showToast(
                "Error occurred while unsending the form",
                1500,
                "error",
                "MM"
              );
              console.error(err);
            });
        }
      }
      showConfirmationDeleteItem = false;
    }}
    on:close={() => {
      showConfirmationDeleteItem = false;
    }}
  />
{/if}

{#if showItemPopUp}
  <ConfirmationDialog
    title="Item Details"
    itemDisplay={itemToBeViewed}
    popUp={true}
    on:yes={() => {
      decideView(itemToBeViewed);
    }}
    on:close={() => {
      showItemPopUp = false;
      itemToBeViewed = null;
    }}
  />
{/if}

{#if showUnsendPromt}
  <ConfirmationDialog
    question={`Are you sure you want to Unsend / Delete this Checklist from this Contact? This action can not be reverted.`}
    yesText="Yes, Delete"
    noText="No, Keep it"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      unsendAssignment(unsendThis.id).then(() => {
        showToast(
          `Checklist "${unsendThis.name}" has been unsent.`,
          3000,
          "default",
          "MM"
        );
        loadPaginatedAssignments(pageNumber);
        unsendThis = null;
        showUnsendPromt = false;
      });
    }}
    on:close={() => {
      unsendThis = null;
      showUnsendPromt = false;
    }}
  />
{/if}

{#if showIACSignatureResetConfirmation}
  <ConfirmationDialog
    question={`Are you sure you want to update document? This will reset the signature fields`}
    yesText="Yes, Reset & continue"
    noText="No, Cancel"
    yesColor="secondary"
    noColor="white"
    on:yes={async () => {
      const { recipientId, contentsId, iacDocId } = iacFilldata;
      await resetRequestorSignatureFields(iacDocId, contentsId, recipientId);
      window.location.hash = `#iac/fill/${iacDocId}/${contentsId}/${recipientId}?editMode=true`;
    }}
    on:close={() => {
      showIACSignatureResetConfirmation = false;
    }}
  />
{/if}

{#if showDocumentVersionHistory}
  <ListView
    data={DocumentVersionData["history"]}
    metadata={DocumentVersionData["metadata"]}
    on:close={() => (showDocumentVersionHistory = false)}
  />
{/if}

{#if showArchivePromt}
  <ConfirmationDialog
    question={`Are you sure you want to archive this checklist? It will be accessible via Contact Details and no longer appear on the Dashboard.`}
    yesText="Yes, Archive"
    noText="No, Cancel"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      archiveAssignment(archiveThis.id).then(() => {
        showToast(
          `Checklist "${archiveThis.name}" has been archived.`,
          3000,
          "default",
          "MM"
        );
        loadPaginatedAssignments(pageNumber);
        archiveThis = null;
        showArchivePromt = false;
      });
    }}
    on:close={() => {
      archiveThis = null;
      showArchivePromt = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if fillViewModal}
  <Modal
    on:close={() => {
      fillViewModal = false;
    }}
  >
    <div slot="header">{fillName}</div>

    <div class="filled-text-container">
      {fillText}
    </div>
  </Modal>
{/if}

{#if showConfirmationDialog}
  <ConfirmationDialog
    title="Manual Reminder"
    question={`This message will be emailed as a reminder. Edit as you like, if the note is not changed it will send the default one to the contact.`}
    showReminderInfo={true}
    lastReminderInfo={reminderInfo}
    responseBoxEnable="true"
    responseBoxText="Please complete this as soon as possible, Thanks!"
    responseBoxDemoText="Enter reminder note here"
    yesText="Send"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    on:message={async (evt) => {
      try {
        await handleRemindMessage(evt);
        loadPaginatedAssignments(pageNumber);
      } catch (err) {
        console.error(err);
      }
    }}
    on:yes={ifConfirmed}
    on:close={() => {
      showConfirmationDialog = false;
    }}
  />
{/if}

{#if showUploadModal}
  <UploadFileModal
    on:close={() => {
      showUploadModal = false;
    }}
    on:done={(evt) => {
      console.log(manualUploadData);
      if (manualUploadData.type == "request") {
        fileRequestManualUpload(
          manualUploadData.assignId,
          manualUploadData.id,
          evt.detail.file
        ).then(() => {
          // hide the modal
          showUploadModal = false;
          loadPaginatedAssignments(pageNumber);
        });
      } else {
        templateManualUpload(
          manualUploadData.assignId,
          manualUploadData.id,
          evt.detail.file
        ).then(() => {
          // hide the modal
          showUploadModal = false;
          loadPaginatedAssignments(pageNumber);
        });
      }
    }}
    multiple={false}
  />
{/if}

{#if showMissingReason}
  <Modal
    on:close={() => {
      showMissingReason = false;
    }}
  >
    <div slot="header">Why is "{missingFile.name}" missing?</div>

    <div class="missing-text-container">
      <p>Choose a reason, or use Other to enter custom notes</p>
      <span>
        <Radio
          elements={{
            "Can't Locate": 0,
            "Doesn't Exist": 1,
            "Decline To Provide": 2,
            Expired: 3,
            "No Longer Required": 4,
            "Other / Not Applicable": 5,
          }}
          bind:selectedValue={missingReasonIndex}
        />
      </span>
      {#if missingReasonIndex == missingReasonOther}
        <span style="padding-bottom: 1rem;">
          <TextField
            bind:value={missingReason}
            text="Please enter a custom reason"
          />
        </span>
      {/if}
      <span class="mtc-buttons">
        <span on:click={handleMissingResponse}>
          <Button
            text="Mark as Unavailable"
            disabled={missingReasonIndex == missingReasonOther &&
              missingReason == ""}
            color="primary"
          />
        </span>
        <span
          on:click={() => {
            showMissingReason = false;
          }}
        >
          <Button text="Cancel" color="white" />
        </span>
      </span>
    </div>
  </Modal>
{/if}

{#if showSelectChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={assignPackage}
    on:close={() => {
      showSelectChecklistModal = false;
      assigning_for_id = null;
    }}
  />
{/if}

{#if showCabinentUploadModal}
  <UploadFileModal
    specializedFor="cabinet"
    multiple={false}
    on:done={(evt) => {
      uploadCabinet(evt.detail, CabinetRecipientId).then(() => {
        loadPaginatedAssignments(pageNumber);
        showCabinentUploadModal = false;
      });
    }}
    on:close={() => {
      showCabinentUploadModal = false;
    }}
  />
{/if}

{#if showContactDeleteConfirmationBox}
  <ConfirmationDialog
    title="Warning"
    question={`Delete a user cannot be undone and all records will be removed. To remove the user from the dashboard, choose 'Hide contact' instead.`}
    responseBoxEnable={true}
    details={`To confirm deletion, type ${DELETECONFIRMATIONTEXT} in the text input field.`}
    responseBoxDemoText={DELETECONFIRMATIONTEXT}
    on:message={(event) => tryDeleteRecipient(event)}
    yesText="Delete"
    noText="Cancel"
    hideText="Hide"
    yesColor="danger"
    noColor="gray"
    hideColor="white"
    on:yes={""}
    on:close={() => {
      showContactDeleteConfirmationBox = false;
    }}
    on:hide={() => {
      hideContactOnDashboard(deleteRecipientId);
    }}
  />
{/if}

{#if showContactDeleteOptions}
  <ConfirmationDialog
    title="Warning"
    question={`Would you like to keep this person in your contacts?`}
    yesText="Fully delete"
    noText="Cancel"
    hideText="Keep contact only"
    yesColor="danger"
    noColor="gray"
    hideColor="white"
    on:yes={() => {
      showContactDeleteConfirmationBox = true;
      showContactDeleteOptions = false;
    }}
    on:close={() => {
      showContactDeleteOptions = false;
    }}
    on:hide={async () => {
      unsendRecipientAssignments(deleteRecipientId)
        .then(() => {
          showToast(`All files removed for the contact`, 1500, "default", "MM");
          loadPaginatedAssignments(pageNumber);
        })
        .catch((x) => console.error(x));
      showContactDeleteOptions = false;
    }}
  />
{/if}

{#if showContactHideConfirmationBox}
  <ConfirmationDialog
    title="Warning"
    question={`This will hide the contact from the Dashboard. They can still be accessed via Contacts. Hide them?`}
    yesText="Yes, Hide"
    noText="No, Keep it"
    yesColor="secondary"
    noColor="white"
    on:yes={(evt) => {
      tryhideRecipient(hideRecipientId);
    }}
    on:close={() => {
      showContactHideConfirmationBox = false;
    }}
  />
{/if}

{#if showChooseTemplateModal}
  <ChooseTemplateModal
    fullScreenDisplay={false}
    showSelectionCount={false}
    customButtonText={true}
    buttonText={"Send to Document"}
    on:selectionMade={async (x) => {
      let selected = x.detail.templateIds[0];
      sesData.raw_document_id = selected;
      console.log(sesData);
      let res = await postIACSESFill(sesData);
      let res2 = await res.json();
      let iacDocId = res2.iac_doc_id;
      let contentsId = res2.contents_id;
      let recipientId = sesData.recipient;
      let tc = sesData.contents;
      window.location.hash = `#iac/fill/${iacDocId}/${contentsId}/${recipientId}?sesMode=true&tc=${tc}`;
    }}
    templates={sesTemplates}
    selectOne={true}
    title={"Select Destination Template"}
    on:close={() => {
      showChooseTemplateModal = false;
    }}
  />
{/if}
{#if showCabinetFileDeleteConfirmationDialogBox}
  <ConfirmationDialog
    question={`Are you sure you want to this file deleted from the cabinet?`}
    yesText="Yes, Delete"
    noText="No, Keep it"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      deleteCabinetFile(cabibetFileToDelete);
      showCabinetFileDeleteConfirmationDialogBox = false;
    }}
    on:close={() => {
      cabibetFileToDelete = null;
      showCabinetFileDeleteConfirmationDialogBox = false;
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
  .text-xs {
    font-size: 14px;
    line-height: 21px;
  }
  .text-primary {
    color: #2a2f34;
  }
  .hidden {
    display: hidden;
  }
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

  .deleted-row {
    text-decoration: line-through;
    background: #f5d8cb !important;
  }
  .reset-style {
    margin: 0;
    padding: 0;
    line-height: 9px;
  }

  .missing-text-container {
    display: flex;
    flex-flow: column nowrap;
  }
  .mtc-buttons {
    display: grid;
    grid-template-columns: 1fr 1fr;
    grid-template-rows: 1fr;
    column-gap: 1rem;
  }
  .filerequest {
    display: flex;
    flex-flow: row nowrap;
  }
  .page-header {
    position: sticky;
    top: 0px;
    z-index: 12;
    background: #fcfdff;
    margin-top: -4px;
  }
  .filerequest:nth-child(1) {
    font-size: 24px;
    align-items: center;
    color: #606972;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .filerequest-name {
    width: 90%;
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
  }

  .filerequest-name > *:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
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

  .green-shade {
    background: #d1fae5 !important;
  }

  .red-shade {
    border-color: #db5244 !important;
    border-width: 2px !important;
    border-style: dashed !important;
  }
  .view-btn {
    width: 99px;
  }
  .learn-more-btn {
    width: 100%;
  }
  .bg-tomato {
    background: tomato;
  }
  .actions-btn :global(button) {
    z-index: 10;
    margin-bottom: 0;
  }
  /* Contents */
  .filled-text-container {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    justify-content: center;
    margin-top: 2rem;
    margin-bottom: 2rem;

    width: 100%;
    min-height: 8ch;
    text-align: center;
    font-weight: 600;
    font-size: 30px;
    background-image: repeating-linear-gradient(
      45deg,
      #ccc,
      #ccc 30px,
      #dbdbdb 30px,
      #dbdbdb 60px
    );
    border-radius: 10px;
    border: 1px dashed black;
    overflow-wrap: anywhere;
  }

  .sortable {
    cursor: pointer;
    left: 6px;
    top: 1px;
    position: relative;
    color: #76808b;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  /* Names */
  .name-description {
    width: 90%;
    display: flex;
    flex-flow: column nowrap;
  }

  .name-name {
    display: flex;
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #171f46;
  }

  .name-desc {
    display: flex;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  /* Main table */
  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 0 auto;
  }

  .tr.th {
    display: none;
    background: #f8fafd;
    display: grid;
    grid-template-columns: 10px 1.2fr 1fr;
    justify-items: stretch;
    position: sticky;
    z-index: 11;
    top: 90px;
    height: 40px;
    color: #76808b;
  }
  .status.status-head {
    /* justify-self: center; */
    display: none;
  }
  .actions-head {
    justify-self: center;
  }

  .th > .td {
    white-space: normal;
    justify-content: left;
    /* background: #fcfdff; */
    font-weight: 800;
    font-size: 13px;
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

  .recipient-info {
    width: 100%;
    /* display: flex;
	  flex-flow: row nowrap; */
    display: grid;
    grid-template-columns: 40px 2fr;
    grid-template-rows: 1fr 1fr;
    align-items: center;
    grid-template-areas:
      "a b "
      ". c "
      ". d ";
  }
  .recipient-info .td.chevron {
    grid-area: a;
  }
  .recipient-info .td.name {
    grid-area: b;
  }
  .recipient-info .td.status {
    grid-area: c;
    display: flex;
    align-items: flex-start;
  }
  .td.next {
    /* font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #606972;
    margin: 0; */
    margin-left: 10px;
  }

  .td.left_margin {
    margin-left: 10px;
  }

  .recipient-info .td.actions {
    grid-area: e;
    justify-self: center;
    display: flex;
    justify-content: center;
  }

  .actions-btn {
    width: 100%;
  }
  .actions-btn > span {
    width: 75%;
  }
  .recipient-info.active {
    padding-bottom: 0.5em;
  }

  .recipient {
    background: #ffffff;
    border: 0.53px solid #b3c1d0;
    color: var(--text-secondary);
    box-sizing: border-box;
    border-radius: 10px;
    margin-bottom: 1rem;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
  }

  .checklist {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
    padding-bottom: 1rem;
  }

  .checklist-info {
    /* display: flex;
	  flex-flow: row nowrap; */
    display: grid;
    /* grid-template-columns: 2fr 1fr; */
    align-items: center;
    width: 100%;
    grid-template-columns: 40px 2fr;
    grid-template-rows: 1fr 1fr;
    grid-template-areas:
      "a a "
      ". b"
      ". c";
  }
  .checklist-info .td.name {
    grid-area: a;
  }
  .checklist-info .td.status {
    grid-area: b;
    /* margin-left: 60px; */
    display: flex;
    justify-self: left;
  }
  .checklist-info .td.next {
    grid-area: c;
    justify-self: start;
    display: flex;
    justify-content: center;
    /* padding-right:0.5rem; */
  }
  .checklist-info .td.actions {
    grid-area: d;
    justify-self: center;
    display: flex;
    justify-content: center;

    /* padding-right:0.5rem; */
  }

  .checklist-inner {
    display: flex;
    flex-flow: column nowrap;
    align-items: center;
    width: 100%;

    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
    margin-right: 5px;
  }

  .checklist-force-pad {
    width: 1rem;
  }

  .document {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
  }

  .document-inner {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: calc(100% - 14px);

    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
    display: grid;
    grid-template-columns: 2fr 130px;
    grid-template-rows: 1fr 1fr;
    grid-template-areas:
      "a a "
      "b b"
      "c c";
    margin: 0.5rem auto;
    padding-right: 0.3rem;
  }
  .document-inner .td.name {
    grid-area: a;
  }
  .document-inner .td.status {
    grid-area: b;
    margin-left: 60px;
  }

  .document-inner .td.next {
    grid-area: c;
    display: flex;
    padding-right: 0.5rem;
    justify-self: start;
    align-items: center;
  }

  .document-inner .td.border-end {
    grid-area: d;
    display: flex;
    padding-right: 0.5rem;
    justify-self: start;
    align-items: center;
  }

  .document-force-pad {
    width: calc(1rem + 40px);
  }

  .name-chevron {
    width: 24px;
  }

  .recipient.desktop {
    display: block;
  }

  .mobile-recipient {
    display: none;
  }

  /* .name-chevron.icon {
    font-size: 28px;
    color: #76808b;
    right: 20px;
    display: inline-block;
    position: relative;
  } */

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .td.chevron {
    flex-grow: 0;
    flex-basis: 30px;
    width: 30px;
    justify-content: center;
    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;
  }

  .td.name {
    flex-grow: 3;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .td.actions {
    /* flex-grow: 1;
    justify-content: flex-end;
    align-items: center;
    padding-right: 1rem; */
    justify-content: flex-start;
    /* justify-self:start; */
    align-items: center;
    /* padding-right: 1rem; */
    flex-grow: 1;
  }

  /* .pad {
    display: inline-block;
    width: 17px;
  } */

  /* Container */
  .container {
    /* padding-right: 4rem; */
  }

  .clickable {
    cursor: pointer;
  }
  .td.border-end {
    display: grid;
    justify-items: start;
  }
  .tr.th .td.status {
    margin-left: 0;
  }
  @media only screen and (min-width: 640px) {
    .tr.th {
      grid-template-columns: 40px 1.7fr 1.5fr 1fr 145px;
    }

    .th > .td {
      font-weight: 600;
      font-size: 14px;
    }
    .recipient-info {
      grid-template-columns: 40px 1.7fr 1fr 1fr 145px;
      grid-template-areas: "a b c d e";
      grid-template-rows: 1fr;
    }
    .recipient-info .td.actions {
      margin-right: 1.5rem;
    }
    .checklist-info .td.actions {
      margin-right: 1.3rem;
    }
    .recipient-info .td.actions > span {
      width: 70%;
    }
    .md\:flex {
      display: flex !important;
    }
    .td.status {
      display: grid;
      justify-items: start;
    }

    .checklist-info {
      grid-template-areas: "a b c d ";
      grid-template-rows: 1fr;
      grid-template-columns: 1.7fr 0.95fr 0.95fr 130px;
      padding-right: 1rem;
    }
    .checklist-info .td.status {
      margin-left: 0px;
    }
    .document-inner {
      grid-template-areas: "a b c d";
      grid-template-rows: 1fr;
      grid-template-columns: 1.7fr 0.95fr 0.95fr 130px;

      /* grid-template-columns: 1.75fr 1fr 0.75fr; */
    }
    .document-inner .td.status {
      margin-left: 0px;
    }
  }

  @media only screen and (min-width: 780px) {
    .tr.th {
      grid-template-columns: 30px 1.7fr 1fr 1fr 145px;
    }
    .document-inner {
      padding-right: 1rem;
    }
    .actions-head {
      padding-right: 30px;
    }
  }
  @media only screen and (max-width: 640px) {
    .actions-head {
      display: none;
    }

    .actions-btn.request div {
      width: 75%;
      margin-left: auto;
    }

    .actions-btn.cabinet span {
      margin-left: auto;
      margin-right: 11px;
    }
  }

  @media only screen and (max-width: 767px) {
    .tr.th {
      top: 0;
    }
    .recipient.desktop {
      display: none;
    }
    .mobile-recipient {
      display: flex;
      flex-direction: column;
      gap: 0.5rem;
    }
    .loader-container {
      height: 70vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }
  }
</style>
