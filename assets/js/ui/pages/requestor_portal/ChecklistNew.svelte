<script>
  import QrCode from "svelte-qrcode";
  import Button from "../../atomic/Button.svelte";
  import NavBar from "../../components/NavBar.svelte";
  import TabBar from "../../components/TabBar.svelte";
  import BottomBar from "../../components/BottomBar.svelte";
  import TextField from "../../components/TextField.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import ChooseTemplateModal from "../../modals/ChooseTemplateModal.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import { onMount } from "svelte";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import Switch from "../../components/Switch.svelte";
  import { isMobile } from "Helpers/util";
  import {
    DUEDATESTEP,
    MINDUEDATE,
    MAXDUEDATE,
    DEFAULTDUEDATE,
  } from "../../../constants";
  import * as checklistUtils from "../../../helpers/Requester/checklistNew";

  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import ChooseRecipientModal from "../../modals/ChooseRecipientModal.svelte";
  import Checkbox from "../../components/Checkbox.svelte";
  import ButtonGroups from "../../components/ButtonGroups.svelte";
  import Modal from "Components/Modal.svelte";
  import NewModal from "../../modals/Modal.svelte";
  import Editor from "Components/Editor.svelte";
  import ProgressTab from "../../components/ProgressTab.svelte";
  import { getTemplate } from "BoilerplateAPI/Template";
  import {
    isNullOrUndefined,
    searchParamObject,
    isUrl,
    isValidFormFields,
    getValidUrlLink,
  } from "../../../helpers/util";
  import { createIntakeLink } from "../../../api/Checklist";
  import Card from "../../components/Card.svelte";
  import FormTitleEdit from "../../components/Form/FormTitleEdit.svelte";
  import { formStore } from "../../../stores/formStore";
  import FormCommands from "../../components/Form/FormCommands.svelte";
  import Question from "../../components/Form/Question.svelte";
  import FormElementRenderer from "../../components/Form/FormElementRenderer.svelte";
  import FormTitleRenderer from "../../components/Form/FormTitleRenderer.svelte";
  import ChecklistDocumentTable from "../../tables/ChecklistDocumentTable.svelte";
  import ChecklistFileRequestsTable from "../../tables/ChecklistFileRequestsTable.svelte";
  import InputNumber from "../../components/InputNumber.svelte";
  import { requestorTemplateNonIACExtensions } from "../../../helpers/fileHelper";
  import Instruction from "../../components/Form/Instruction.svelte";
  import {
    CHECKLISTSEARCHPARAMKEY,
    CURRENTLYSELECTEDRECIPIENT,
    DIRECTSENDURLPARAMKEY,
    DOARCHIVE,
  } from "../../../helpers/constants";
  import {
    sessionStoragePop,
    sessionStorageSave,
  } from "../../../helpers/sessionStorageHelper";
  import { showErrorMessage } from "Helpers/Error";
  import { createTemplate } from "../../../api/Template";
  import CheckListForm from "../../components/CheckListForm.svelte";
  import ChooseExistingFormModal from "../../modals/ChooseExistingFormModal.svelte";
  import {
    EXPIRATIONTRACKINGTEXT,
    ALLOWEXTRAFILESTOUPLOADTEXT,
  } from "../../../helpers/constants";
  import { getCompanyId } from "Helpers/Features";
  import DocumentTag from "../../pages/requestor_portal/DocumentTag.svelte";

  let allowDuplicateSubmission = false;
  let allowMultipleRequests = false;
  let allowFileRequestisChecked = false;
  let setDueDate = false;
  let setXDueDays = false;
  let enforceDueDate = setDueDate || setXDueDays;
  let defaultDueDays = DEFAULTDUEDATE;
  let track_document_expiration = false;
  const ADDTIONALFILEUPLOADTYPE = "allow_extra_files";
  let addtionalFileRequestAdded = false;

  let empty_checklist = {
    name: "",
    description: "",
    documents: [],
    file_requests: [],
    allowDuplicateSubmission,
    allowMultipleRequests,
    forms: [],
    enforceDueDate,
    dueDateType: 1,
    defaultDueDays: null,
    tags: [],
  };

  let tagsSelected = [];
  let company_id = 0;

  // Intake
  let linkTextCopied = false;
  let copyButtonText = "Copy Link";
  let copyButtonIcon = "";

  export let newChecklist = true;
  export let checklistId = 0;

  let showSelectRecipientModal = false;
  let newChecklistCreatedConfirmation = false;
  let newChecklistId;
  let hasContactSpecificTemplate = [];
  let enableIntakeOption = true;

  let delTemplateDocConfirmation = false;
  let docToBeRemoved = null;
  let checklist = empty_checklist;
  export let isDraftChecklist = false;
  let tabs = [
    { name: "Details", icon: "info-circle" },
    { name: "Options", icon: "gear" },
    { name: "Templates", icon: "copy" },
    { name: "Requests", icon: "plus-square" },
    { name: "Form", icon: "rectangle-list" },
  ];
  let min_tab = 0,
    max_tab = 4;
  let current_tab = 0;
  let new_file_request = "";
  let new_file_request_description = "";
  let new_request_type = "file";
  let showUploadModal = false;
  let showNewTemplateModal = false;
  let current_selection_list = [];
  let is_draft = false;
  let showSubmitWithoutAnyRequestConfirmation = false;
  let abandonChanges = false;
  let leaveChecklistWithoutSave = false;
  let showTaskDetailsModal = false;
  let editorText;

  const setEditorText = (text) => {
    editorText = text;
  };
  const sesExportTooltipTitle =
    "You can choose a document to export data collected from this checklist to. This requires setup.";
  const DueDateTooltipTitle =
    "You can choose a set number of days from sending a checklist now, or be prompted to set a specific date when you send the checklist";
  const repeatChecklistTooltipTitle =
    "Allows same person to Request or Submit a Checklist repeatedly by prompting them to add a unique identifier";
  const repeatSendText =
    "Repeat send: You can send the same checklist to the same person multiple times, i.e. Tax Return Support for 2020 and then again for 2021. You'll be prompted to add a unique reference for each";
  const duplicateSubmissionText =
    "Duplicate submissions: allow the other person to submit the same checklist more than once, i.e. prescriptions, claims, or a weekly report. They'll be asked to add a unique reference to tell them apart.";
  const INVALIDURLMESSAGE = "Error! Invalid url added";
  const INVALIDDUEDATEMESSAGE = `Error! Invalid due days. Should be between ${MINDUEDATE} - ${MAXDUEDATE} days`;
  let askLeaveWithoutSave =
    "Cannot save without a name. Are you sure you want to discard change and go back?";

  const toggleMultipleSubmission = (e) =>
    (allowDuplicateSubmission = e.detail && e.detail.state ? true : false);
  const toggleMultipleRequestSend = (e) =>
    (allowMultipleRequests = e.detail && e.detail.state ? true : false);

  // adding this here for future use
  let fileRetentionPeriod = null;

  let allowSes = false;
  let sesTargetName = [];
  let sesTargetId = [];
  let showChooseSesTemplateModal = false;
  let mergedLabels = [];
  function pickSesTarget() {
    if (allowSes) {
      showChooseSesTemplateModal = true;
    } else {
      sesTargetName = [];
      sesTargetId = [];
    }
  }

  async function getIacLabelsOf(rdId) {
    let r = await fetch(`/n/api/v1/iac/labels/${rdId}`);
    if (r.status != 200) {
      console.error(`Error fetching IAC labels of rd ${rdId}: ${r.status}`);
      return [];
    }
    return await r.json();
  }

  function sesIacLabelsUpdate(sesTargetId) {
    // create the mergedLabels array
    for (let i = 0; i < sesTargetId.length; i++) {
      getIacLabelsOf(sesTargetId[i]).then((arr) => {
        for (let j = 0; j < arr.length; j++) {
          let val = arr[j];
          if (
            val != "" &&
            val != undefined &&
            val != null &&
            !mergedLabels.includes(val)
          ) {
            mergedLabels.push(val);
          }
        }
      });
    }
  }
  function processSesTargetSelection(evt) {
    let selectedTemplates = evt.detail.templates;
    sesTargetName = selectedTemplates.map((x) => x.name);
    sesTargetId = selectedTemplates.map((x) => x.id);
    sesIacLabelsUpdate(sesTargetId);
    showChooseSesTemplateModal = false;
  }

  function handleAddRequest({ detail }) {
    let isValidTask = true;
    if (detail.new_request_type === "task") {
      isValidTask = isValidTaskRequest(
        detail.new_file_request,
        detail.link_button_name,
        detail.link_button_url
      );
    }
    if (isValidTask) {
      showFillModal = false;
      appendFileRequest(detail);
      if (detail.save_and_add) {
        setTimeout(() => {
          showFillModal = true;
        }, 100);
      }
    }
    return isValidTask;
  }

  function appendFileRequest({
    new_file_request_description,
    new_file_request,
    new_request_type,
    track_document_expiration,
    link_button_name,
    link_button_url,
    is_confirmation_required,
  }) {
    let description = new_file_request_description;
    checklist.file_requests.push({
      name: new_file_request.trim(),
      type: new_request_type,
      description: description.trim(),
      new: true,
      allow_expiration_tracking: track_document_expiration,
      link: {
        name: link_button_name.trim(),
        url: getValidUrlLink(link_button_url.trim()),
      },
      id: Math.floor(Math.random() * Math.floor(500000)), // generates randow number of 5 digit length,
      file_retention_period: fileRetentionPeriod,
      is_confirmation_required,
    });

    // Needed to alert Svelte that the checklist object was updated.
    checklist = checklist;

    new_file_request = "";
    new_file_request_description = "";
    link_button_name = "";
    link_button_url = "";
    track_document_expiration = false;
  }

  let additionalFileUploadId = undefined;
  let extraFileRequest = [];
  function addAdditionalFileUploads() {
    const fileReq = checklist.file_requests;
    additionalFileUploadId =
      fileReq.length === 0
        ? 0
        : Math.max.apply(
            Math,
            fileReq.map(function (req) {
              return req.id;
            })
          ) + 1; // assign unique obj id as the max + 1 value of list obj
    extraFileRequest.push({
      name: "Placeholder for Recipient File Uploads",
      type: ADDTIONALFILEUPLOADTYPE,
      description: "to be filled by the recipient on additional file requests",
      new: true,
      id: additionalFileUploadId,
      is_confirmation_required: false,
    });
    addtionalFileRequestAdded = true;
  }

  function removeAdditionalFileUploads(uploadId) {
    checklist.file_requests = checklist.file_requests.filter((e) => {
      return e.id != uploadId;
    });
    checklist = checklist;
    addtionalFileRequestAdded = false;
    additionalFileUploadId = undefined;
    extraFileRequest = [];
  }

  /**
   * @description handler for allow additional file uploads.
   * if box is checked then push to file request list else removes
   *
   * @param evt checkbox status
   *
   * @returns
   */
  function handleAddtionalFileUploadStatus(flag) {
    const isChecked = flag;
    const previousRecipeintAllowFiles =
      checklist.allowed_additional_files_uploads;
    if (isChecked) {
      if (previousRecipeintAllowFiles || addtionalFileRequestAdded) {
        return;
      }
      return addAdditionalFileUploads();
    } else {
      const getCheckboxStatus = checklist.file_requests.filter(
        (request) => request.flags === 4
      );
      const toRemoveId = newChecklist
        ? additionalFileUploadId
        : getCheckboxStatus.length === 1
        ? getCheckboxStatus[0].id
        : additionalFileUploadId;
      if (toRemoveId != undefined && previousRecipeintAllowFiles) {
        return removeAdditionalFileUploads(toRemoveId);
      }
    }
    return;
  }

  let freqID = null;
  let freqName = null;

  function deleteFileRequest(fr) {
    checklist.file_requests = checklist.file_requests.filter((e) => {
      return e.id != fr;
    });
    checklist = checklist;
  }

  function deleteTemplate(doc) {
    let new_documents = checklist.documents.filter((x) => x.id != doc.id);
    current_selection_list = current_selection_list.filter((x) => x != doc.id);

    checklist.documents = new_documents;
    checklist = checklist;
  }

  /* Callback from ChooseTemplateModel */
  async function processSelection(evt) {
    let selectionIds = evt.detail.templateIds;
    let template_list = await Promise.all(
      selectionIds.map((id) => getTemplate(id, "requestor"))
    );

    checklist.documents = checklist.documents.concat(template_list);
    current_selection_list = checklist.documents.map((x) => x.id);
    checklist = checklist;
  }

  function processAssigneSelection(evt) {
    let detail = evt.detail;
    window.location.hash = `#recipient/${detail.recipientId}/assign/${newChecklistId}`;
  }

  function addOrder(element, index) {
    element["order"] = index + 1;
    return element;
  }
  const getDueDateType = () => {
    // 1 -> set during checklist send
    // 2 -> set x due days from send
    return setDueDate === true ? 1 : 2;
  };

  async function submitChecklist(c, redirect) {
    handleAddtionalFileUploadStatus(allowFileRequestisChecked);

    const newForms = $formStore.forms;
    const checklistForms = [...newForms];
    const request_with_order = checklist.file_requests.map(addOrder);
    const fileRequests = [...request_with_order, ...extraFileRequest];
    const _dueDateType = enforceDueDate ? getDueDateType() : null;
    let raw_checklist = {
      name: checklist.name,
      description: checklist.description == "" ? "-" : checklist.description,
      documents: checklist.documents.map((x) => x.id),
      file_requests: fileRequests,
      commit: c,
      ses_struct: {
        allow: allowSes,
        sesTargetId: sesTargetId,
      },
      allow_duplicate_submission: allowDuplicateSubmission,
      allow_multiple_requests: allowMultipleRequests,
      forms: checklistForms,
      enforce_due_date: enforceDueDate,
      due_date_type: _dueDateType,
      due_days: enforceDueDate
        ? getDueDateType() === 2
          ? defaultDueDays
          : null
        : null,
      tags: [...new Set(tagsSelected.map((x) => x.id))],
    };

    extraFileRequest = []; // reset file data, pushed to the checklist request
    if (newChecklist) {
      hasContactSpecificTemplate = checklist.documents.filter((docu) => {
        return docu.is_rspec;
      });

      enableIntakeOption = !(
        hasContactSpecificTemplate.length > 0 ||
        (enforceDueDate && _dueDateType === 1)
      );

      let id;
      if (isDraftChecklist) {
        id = await updateChecklist(checklistId, raw_checklist, redirect);
      } else {
        id = await createNewChecklist({
          ...raw_checklist,
          archive_checklist: isChecklistToArchive,
        });
      }

      newChecklistId = id;
      if (redirect) {
        if (hasRecipientSelected) {
          showToast("Checklist created", 1000, "default", "TM");
          window.location.hash = `#recipient/${selectedRecipientId}/assign/${newChecklistId}`;
        }
        if (isDirectSend) {
          showToast("Checklist created", 1000, "default", "TM");
          return (showSelectRecipientModal = true);
        }
        newChecklistCreatedConfirmation = true;
      }
      return id;
    } else {
      await updateChecklist(checklistId, raw_checklist);
      if (redirect) {
        showToast(`Success! Checklist Updated.`, 1000, "default", "MM");
        newChecklistId = checklistId;
        newChecklistCreatedConfirmation = true;
      }
      return checklistId;
    }
  }

  async function processNewTemplate(evt) {
    // save as draft first to get an id

    let { name: templateName, file } = evt.detail;

    const reply = await createTemplate(
      templateName,
      file,
      isChecklistToArchive
    );

    if (reply.ok) {
      let jsonReply = await reply.json();
      checklist.documents.splice(0, 0, { id: jsonReply.id });
      checklistId = await submitChecklist(
        newChecklist ? false : !is_draft,
        false
      );
      let currentHash = window.location.hash.split("?")[0];

      if (currentHash.match(/#checklists\/new\/(\d+)/)) {
        currentHash = "#checklists/new";
      }

      if (!newChecklist) {
        currentHash = "#checklist";
      }

      // careful: This replaces the browser history in the background. windoe.history.go() points to this url.
      // this is a silent code.
      window.history.replaceState({}, "", `${currentHash}/${checklistId}`);

      window.sessionStorage.setItem("templateTab", true);

      sessionStorageSave(CHECKLISTSEARCHPARAMKEY, currentSearchParams);
      window.location.hash = `#template/${jsonReply.id}?type=newTemplate&userGuide=true`;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }

  async function saveDraft() {
    const isValid = validateChecklistDetails({ checklistName: checklist.name });
    if (isValid) {
      submitChecklist(false, true);
      const toastMessageBody = "Saved as Draft!";
      showToast(toastMessageBody, 2000, "default", "MM");
    } else leaveChecklistWithoutSave = true;
  }

  let formTitle = "";
  let formDescription = "";
  let form_repeat_label = "";
  let has_repeat_entries = false;
  let has_repeat_vertical = false;
  let isFormEdit = false;
  let isFormCreate = false;
  let selectedFormIndex = null;

  let edit_track_document_expiration = false;

  //creating with the title and description than we show the edit page
  const handleCreateForm = () => {
    if (formTitle) {
      formStore.resetQuestions();
      isFormCreate = true;
      isPreview = false;
      formStore.addDetails(
        formTitle,
        formDescription,
        has_repeat_entries,
        has_repeat_vertical,
        form_repeat_label
      );
      formTitle = "";
      formDescription = "";
      has_repeat_entries = false;
      has_repeat_vertical = false;
      form_repeat_label = "";
    }
  };

  let showChooseExistingForm = false;

  //when user finished to edit the form and user add form to the list
  const handleAddForm = () => {
    formStore.addForm();
    isFormCreate = false;
  };

  const handleEditForm = (index) => {
    selectedFormIndex = index;
    formStore.selectForm(index);
    isFormEdit = true;
  };

  const handleUpdateForm = () => {
    isFormEdit = false;
    formStore.handleUpdateForm(selectedFormIndex);
    selectedFormIndex = null;
  };

  const isFormValid = () => {
    if ($formStore.questions.title == "") {
      showToast("Form title is required!", 2500, "error", "MM");
      return false;
    } else if (!$formStore.questions.formFields.length) {
      showToast(
        "There are no questions attached to the form!",
        2500,
        "error",
        "MM"
      );
      return false;
    } else {
      if (!isValidFormFields($formStore.questions.formFields, showToast)) {
        return false;
      }

      formStore.clearEmptyOptions();
      return true;
    }
  };

  async function onSaveChecklist() {
    if (
      !checklist.documents.length &&
      !checklist.file_requests.length &&
      !$formStore.forms.length
    )
      showSubmitWithoutAnyRequestConfirmation = true;
    else {
      submitChecklist(true, true);
      disableMultipleClick = false;
    }
  }

  const redirectAfterUpdate = () => {
    setTimeout(() => {
      window.location.hash = "#checklists";
    }, 1000);
    showToast(`Success! Checklist Updated.`, 1000, "default", "MM");
  };

  async function updateChecklist(id, raw, redirect = false) {
    let reply = await fetch(`/n/api/v1/checklist/${id}`, {
      method: "PUT",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(raw),
    });

    if (reply.ok) {
      return id;
    } else {
      alert("Something went wrong while updating the checklist.");
    }
  }

  /* Finalize the checklist structure and send it to the API */
  async function createNewChecklist(raw_checklist) {
    console.log(`Submitting checklist...`);

    let reply = await fetch("/n/api/v1/checklist", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(raw_checklist),
    });

    if (reply.ok) {
      let j = await reply.json();
      return j.id;
    } else {
      alert("Something went wrong while creating the checklist");
    }
  }

  async function getChecklist(id) {
    let request = await fetch(`/n/api/v1/checklist/${id}`);
    let assignments = await request.json();
    return assignments;
  }

  let editID = null;
  let editName = null;
  let editDetails = "";
  let disableMultipleClick = false;

  let isChecklistToArchive = false;

  // Intake
  let showIntakeModal = false;
  let newIntakeLink = "dummy";

  async function getSecureIntakeLink(newChecklistId) {
    let reply = await createIntakeLink(newChecklistId);
    if (reply.ok) {
      let response = await reply.json();
      newIntakeLink = response.link;
      showIntakeModal = true;
      copyButtonText = "Copy Link";
      copyButtonIcon = "";
    } else {
      let error = await reply.json();
      showErrorMessage("checklist", error.error);
    }
  }

  /**
   * the intend of this function is to get all the search params stored in session storage and
   * append with current params to maintain the correct button states and user flow.
   * Since we rely on window.history.go() which saves the data but buttons and user flow resets to default
   * the better approach is to save the current user data and state before going to templates screen
   */
  const addSearchParams = () => {
    const previousSearchParams =
      sessionStoragePop(CHECKLISTSEARCHPARAMKEY) || "";

    let newSearchParams = "";
    if (!previousSearchParams || previousSearchParams === currentSearchParams)
      return;
    if (previousSearchParams !== currentSearchParams) {
      newSearchParams = previousSearchParams
        ? currentSearchParams
          ? `${previousSearchParams}&${currentSearchParams}`
          : previousSearchParams
        : currentSearchParams;
      if (!currentSearchParams) {
        window.location.hash = `${window.location.hash}?${newSearchParams}`;
      } else {
        window.location.hash.replace(currentSearchParams, newSearchParams);
      }
    }
    return;
  };

  let templateTipsPopUp = false;
  let templateTipsPopUpPage = 0;
  let templateTipsPopUpCheckbox = false;

  const templateTipsPopUpHandleCheckbox = () => {
    templateTipsPopUpCheckbox = !templateTipsPopUpCheckbox;
  };

  let templateTipsPopUpStatus = JSON.parse(
    localStorage.getItem("dontShowNewChecklisttemplateTipsPopUp")
  );
  let requestParams;
  let fromUserGuide = false;
  let isDirectSend = false;
  let selectedRecipientId = false;
  let hasRecipientSelected = false;
  const currentSearchParams = window.location.hash.split("?")[1] || "";
  onMount(async () => {
    //set the user always top of the screen
    let templateTab = JSON.parse(window.sessionStorage?.getItem("templateTab"));
    addSearchParams();
    requestParams = searchParamObject();
    isChecklistToArchive = requestParams[DOARCHIVE] === "true" ? true : false;
    fromUserGuide = requestParams.userGuide === "true" ? true : false;
    isDirectSend =
      requestParams[DIRECTSENDURLPARAMKEY] === "true" ? true : false;
    selectedRecipientId = requestParams[CURRENTLYSELECTEDRECIPIENT];
    hasRecipientSelected = !isNullOrUndefined(selectedRecipientId);
    if (templateTab) {
      current_tab = 2;
      fromUserGuide = true;
      window.sessionStorage.removeItem("templateTab");
    }

    window.scrollTo(0, 0);

    if (!newChecklist || isDraftChecklist) {
      console.log("get checklist api ...");
      getChecklist(checklistId).then((cl) => {
        checklist = cl;
        is_draft = cl.is_draft;
        console.log(`is_draft=${is_draft} newChecklist=${newChecklist}`);
        console.log(checklist);
        current_selection_list = checklist.documents.map((x) => x.id);
        allowDuplicateSubmission = checklist.allow_duplicate_submission;
        allowMultipleRequests = checklist.allow_multiple_requests;
        allowFileRequestisChecked = checklist.allowed_additional_files_uploads;
        enforceDueDate = checklist.enforce_due_date;
        setDueDate = checklist.due_date_type === 1;
        setXDueDays = checklist.due_date_type === 2;
        defaultDueDays = checklist.deadline_due || 1;
        allowSes = checklist.ses_struct.allow;
        sesTargetId = checklist.ses_struct.sesTargetId;
        sesTargetName = checklist.ses_struct.sesTargetName;
        tagsSelected = [...checklist.tags] || [];
        console.log(tagsSelected);
        if (allowSes) {
          sesIacLabelsUpdate(sesTargetId);
        }
        formStore.loadForms(cl.forms);
      });
    } else {
      formStore.reset();
    }
    company_id = await getCompanyId();
  });

  let errors = {};

  /**
   * This is a simple validation for checklist. Currently validates checklist name.
   * To add ther validations for a checklist, provide the value to be checked as an arg. and write the validation logic
   * @param param0 validation fields
   *
   * @returns Boolean
   */
  const validateChecklistDetails = ({ checklistName }) => {
    errors = {};
    const name = checklistName && checklistName.trim();
    if (!name) {
      errors["name"] = ["Please enter a checklist name to continue setup"];
    }

    if (setXDueDays && isInvalidDueDays) {
      askLeaveWithoutSave =
        "Cannot save without a valid due day selected. Are you sure you want to discard change and go back?";
      return false;
    }
    return errors && errors.name ? false : true;
  };

  const handleOnClickTab = (tabIndex) => {
    const checklistName = checklist.name;
    tagsSelected = tagsSelected.length === 0 ? checklist.tags : tagsSelected;
    checklist.tags = tagsSelected;
    const isValidChecklistDetails = validateChecklistDetails({ checklistName });
    if (isValidChecklistDetails) {
      return (current_tab = tabIndex);
    }
  };

  const toggleTaskDetailsModal = () =>
    (showTaskDetailsModal = !showTaskDetailsModal);

  const updateFileRequests = () => {
    const description = editorText || "";
    checklist.file_requests = checklist.file_requests.map((req) => {
      if (req.id != editID) return req;
      req.name = editName;
      req.description = description;
      req.type = "task";
      return req;
    });

    editMode[editID] = false;
    editID = null;
    editName = "";
    editDetails = "";
    showTaskDetailsModal = false;
  };

  const onBackArrow = (hash = "#checklists") => {
    window.location.href = hash;
  };

  let showSaveAsDraftConfirmation = false;
  const handleBackArrowClick = async () => {
    const toastMessageBody = "Checklist Updated";
    const isValidChange = validateChecklistDetails({
      checklistName: checklist.name,
    });
    if (newChecklist) {
      return !isValidChange
        ? (showNoSaveChecklistWarning = true)
        : (showSaveAsDraftConfirmation = true);
    } else {
      if (isValidChange) {
        await onSaveChecklist();
        showToast(toastMessageBody, 2000, "default", "MM");
        onBackArrow("#checklists");
      } else {
        cancelChangeMessage =
          "Invalid checklist name, changes will be discarded?";
        return (abandonChanges = true);
      }
    }
  };

  let showNoSaveChecklistWarning = false;
  let cancelChangeMessage =
    "To save changes, use the finish button in the bottom right.";

  const handleKeyDown = (evt, req) => {
    if (evt.key === "Enter") {
      handleEditRequest(req);
      return;
    }
  };

  const handleEditRequest = ({ name, type, link }) => {
    if (name.trim() === "") {
      currentEditRequest == null;
      showToast("Error! title Cannot be empty", 1000, "error", "MM");
      return;
    } else if (
      type === "task" &&
      !isValidTaskRequest(name, link.name, link.url)
    ) {
      currentEditRequest == null;
      return;
    } else {
      const index = checklist.file_requests.findIndex(
        (req) => req.id === currentEditRequest.id
      );

      if (index === -1) {
        showToast("Error! File request not found!", 2000, "error", "MM");
        console.error(`File request not found at ${index} index`);
        return;
      }
      checklist.file_requests[index] = currentEditRequest;

      showEditModal = false;
    }
  };

  const isValidTaskRequest = (name, label, url) => {
    let validName = name.trim().length > 0;
    let validUrl = url.trim().length > 0 && isUrl(url);
    let validLabelName = label.trim().length > 0;

    if (!validName) {
      showToast("Error! Title cannot be empty.", 2000, "error", "MM");
      return false;
    }

    if (
      (validUrl && validLabelName) ||
      (url.trim() === "" && label.trim() === "")
    ) {
      return true;
    } else if (validUrl && label.trim().length === 0) {
      showToast("Button name cannot be empty.", 2000, "error", "MM");
      return false;
    } else if (url.trim().length === 0 && validLabelName) {
      showToast("Add Url for the the button link", 2000, "error", "MM");
      return false;
    } else if (!validUrl) {
      showToast(INVALIDURLMESSAGE, 2000, "error", "MM");
      return false;
    }
    return false;
  };

  let showFillModal = false;
  let showEditModal = false;
  let showFormCreateModal = false;
  let showExistingFormButton = false;
  let currentEditRequest = null;
  let link_button_name = "";
  let link_button_url = "";
  let isEmptyFileRequest = false;
  // check if the file request excluding the additonal file upload req type is empty
  $: isEmptyFileRequest =
    checklist.file_requests.filter((x) => x.flags !== 4).length === 0;

  let actions = [
    {
      evt: "shareableLink",
      description: "Get shareable link/ QR code",
      icon: "link",
    },
  ];

  let currentIndex;
  let isPreview = false;

  const incrementNumber = () => {
    if (defaultDueDays + DUEDATESTEP >= MAXDUEDATE) {
      defaultDueDays = MAXDUEDATE;
      return;
    }
    defaultDueDays += isNaN(DUEDATESTEP) ? 1 : DUEDATESTEP;
  };

  const decrementNumber = () => {
    if (defaultDueDays - DUEDATESTEP <= MINDUEDATE) {
      defaultDueDays = MINDUEDATE;
      return;
    }
    defaultDueDays -= isNaN(DUEDATESTEP) ? 1 : DUEDATESTEP;
  };

  const switchActionExpiration = (checked) => {
    track_document_expiration = checked;
  };

  const switchActionExpirationRequest = (req, checked) => {
    console.log(req);
    req.allow_expiration_tracking = checked;
    edit_track_document_expiration = req.allow_expiration_tracking;
  };

  const editSwitchActionExpiration = (checked) => {
    currentEditRequest.edit_track_document_expiration = checked;
  };

  const switchAdditionalFiles = (checked) => {
    allowFileRequestisChecked = checked;
  };

  let isInvalidDueDays = false;
  $: isInvalidDueDays =
    isNullOrUndefined(defaultDueDays) ||
    defaultDueDays < MINDUEDATE ||
    defaultDueDays > MAXDUEDATE;

  $: enforceDueDate = setDueDate || setXDueDays;

  // **************************** Buttom Bar Event Handlers *********************** //

  const handleBackButton = () => {
    if (current_tab == min_tab) {
      if (newChecklist || isDirectSend) return handleCancelButton();
      saveDraft();
      showToast(`Saved as Draft!`, 2000, "default", "MM");
      return;
    }
    current_tab--;
    tagsSelected = tagsSelected.length === 0 ? checklist.tags : tagsSelected;
    checklist.tags = tagsSelected;
  };

  const handleNextButton = () => {
    const isValid = validateChecklistDetails({
      checklistName: checklist.name,
    });
    if (isValid) {
      current_tab == max_tab ? current_tab : current_tab++;
    }
    tagsSelected = tagsSelected.length === 0 ? checklist.tags : tagsSelected;
    checklist.tags = tagsSelected;
  };

  const handleCancelButton = () => {
    return (abandonChanges = true);
  };

  const handleSaveChecklists = () => {
    if (!disableMultipleClick) {
      onSaveChecklist();
      disableMultipleClick = true;
    }
  };

  const handleFinishButton = (steadyFinish = false) => {
    const isValid = validateChecklistDetails({
      checklistName: checklist.name,
    });

    if (isValid) {
      if (isFormEdit && !isFormValid()) {
        return;
      }
      if (steadyFinish) {
        return handleSaveChecklists();
      } else {
        if (current_tab == max_tab) {
          return handleSaveChecklists();
        } else {
          current_tab++;
        }
      }
    } else {
      leaveChecklistWithoutSave = true;
    }
  };

  const handleSaveForm = () => {
    if (isFormValid()) {
      if (isFormCreate) {
        handleAddForm();
        return;
      }
      handleUpdateForm();
    }
  };
</script>

<div class="desktop-only">
  <NavBar
    navbar_spacer_classes="navbar_spacer_pb1"
    renderOnlyIcon={true}
    on:arrowClicked={handleBackArrowClick}
    showCompanyLogo={false}
    middleText={`Setup: ${checklist.name}`}
    middleSubText={checklist.description}
  />
</div>

<div class="mobile-only">
  <NavBar
    backLink="  "
    backLinkHref="#checklists"
    on:arrowClicked={handleBackArrowClick}
    navbar_spacer_classes="navbar_spacer_pb1"
    showCompanyLogo={false}
    renderOnlyIcon={true}
    middleText={`Setup: ${checklist.name}`}
    middleSubText={checklist.description}
  />
</div>

<div class="container">
  <section class="content">
    <TabBar
      container_classes="tab-container-center-mobile sticky"
      {tabs}
      {current_tab}
      on:changeTab={({ detail: { tab_index } }) => handleOnClickTab(tab_index)}
    />
    <div class="main-content">
      {#if current_tab == 0}
        <p class="heading">Item Description</p>
        <div class="field">
          <p class="field-title">
            Checklist Name <span class="required">*</span>
          </p>
          <TextField
            bind:value={checklist.name}
            text="Checklist Name"
            invalidInput={errors.name}
            maxlength={"61"}
          />
          {#each errors.name || [] as error}
            <div class="errormessage" id="name">{error}</div>
          {/each}
          {#if checklist.name.length > 60}
            <div class="errormessage" id="name">
              {"Character limit (60) reached."}
            </div>
          {/if}
          {#if checklist.name.replace(/\s/g, "").length < 1 && checklist.name.length >= 1}
            <div class="errormessage" id="name">
              {"All Whitespaces are not allowed."}
            </div>
          {/if}
        </div>
        <div class="field">
          <p class="field-title">Description</p>
          <TextField
            bind:value={checklist.description}
            text="Checklist Description"
            maxlength={"61"}
          />
          {#if checklist.description.length > 60}
            <div class="errormessage" id="name">
              {"Character limit (60) reached."}
            </div>
          {/if}
        </div>
        <div class="field">
          <p class="field-title">Tags</p>
          {#if company_id != 0}
            <DocumentTag
              companyID={company_id}
              bind:tagsSelected
              tagType="recipient"
              templateTagIds={checklist?.tags?.map((tag) => tag.id) || []}
            />
          {/if}
        </div>
      {/if}
      {#if current_tab == 1}
        <div class="field content-width">
          <p class="heading" style="margin-bottom: 20px">
            Additional/ unrequested file uploads
            <span
              class="checklist-new__question-mark tooltip"
              title={"Additional/ unrequested file uploads"}
            >
              <FAIcon icon="question-circle" leftPad />
            </span>
          </p>
          <Switch
            bind:checked={allowFileRequestisChecked}
            text={`${ALLOWEXTRAFILESTOUPLOADTEXT}`}
            action={switchAdditionalFiles}
          />
        </div>
        <div class="field content-width">
          <p class="heading" style="margin-bottom: 20px">
            Set due dates<span
              class="checklist-new__question-mark tooltip"
              title={DueDateTooltipTitle}
              ><FAIcon icon="question-circle" leftPad /></span
            >
          </p>
          <div on:click={() => (setXDueDays = false)}>
            <Checkbox
              text={"Choose a due date when sending each checklist."}
              subtext={"(Cannot share this checklist using intake links)"}
              bind:isChecked={setDueDate}
            />
          </div>
          <div on:click={() => (setDueDate = false)}>
            <Checkbox
              text={"Standard number of days after sending (i.e. 5 days)"}
              bind:isChecked={setXDueDays}
            />
          </div>
          {#if setXDueDays}
            <div class="due-date__container">
              <div>
                <label for="inputfield">Days from sending</label><span
                  class="required"
                >
                  *</span
                >
              </div>
              <InputNumber
                bind:value={defaultDueDays}
                minValue={MINDUEDATE}
                maxValue={MAXDUEDATE}
                step={DUEDATESTEP}
                onDecrementHandler={decrementNumber}
                onIncrementHandler={incrementNumber}
              />
              {#if isInvalidDueDays}
                <p class="errormessage">{INVALIDDUEDATEMESSAGE}</p>
              {/if}
            </div>
          {/if}
          <div class="field content-width">
            <p class="heading" style="margin-bottom: 20px">
              Checklist-To-Document Export<span
                class="checklist-new__question-mark tooltip"
                title={sesExportTooltipTitle}
                ><FAIcon icon="question-circle" leftPad /></span
              >
            </p>
            <div>
              <Checkbox
                text={sesTargetName != []
                  ? `Allow this checklist to be exported to these template(s): ${sesTargetName.join(
                      ", "
                    )}`
                  : "Allow this checklist to be exported to PDF templates"}
                bind:isChecked={allowSes}
                on:changed={pickSesTarget}
              />
            </div>
          </div>
        </div>
        <div class="field content-width">
          <p class="heading" style="margin-bottom: 20px">
            Repeat Checklist<span
              class="checklist-new__question-mark tooltip"
              title={repeatChecklistTooltipTitle}
              ><FAIcon icon="question-circle" leftPad /></span
            >
          </p>
          <Checkbox
            text={repeatSendText}
            isChecked={allowMultipleRequests}
            on:changed={toggleMultipleRequestSend}
          />
          <Checkbox
            text={duplicateSubmissionText}
            isChecked={allowDuplicateSubmission}
            on:changed={toggleMultipleSubmission}
          />
        </div>
      {/if}
      {#if current_tab == 2}
        {#if checklist.documents.length == 0}
          <div class="documents-container">
            <div class="documents-container-inner">
              <p class="center-content documents-title">Add a Template</p>
              <p class="documents-subtitle">
                To add a new document, please select from existing templates
                <span class="desktop-only">, or upload a new one.</span>
              </p>
              <ButtonGroups classes="flex-direction-column">
                <span
                  class="button"
                  on:click={() => {
                    showUploadModal = true;
                  }}
                >
                  <Button
                    color="secondary"
                    icon="file-contract"
                    text="Choose Existing"
                  />
                </span>
                <span
                  class="button desktop-only"
                  on:click={() => {
                    templateTipsPopUpStatus = JSON.parse(
                      localStorage.getItem(
                        "dontShowNewChecklisttemplateTipsPopUp"
                      )
                    );
                    if (templateTipsPopUpStatus) {
                      showNewTemplateModal = true;
                    } else {
                      templateTipsPopUp = true;
                    }
                  }}
                >
                  <Button
                    color="primary"
                    icon="cloud-upload-alt"
                    text="Upload New"
                  />
                </span>
              </ButtonGroups>
              <p class="center-content documents-subtitle">
                You can always add more documents later.
              </p>
            </div>
          </div>
        {:else}
          <div class="documents-preamble">
            <ButtonGroups>
              <span
                class="button"
                on:click={() => {
                  showUploadModal = true;
                }}
              >
                <Button
                  color="secondary"
                  icon="file-contract"
                  text="Choose Existing"
                />
              </span>
              <span
                class="button desktop-only"
                on:click={() => {
                  templateTipsPopUpStatus = JSON.parse(
                    localStorage.getItem(
                      "dontShowNewChecklisttemplateTipsPopUp"
                    )
                  );
                  if (templateTipsPopUpStatus) {
                    showNewTemplateModal = true;
                  } else {
                    templateTipsPopUp = true;
                  }
                }}
              >
                <Button
                  color="primary"
                  icon="cloud-upload-alt"
                  text="Upload New"
                />
              </span>
            </ButtonGroups>
          </div>
          <div class="documents">
            <ChecklistDocumentTable
              on:deleteTemplate={({ detail: { item } }) => {
                delTemplateDocConfirmation = true;
                docToBeRemoved = item;
              }}
              documents={checklist.documents.sort((a, b) =>
                a.name.localeCompare(b.name)
              )}
              recpt_assign_view={false}
            />
          </div>
        {/if}
      {/if}
      {#if current_tab == 3}
        {#if checklist.file_requests.length == 0 || checklist.file_requests.filter((x) => x.flags !== 4).length === 0}
          <div class="documents-container">
            <div class="documents-container-inner">
              <p class="center-content documents-title">
                Add request (file upload, data input, task)
              </p>
              <ButtonGroups classes="flex-direction-column">
                <span
                  on:click={() => {
                    showFillModal = true;
                  }}
                >
                  <Button text="Add Request" color="secondary" />
                </span>
              </ButtonGroups>
            </div>
          </div>
        {:else}
          <div class="filerequests-preamble">
            <p>Requests</p>
            <p style="display: flex; align-items: center;">
              <span
                on:click={() => {
                  showFillModal = true;
                }}
              >
                <Button text="Add Request" color="secondary" />
              </span>
            </p>
          </div>
          {#if new_request_type === "file"}
            <span
              style="margin-bottom: -1rem; display: flex; justify-content: flex-end;"
            >
              <span>
                <Switch
                  bind:checked={allowFileRequestisChecked}
                  text={`${ALLOWEXTRAFILESTOUPLOADTEXT}`}
                  action={switchAdditionalFiles}
                />
              </span>
            </span>
          {/if}

          <div class="documents">
            <ChecklistFileRequestsTable
              file_requests={checklist.file_requests}
              chcklistView={true}
              {switchActionExpirationRequest}
              draggable={true}
              on:deleteRequest={({ detail: { item } }) => {
                delTemplateDocConfirmation = true;
                freqID = item.id;
                freqName = item.name;
              }}
              on:handleEditRequest={({ detail: { id } }) => {
                const found = checklist.file_requests.find(
                  (req) => req.id === id
                );

                if (!found) {
                  showToast(
                    "File request id is not found!",
                    2000,
                    "error",
                    "MM"
                  );
                  return;
                }
                currentEditRequest = {
                  ...found,
                };
                showEditModal = true;
              }}
            />
          </div>
        {/if}
      {:else if current_tab == 4}
        {#if isFormEdit || isFormCreate}
          <div class="form-container">
            <div class="desktop-only">
              {#if !isPreview}
                <h1>Form Editor</h1>
              {:else}
                <h1>Form Preview</h1>
              {/if}
              <div class="tooltip" style="position: relative;">
                <div
                  style="position: absolute;
                  left: 202px;
                  top: -52px;
                  cursor: pointer;
                  font-size: 26px;
                  display: flex;
                  align-items: center;
            "
                  on:click={() => {
                    isPreview = !isPreview;
                  }}
                >
                  {#if isPreview}
                    <span
                      style="font-size: 14px;
                    margin-right: 6px;
                    width: 90px;">Hide preview</span
                    >
                    <FAIcon iconStyle="regular" icon="eye-slash" />
                  {:else}
                    <span
                      style="font-size: 14px;
                    margin-right: 6px;
                    width: 90px;">Show preview</span
                    >
                    <FAIcon iconStyle="regular" icon="eye" />
                  {/if}
                  <span class="tooltiptext">Preview</span>
                </div>
              </div>
            </div>

            <div class="mobile-only-form form-title">
              <span class="form-heading"
                >{!isPreview ? `Form Editor` : `Form Preview`}</span
              >
              <span
                on:click={() => {
                  isPreview = !isPreview;
                }}
                class="form-preview"
              >
                <span>{isPreview ? `Hide preview` : `Show preview`}</span>
                <FAIcon
                  iconStyle="regular"
                  icon={isPreview ? `eye-slash` : `eye`}
                />
              </span>
            </div>

            <div class="form-body">
              <div style="padding-top: 12px;">
                {#if !isPreview}
                  <Card isHeader={true}>
                    <FormTitleEdit formElement={$formStore.questions} />
                    <FormCommands hideRemove={true} />
                  </Card>
                {:else}
                  <FormTitleRenderer
                    title={$formStore.questions.title}
                    description={$formStore.questions.description}
                  />
                {/if}
              </div>
              {#if $formStore.questions.formFields !== undefined}
                {#each $formStore.questions.formFields as question, index}
                  <div style="padding-top: 12px;">
                    {#if !isPreview}
                      <Card
                        setSelected={() => {
                          currentIndex = index;
                        }}
                        isSelected={currentIndex == index ? true : false}
                      >
                        {#if question.type === "instruction"}
                          <Instruction instruction={question} />
                        {:else}
                          <Question
                            {question}
                            {allowSes}
                            {mergedLabels}
                            questionIndex={index}
                          />
                        {/if}
                        <FormCommands {question} {index} />
                      </Card>
                    {:else if question.type === "instruction"}
                      <Instruction instruction={question} mode="view" />
                    {:else}
                      <FormElementRenderer {question} readOnly={true} />
                    {/if}
                  </div>
                {/each}
              {/if}
              {#if isFormCreate}
                <div
                  style="display: flex;
            justify-content: center;
            height: 50px;
            align-items: flex-end;"
                >
                  <span
                    style="width: 50%;"
                    on:click={() => {
                      if (isFormValid()) {
                        if (isFormCreate) {
                          handleAddForm();
                          return;
                        }

                        handleUpdateForm();
                      }
                    }}
                  >
                    <Button color="secondary" text={"Create Form"} />
                  </span>
                </div>
              {/if}
            </div>
          </div>
        {:else if $formStore.forms.length !== 0}
          <div class="filerequests-preamble">
            <p>Forms</p>
            <div class="buttonContainer">
              <span
                on:click={() => {
                  showExistingFormButton = true;
                  showFormCreateModal = true;
                }}
              >
                <Button text="Create new form" color="secondary" />
              </span>
              <span
                on:click={() => {
                  showChooseExistingForm = true;
                  formStore.resetQuestions();
                }}
              >
                <Button text="Add existing form" color="primary" />
              </span>
            </div>
          </div>
          <div class="documents">
            <div class="tr th">
              <div class="td icon" />
              <div class="td name">Form Details</div>
              <!-- <div class="td type desktop">Description</div> -->
              <div class="td icon" />
            </div>
            {#each $formStore.forms as form, index}
              <div class="tr">
                <div class="td icon requests-documents-icon">
                  <div>
                    <FAIcon icon="rectangle-list" iconStyle="regular" />
                  </div>
                </div>
                <div class="td name request-name">
                  <div class="name-container">
                    <div class="name-text">
                      {form.title}
                    </div>
                    <div class="filetype-title">
                      {form.description}
                    </div>
                  </div>
                </div>
                <!-- <div class="td type file-requests">
                  {form.description}
                </div> -->
                <div class="td icon action content-right">
                  <span
                    on:click={() => {
                      handleEditForm(index);
                    }}
                    class="deleter"
                    style="margin-right: 0.5rem;"
                  >
                    <div>
                      <FAIcon iconStyle="regular" icon="edit" />
                    </div>
                  </span>
                  <span
                    on:click={() => {
                      formStore.removeForm(index);
                    }}
                    class="deleter"
                  >
                    <FAIcon iconStyle="regular" icon="times-circle" />
                  </span>
                </div>
              </div>
            {/each}
          </div>
        {:else if $formStore.forms.length === 0}
          <div class="formContainer">
            <div class="innerFormContainer">
              <div class="modal-buttons">
                <span
                  style="width: 50%;"
                  on:click={() => {
                    showFormCreateModal = true;
                    showExistingFormButton = false;
                  }}
                >
                  <Button color="secondary" text="Create new" />
                </span>
                <span
                  style="width: 50%; margin-left: 15px;"
                  on:click={() => (showChooseExistingForm = true)}
                >
                  <Button color="light" text="Add existing" />
                </span>
              </div>
            </div>
          </div>
        {:else}
          <div>
            Unhandled condition! isFormEdit: {isFormEdit}, isFormCreate: {isFormCreate}
          </div>
        {/if}
      {/if}
    </div>
  </section>
</div>

<div class="mobile-only">
  <BottomBar
    leftButtons={[
      { button: "Back", evt: "back", color: "white" },
      {
        button: "Next",
        disabled: checklistUtils.calculateNextState(
          checklist,
          current_tab,
          max_tab,
          showUploadModal,
          showFillModal
        ),
        evt: "next",
        color: current_tab == max_tab ? "secondary" : "primary",
      },
    ]}
    rightButtons={[
      {
        button: "Cancel",
        evt: "cancel",
        disabled: false,
        color: "danger",
      },
      {
        button: "Save & Finish Later",
        ignore: (newChecklist && current_tab === max_tab) || !newChecklist,
        disabled: checklistUtils.inValidChecklistData(checklist),
        evt: "draft",
        color: "white",
      },
      {
        button: current_tab == max_tab ? "Finish" : "Save & Next",
        disabled: checklistUtils.calculateFinishState(
          checklist,
          showFillModal,
          isEmptyFileRequest,
          new_file_request,
          showUploadModal,
          isFormEdit,
          isFormCreate,
          editID
        ),
        evt: "finish",
        ignore: newChecklist && current_tab != max_tab,
        color: current_tab == max_tab ? "primary" : "white",
      },
      {
        button: isFormCreate ? "Create form" : "Save form",
        ignore: !isFormEdit,
        color: "secondary",
        evt: "saveForm",
      },
      {
        button: "Finish",
        disabled: checklistUtils.calculateSteadyFinishState(
          checklist,
          showFillModal,
          showUploadModal,
          isEmptyFileRequest,
          new_file_request
        ),
        evt: "steadyFinish",
        ignore: current_tab == max_tab,
        color: "white",
      },
    ]}
    on:draft={saveDraft}
    on:back={() => handleBackButton()}
    on:cancel={() => handleCancelButton()}
    on:next={() => handleNextButton()}
    on:finish={() => handleFinishButton()}
    on:steadyFinish={() => handleFinishButton(true)}
    on:saveForm={() => handleSaveForm()}
  />
</div>
<div class="desktop-only">
  <BottomBar
    leftButtons={[
      { button: "Cancel", evt: "cancel", disabled: false, color: "gray" },
      { button: "Back", evt: "back", color: "white" },
    ]}
    rightButtons={[
      {
        button: "Save & Finish Later",
        ignore:
          (newChecklist && current_tab === max_tab) ||
          !newChecklist ||
          isDirectSend,
        disabled: checklistUtils.inValidChecklistData(checklist),
        evt: "draft",
        color: "white",
      },
      {
        button: isFormCreate ? "Create form" : "Save form",
        ignore: !isFormEdit && !isFormCreate,
        color: "secondary",
        evt: "saveForm",
      },
      {
        button: "Next",
        disabled: checklistUtils.calculateNextState(
          checklist,
          current_tab,
          max_tab,
          showUploadModal,
          showFillModal
        ),
        evt: "next",
        color: current_tab == max_tab ? "secondary" : "primary",
      },
      {
        button:
          current_tab == max_tab
            ? isDirectSend
              ? "Send"
              : "Finish"
            : "Save & Next",
        disabled: checklistUtils.calculateFinishState(
          checklist,
          showFillModal,
          isEmptyFileRequest,
          new_file_request,
          showUploadModal,
          isFormEdit,
          isFormCreate,
          editID
        ),
        evt: "finish",
        ignore: (newChecklist && current_tab != max_tab) || isFormCreate,
        color: current_tab == max_tab ? "primary" : "white",
      },
      {
        button: isDirectSend ? "Send" : "Finish",
        disabled: checklistUtils.calculateSteadyFinishState(
          checklist,
          showFillModal,
          showUploadModal,
          isEmptyFileRequest,
          new_file_request
        ),
        evt: "steadyFinish",
        ignore: current_tab == max_tab,
        color: "white",
      },
    ]}
    on:draft={saveDraft}
    on:back={() => handleBackButton()}
    on:cancel={() => handleCancelButton()}
    on:next={() => handleNextButton()}
    on:finish={() => handleFinishButton()}
    on:steadyFinish={() => handleFinishButton(true)}
    on:saveForm={() => handleSaveForm()}
  />
</div>

{#if templateTipsPopUp}
  {#if templateTipsPopUpStatus !== true}
    <Modal
      on:close={() => {
        templateTipsPopUp = false;
        showNewTemplateModal = true;
        templateTipsPopUpPage = 1;

        if (templateTipsPopUpCheckbox) {
          localStorage.setItem("dontShowNewChecklisttemplateTipsPopUp", true);
        } else {
          localStorage.setItem("dontShowNewChecklisttemplateTipsPopUp", false);
        }
      }}
    >
      <p slot="header">User Guide</p>

      <div class="progress-tab">
        <ProgressTab
          elements={[
            "Standard Information",
            "Personalized Information",
            "Client Fills",
            "Fill After",
          ]}
          current={templateTipsPopUpPage}
        />
        <br />
      </div>

      {#if templateTipsPopUpPage == 0}
        <p class="tipsPopHeader">Standard Information</p>

        <div class="modal-subheader">
          Add any standard information that never changes, like your business
          info, to the document BEFORE loading it into the system.
        </div>
      {/if}

      {#if templateTipsPopUpPage == 1}
        <p class="tipsPopHeader">Personalized Information</p>

        <div class="modal-subheader">
          You`ll be able to set fields to be pre-filled in the system before
          sending to a specific person, like filling in details of a contract or
          offer letter. We recommend leaving these as blanks in the template you
          upload.
        </div>
      {/if}

      {#if templateTipsPopUpPage == 2}
        <p class="tipsPopHeader">Client Fills</p>

        <div class="modal-subheader">
          A “client” is the other party who will be filling and signing the form
          or document you send. A “client” may be an employee, vendor,
          contractor, etc.
        </div>
      {/if}

      {#if templateTipsPopUpPage == 3}
        <p class="tipsPopHeader">Fill After</p>

        <div class="modal-subheader">
          These are fields you’ll be prompted to fill and sign AFTER the client/
          other party has completed their parts.
        </div>
      {/if}

      <br />
      <label
        style="display: flex; justify-content: flex-start; align-items: center; font-family: sans-serif;
    font-size: 14px;"
      >
        <input
          type="checkbox"
          on:click={templateTipsPopUpHandleCheckbox}
          bind:checked={templateTipsPopUpCheckbox}
        />
        <span class="pl-2">Don't ask me this again</span>
      </label>
      <br />

      <div class="modal-buttons">
        <span
          on:click={() => {
            templateTipsPopUpPage = templateTipsPopUpPage - 1;
          }}
        >
          <Button
            color="white"
            text="Previous Page"
            disabled={templateTipsPopUpPage == 0}
          />
        </span>

        {#if templateTipsPopUpPage != 3}
          <span
            on:click={() => {
              templateTipsPopUpPage = templateTipsPopUpPage + 1;
            }}
          >
            <Button
              color="primary"
              text="Next Page"
              disabled={templateTipsPopUpPage == 3}
            />
          </span>
        {:else}
          <span
            on:click={() => {
              templateTipsPopUp = false;
              showNewTemplateModal = true;
              templateTipsPopUpPage = 1;
            }}
          >
            <Button color="primary" text="Proceed to Upload" />
          </span>
        {/if}
      </div>
    </Modal>
  {/if}
{/if}

{#if showChooseExistingForm}
  <ChooseExistingFormModal
    on:close={() => {
      showChooseExistingForm = false;
    }}
  />
{/if}

{#if showSelectRecipientModal}
  <ChooseRecipientModal
    on:selectionMade={processAssigneSelection}
    on:close={() => {
      showSelectRecipientModal = false;
      window.location.hash = "#checklists";
    }}
  />
{/if}

{#if showChooseSesTemplateModal}
  <ChooseTemplateModal
    on:selectionMade={processSesTargetSelection}
    on:close={() => (showChooseSesTemplateModal = false)}
    selectOne={false}
    title={"Choose Target Template"}
    customButtonText={true}
    buttonText={"Choose"}
  />
{/if}

{#if showUploadModal}
  <ChooseTemplateModal
    on:selectionMade={processSelection}
    on:close={() => (showUploadModal = false)}
    default_selection_list={current_selection_list}
  />
{/if}

{#if showNewTemplateModal}
  <UploadFileModal
    requireIACwarning={true}
    multiple={false}
    specializedFor="newTemplate"
    allowNonIACFileTypes={requestorTemplateNonIACExtensions}
    on:done={processNewTemplate}
    on:close={() => {
      showNewTemplateModal = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if newChecklistCreatedConfirmation}
  <ConfirmationDialog
    title="Confirmation"
    question="Checklist successfully created. What would you like to do next?"
    yesText="Send checklist"
    noText="I'm done"
    yesColor="primary"
    noColor="white"
    tooltipHideMessage="Not available if checklist contains custom documents."
    noLeftAlign={true}
    actionsColor="white"
    actions={enableIntakeOption ? actions : null}
    on:close={() => {
      window.location.hash = "#checklists";
    }}
    on:yes={() => {
      newChecklistCreatedConfirmation = false;
      showSelectRecipientModal = true;
    }}
    on:shareableLink={() => {
      newChecklistCreatedConfirmation = false;
      getSecureIntakeLink(newChecklistId);
    }}
  />
{/if}

{#if leaveChecklistWithoutSave}
  <ConfirmationDialog
    title="Warning!"
    question={askLeaveWithoutSave}
    yesText="Yes, I do"
    noText="No, Continue"
    yesColor="secondary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => {
      leaveChecklistWithoutSave = false;
    }}
    on:yes={() => (window.location.hash = "#checklists")}
  />
{/if}
{#if delTemplateDocConfirmation}
  <ConfirmationDialog
    title="Confirmation"
    question="Are you sure you want to remove this item from the checklist?"
    yesText="Yes, Remove it"
    noText="No, Keep it"
    yesColor="secondary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => {
      delTemplateDocConfirmation = false;
    }}
    on:yes={docToBeRemoved != null
      ? () => {
          deleteTemplate(docToBeRemoved);
          showToast(
            docToBeRemoved.name + " removed From Checklist",
            2000,
            "white",
            "MM"
          );
          docToBeRemoved = null;
          delTemplateDocConfirmation = false;
        }
      : () => {
          deleteFileRequest(freqID);
          showToast(freqName + " removed From Checklist", 2000, "white", "MM");
          freqID = null;
          freqName = null;
          delTemplateDocConfirmation = false;
        }}
  />
{/if}
{#if showSubmitWithoutAnyRequestConfirmation}
  <ConfirmationDialog
    title="Confirmation"
    question="You have not added any templates or requests or forms to this checklist. Are you sure you want to close?"
    yesText="Yes, I do"
    noText="Go Back"
    yesColor="secondary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => {
      showSubmitWithoutAnyRequestConfirmation = false;
      disableMultipleClick = false;
    }}
    on:yes={() => {
      submitChecklist(true, true);
      showSubmitWithoutAnyRequestConfirmation = false;
    }}
  />
{/if}
{#if abandonChanges}
  <ConfirmationDialog
    title="Cancellation"
    question={cancelChangeMessage}
    yesText="Exit setup/ discard changes"
    noText="Stay/ continue editing"
    yesColor="secondary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => (abandonChanges = false)}
    on:yes={() => {
      window.location.hash = isDirectSend ? "#directsend" : "#checklists";
      formStore.reset();
    }}
  />
{/if}

{#if showNoSaveChecklistWarning}
  <ConfirmationDialog
    title="Warning"
    question="Checklist will be discarded."
    yesText="Discard"
    noText="Cancel"
    yesColor="danger"
    noColor="white"
    noLeftAlign={true}
    on:close={() => (showNoSaveChecklistWarning = false)}
    on:yes={() => {
      onBackArrow("#checklists");
    }}
  />
{/if}

{#if showSaveAsDraftConfirmation}
  <ConfirmationDialog
    title="Confirmation"
    question="Checklist will be Saved as draft for future use."
    yesText="Yes, Save as draft"
    noText="Cancel/ stay"
    yesColor="primary"
    noColor="white"
    hideText="Discard and close"
    hideColor="white"
    noLeftAlign={true}
    on:close={() => (showSaveAsDraftConfirmation = false)}
    on:yes={async () => {
      await saveDraft();
      onBackArrow("#checklists");
    }}
    on:hide={() => {
      onBackArrow("#checklists");
    }}
  />
{/if}

{#if showTaskDetailsModal}
  <Modal
    on:close={toggleTaskDetailsModal}
    maxWidth={isMobile() ? "90%" : "50%"}
  >
    <div slot="header">
      <h4 style="margin: 1rem 0;line-height: 17px;">
        Task Details: {editID ? editName : new_file_request}
      </h4>
    </div>
    <div class="details-modal">
      <Editor {setEditorText} defaultValue={editDetails} />
      <input
        type="checkbox"
        id="confimation"
        name="confimation"
        value="confimation"
      />
      <label for="confimation"> Request a confirmation file</label><br />
      <!-- <textarea bind:value={new_task_details} class="textarea" /> -->
      <div class="buttons">
        <span on:click={toggleTaskDetailsModal}>
          <Button color="gray" text="Cancel" />
        </span>
        {#if editID}
          <span on:click={updateFileRequests}>
            <Button color="primary" text="Update" />
          </span>
        {:else}
          <span on:click={appendFileRequest}>
            <Button color="primary" text="Add Task" />
          </span>
        {/if}
      </div>
    </div>
  </Modal>
{/if}

{#if showFormCreateModal}
  <Modal
    on:close={() => {
      showFormCreateModal = false;
      formTitle = "";
      formDescription = "";
    }}
  >
    <p slot="header">Create Form</p>
    <div class="modal-subheader">
      Easily create and share forms and surveys.
    </div>
    <div class="modal-field">
      <div class="modal-field-inner">
        <div class="name">Title <span class="required">*</span></div>
        <TextField
          bind:value={formTitle}
          iconStyle="regular"
          width="70%"
          text={""}
          maxlength={"40"}
        />
      </div>
      <div class="modal-field-inner">
        <div class="name">Description</div>
        <TextField
          bind:value={formDescription}
          iconStyle="regular"
          width="70%"
          text={""}
          maxlength={"80"}
        />
      </div>
      <div class="modal-field-inner flex-col items-start">
        <div class="name">
          <input
            type="checkbox"
            id="repeat-entries"
            bind:checked={has_repeat_entries}
          />
          <label class="cursor-pointer" for="repeat-entries">
            Set form for repeat entries of standard questions, i.e. list the
            name and age of every driver
          </label>
        </div>
        {#if has_repeat_entries}
          <div class="name pt-4">
            <input
              type="checkbox"
              id="repeat-vertical"
              bind:checked={has_repeat_vertical}
            />
            <label class="cursor-pointer" for="repeat-vertical">
              Vertical Entry
            </label>
          </div>
        {/if}
      </div>
    </div>
    <div class="modal-field-inner">
      <div class="name">Repeat Label</div>
      <TextField
        bind:value={form_repeat_label}
        iconStyle="regular"
        width="70%"
        text={""}
        maxlength={"80"}
      />
    </div>
    <div class="modal-buttons">
      <span
        style="width: 100%;"
        on:click={() => {
          showFormCreateModal = false;
          handleCreateForm();
        }}
      >
        <Button
          disabled={formTitle.trim() === ""}
          color="secondary"
          text="Create form"
        />
      </span>
      {#if showExistingFormButton}
        <span
          style="width: 45%; margin-left: 15px;"
          on:click={() => {
            showChooseExistingForm = true;
            showFormCreateModal = false;
          }}
        >
          <Button color="light" text="Add existing" />
        </span>
      {/if}
    </div>
  </Modal>
{/if}

{#if showFillModal}
  <NewModal
    on:close={() => {
      showFillModal = false;
      new_file_request = "";
      new_file_request_description = "";
      link_button_name = "";
      link_button_url = "";
    }}
  >
    <CheckListForm
      {new_request_type}
      {new_file_request}
      {new_file_request_description}
      {link_button_name}
      {link_button_url}
      {track_document_expiration}
      allow_file_requestis_checked={allowFileRequestisChecked}
      modalView={true}
      on:add={(ev) => handleAddRequest(ev)}
      on:cancel={() => {
        showFillModal = false;
      }}
    />
  </NewModal>
{/if}

{#if showIntakeModal}
  <Modal
    maxWidth="52rem"
    on:close={() => {
      showIntakeModal = false;
      newChecklistCreatedConfirmation = true;
    }}
  >
    <div slot="header">QR code/ shareable link created</div>

    <div
      style="display: flex; flex-direction: column; line-height:16px"
      class="intake-text"
    >
      <span style="font-weight: 900;">To share:</span>
      <br />
      <span>
        <span style="font-weight: 900;">QR code : </span>Download by
        right-clicking the QR code on desktop, or long-pressing on mobile.
        Display the QR in a scannable location.
      </span>
      <br />
      <span>
        <span style="font-weight: 900;">Link : </span>Copy to your clipboard and
        then post on your website, social media, in an email (no tracking), etc.
      </span>
      <br />
      <span>
        Anyone who scans the QR code or clicks the link will be able to submit.
        You will be notified of any submissions.
      </span>
    </div>

    <br />

    <div class="intake-qr-code">
      <QrCode value={newIntakeLink} />
    </div>

    <div class="intake-link">
      <p>{newIntakeLink}</p>
    </div>
    <div
      class="intake-link-copy"
      on:click={async () => {
        linkTextCopied = true;
        copyButtonText = "Copied";
        copyButtonIcon = "check-circle";
        await navigator.clipboard.writeText(newIntakeLink);
        showToast(`Link copied to clipboard.`, 1000, "white", "MM");
      }}
      data-text-copy="Click to Copy"
      on:mouseleave={() => {
        linkTextCopied = false;
      }}
    >
      <FAIcon icon="copy" />&nbsp;&nbsp;Copy link
    </div>
  </Modal>
{/if}

{#if showEditModal}
  <NewModal
    on:close={() => {
      showEditModal = false;
    }}
  >
    <CheckListForm
      {currentEditRequest}
      isEditMode={true}
      modalView={true}
      on:handleEditRequest={(e) => {
        handleEditRequest(e.detail.item);
      }}
      on:cancel={() => {
        showEditModal = false;
      }}
    />
  </NewModal>
{/if}

<style>
  /* Intake CSS */
  :root {
    --color-required: rgb(221, 38, 38);
  }

  .buttonContainer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 350px;
  }

  .formContainer {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 120px;
  }

  .innerFormContainer {
    width: 750px;
  }

  .documents {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    justify-content: left;
    align-items: center;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #606972;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .td.name {
    flex: 0.67 1 0;
    flex-grow: 2;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
  }

  .td.icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    max-width: 250px;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: center;
    margin-left: 15px;
  }

  .action {
    display: flex;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: flex-end;
  }

  .deleter {
    cursor: pointer;
  }

  .deleter:hover {
    color: hsl(0, 95%, 77%);
  }

  .intake-text {
    padding-top: 1rem;
  }

  .intake-link {
    padding-top: 2rem;
    display: flex;
    flex-flow: row nowrap;

    justify-content: center;
  }

  .intake-link-copy {
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: copy;
    width: 30;
    margin: 0 auto;
    padding: 5px;
    position: relative;
    border-radius: 5px;
  }

  .intake-link-copy:hover::before {
    content: attr(data-text-copy);
    position: absolute;
    background-color: red;
    top: -126%;
    width: 80px;
    text-align: center;
    background: white;
    box-shadow: 0px 3px 20px rgba(46, 56, 77, 0.22);
    padding: 3px;
    font-size: 10px;
  }

  .intake-link-copy:focus,
  .intake-link-copy:hover {
    box-shadow: 0px 3px 20px 7px rgba(46, 56, 77, 0.22);
  }

  .intake-qr-code {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .required {
    color: rgb(221, 38, 38);
  }

  .required {
    color: var(--color-required);
  }

  .details-modal > .buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    padding-top: 1rem;
  }

  .button {
    flex: 1;
  }

  .pl-2 {
    padding-left: 0.5rem;
  }

  .mobile-only-form {
    display: none !important;
  }
  .form-title {
    display: flex;
    width: 100%;
    justify-content: space-around;
  }
  .form-body {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    width: 65%;
  }
  .form-heading {
    justify-content: center;
    font-size: 1.5rem;
  }

  .errormessage {
    display: inline-block;
    color: #cc0033;
    font-size: 12px;
    font-weight: bold;
    line-height: 15px;
    margin: 5px 0 0;
  }

  .required {
    color: rgb(221, 38, 38);
  }

  .container {
    padding-left: 2rem;
    padding-right: 2rem;
    margin-bottom: 6rem;
  }

  section.content {
    padding-top: 2rem;
  }

  .checklist-new__question-mark {
    cursor: pointer;
  }

  .tooltip {
    position: relative;
    display: inline;
  }
  .tooltip:hover {
    content: attr(title);
  }

  .content-width {
    width: 40%;
  }

  .form-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
  }

  .tooltip {
    position: relative;
  }
  .tooltip .tooltiptext {
    visibility: hidden;
    width: max-content;
    background-color: black;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 6px 6px;
    position: absolute;
    z-index: 1;
    bottom: 14%;
    left: 120%;
    right: 0%;
    font-size: 10px;
  }

  .tooltip:hover .tooltiptext {
    visibility: visible;
  }

  .content-right {
    justify-content: end !important;
  }

  .main-content {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 2rem;
  }

  .heading {
    font-style: normal;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #4a5158;
  }

  .field {
    padding-top: 0.5rem;
    width: 50%;
  }

  .field > .field-title {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 16px;
    color: #76808b;
  }

  /* Templates if there is more Tab */
  .documents-container {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 40vh;
  }
  .documents-container-inner {
    display: flex;
    flex-direction: column;
  }
  .center-content {
    display: flex;
    justify-content: center;
  }
  .documents-title {
    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    color: #4a5158;
  }
  .documents-subtitle {
    font-size: 16px;
    line-height: 24px;
    text-align: center;
    letter-spacing: 0.5px;
    color: #606972;
  }

  .documents-preamble {
    display: flex;
    justify-content: center;
    align-items: center;
    padding-bottom: 16px;
  }

  .documents {
    padding-top: 2rem;

    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    justify-content: left;
    align-items: center;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #606972;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .td.name {
    flex: 2 1 0;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
  }

  .td.icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    width: 48px;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: center;
    margin-right: 10px;
  }
  .action {
    display: flex;
    gap: 0.5rem;
  }

  .action span {
    cursor: pointer;
  }
  .action span:hover {
    color: hsl(0, 95%, 77%);
  }

  .name-container {
    width: 70%;
    display: flex;
    flex-flow: column nowrap;
    justify-content: space-around;
  }

  .name-container > *:nth-child(1) {
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #2a2f34;
  }

  .name-container > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #7e858e;
  }

  .name-container > *:nth-child(3) {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #7e858e;
  }

  .filerequests-preamble {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
  }

  .filerequests-preamble > p:nth-child(1) {
    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    color: #4a5158;
  }

  .mobile-only {
    display: none;
  }

  .modal-field {
    padding-bottom: 2rem;
  }

  .modal-field-inner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding-bottom: 1rem;
  }

  .items-start {
    align-items: flex-start;
  }

  .flex-col {
    flex-direction: column;
  }

  .cursor-pointer {
    cursor: pointer;
  }

  .pt-4 {
    padding-top: 16px;
  }

  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
  }

  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
  }

  .tipsPopHeader {
    display: none;
    justify-content: flex-start;
    font-size: large;
    font-weight: bolder;
    color: #2a2f34;
  }

  .modal-subheader {
    color: #2a2f34;
    height: 90px;
  }

  .progress-tab {
    display: flex;
    flex-flow: column nowrap;
    justify-content: center;
  }

  @media only screen and (max-width: 1024px) {
    .field {
      width: 70%;
    }
  }
  @media only screen and (max-width: 767px) {
    .field {
      width: 100%;
    }

    .content-width {
      width: 100%;
    }
    .container {
      padding-left: 0.5rem;
      padding-right: 0.5rem;
    }
    .main-content {
      padding: 1rem;
    }
    section.content {
      padding-top: 1rem;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }

    .form-body {
      width: 100%;
    }

    .mobile-only-form {
      display: flex !important;
    }
  }

  @media (max-width: 445px) {
    .button {
      width: 100%;
    }
  }
</style>
