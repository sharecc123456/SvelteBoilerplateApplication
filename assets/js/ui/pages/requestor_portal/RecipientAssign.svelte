<script>
  import NavBar from "../../components/NavBar.svelte";
  import Panel from "../../components/Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import ProgressTab from "../../components/ProgressTab.svelte";
  import TextField from "../../components/TextField.svelte";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import ChecklistDocumentTable from "../../tables/ChecklistDocumentTable.svelte";
  import ChecklistFileRequestsTable from "../../tables/ChecklistFileRequestsTable.svelte";
  import ChooseTemplateModal from "../../modals/ChooseTemplateModal.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import assignedChecklistInfo from "../../../localStorageStore";
  import Modal from "Components/Modal.svelte";
  import AddRequestModal from "../../modals/Modal.svelte";
  import { getValidUrlLink, isUrl } from "../../../helpers/util";
  import { onMount } from "svelte";
  import { createForm } from "BoilerplateAPI/Form";
  import FormTitleEdit from "../../components/Form/FormTitleEdit.svelte";
  import { formStore } from "../../../stores/formStore";
  import FormCommands from "../../components/Form/FormCommands.svelte";
  import Question from "../../components/Form/Question.svelte";
  import FormElementRenderer from "../../components/Form/FormElementRenderer.svelte";
  import FormTitleRenderer from "../../components/Form/FormTitleRenderer.svelte";
  import { getCompanies } from "BoilerplateAPI/Recipient";
  import {
    sessionStorageHas,
    sessionStorageGet,
    sessionStorageSave,
  } from "../../../helpers/sessionStorageHelper";
  import {
    addDates,
    getDaysDiff,
    getTomorrowDate,
  } from "../../../helpers/dateUtils";
  import { getRSDsIACPrefilled } from "BoilerplateAPI/IAC";
  import Flatpickr from "svelte-flatpickr";
  import "flatpickr/dist/flatpickr.css";
  import "flatpickr/dist/themes/light.css";
  import CheckListForm from "../../components/CheckListForm.svelte";
  import { updateContentsAsync } from "../../../api/Form";
  import Switch from "../../components/Switch.svelte";

  import {
    resetCustomization,
    customizeDocument,
    assignContents,
    commitRSDocuments,
    deleteDraftContents,
  } from "BoilerplateAPI/Assignment";

  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import {
    capitalizeFirstLetter,
    isNullOrUndefined,
  } from "../../../helpers/util";
  import { getChecklist } from "../../../api/Checklist";
  import Checkbox from "../../components/Checkbox.svelte";
  import Card from "../../components/Card.svelte";
  import ChecklistFormsTable from "../../tables/ChecklistFormsTable.svelte";
  import EditFormModal from "../../modals/EditFormModal.svelte";
  import { DUEDATESTEP, MINDUEDATE } from "../../../constants";
  import { ALLOWEXTRAFILESTOUPLOADTEXT } from "../../../helpers/constants";
  import ChooseExistingFormModal from "../../modals/ChooseExistingFormModal.svelte";

  export let checklistId;
  export let recipientId;
  let allowResetChecklistState = true;
  let allowFileRequestisChecked = false;
  let currentRequestorCompany = "";

  const ADDTIONALFILEUPLOADTYPE = "allow_extra_files";
  let isRecipientAllowedExtraFileUploads = false;
  let dueDateHumanized = "";

  let append_note = "";
  let showChooseExistingForm = false;

  let prefilled = [];
  let isTemplateSwapped = false;
  let swappedTemplateID;
  let checkStatusConfirmation = JSON.parse(
    localStorage.getItem("dontShowConfirmationSendChecklist")
  );
  let checklistGuideDialogStatus = JSON.parse(
    localStorage.getItem("dontshowChecklistGuideDialog")
  );
  let showChecklistGuideDialog = false;
  let guidePoints = [
    "Swap in recipient-specific PDF documents and set them up to be filled/ signed online (i.e. a contract drafted in Word then printed to a PDF and uploaded)",
    "Pre-fill recipient specific documents (i.e. filling in the blanks on an offer letter with the date, employee name, start date, etc)",
    "Add or remove templates and requests",
  ];
  let ProgressStep = 1;
  let sendChecklistClicked = false;
  let showFillModal = false;

  const addForm = async () => {
    // replace formForRecipientAssign with actual form data
    // checklist_id is 0 here because this form only belongs to the contents
    const formData = { checklist_id: checklistId, ...$formStore.questions };

    const data = await createForm(formData);
    contents.forms.push(data);
    contents = contents;
    try {
      await updateContentsAsync(contents);
      allowResetChecklistState = true;
    } catch (error) {
      alert(error);
      console.error(error);
    }
  };

  let formTitle = "";
  let formDescription = "";
  let showFormCreateModal = false;
  let showFormEdit = false;
  let isFormPreview = false;
  let currentIndex;

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
      let isInvalidFormElements = $formStore.questions.formFields.filter(
        (e) => {
          return e.title == "";
        }
      );

      if (isInvalidFormElements.length) {
        showToast("Question and label is required!", 2500, "error", "MM");
        return false;
      }
      return true;
    }
  };

  const switchAdditionalFiles = (checked) => {
    allowFileRequestisChecked = checked;
  };

  let due_date = 1;
  let due_date_group = 1;
  let now = new Date();
  let contents = {};
  const DUEDATENOTSET = "Not Set";

  // set now as next day
  now.setDate(now.getDate() + 1);
  const tomorrow = getTomorrowDate();
  let selectedDate = tomorrow;

  const flatpickrOptions = {
    element: "#date-picker",
    minDate: selectedDate,
    defaultDate: selectedDate,
  };

  let contentsPromise = loadContents(recipientId, checklistId);
  let current_tab = 0,
    min_tab = 0,
    max_tab = 1;

  onMount(async () => {
    if (sessionStorageHas("boilerplate_company")) {
      currentRequestorCompany = sessionStorageGet("boilerplate_company");
    } else {
      await getCompanies().then((x) => {
        currentRequestorCompany = x.current_requestor_company_name;
        sessionStorageSave(
          "boilerplate_company",
          x.current_requestor_company_name
        );
      });
    }
    showChecklistGuideDialog = true;
  });

  async function appendFileRequest() {
    let description = new_file_request_description;
    /* Ask the API to assign this an ID */
    let request = await fetch("/n/api/v1/documentrequest", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name: new_file_request.trim(),
        type: new_request_type,
        description,
        link: {
          name: link_button_name.trim(),
          url: link_button_url,
        },
        file_retention_period: fileRetentionPeriod,
        allow_expiration_tracking: track_document_expiration,
        is_confirmation_required,
      }),
    });

    if (request.ok) {
      let new_request = await request.json();

      contents.requests.push({
        name: new_request.name.trim(),
        new: false,
        description: description,
        link: {
          name: link_button_name.trim(),
          url: link_button_url,
        },
        id: new_request.id,
        type: new_request.type,
        flags: new_request.flags,
      });

      // Needed to alert Svelte that the checklist object was updated.
      contents = contents;

      new_file_request = "";
      new_file_request_description = "";
      link_button_name = "";
      link_button_url = "";

      try {
        await updateContentsAsync(contents);
        allowResetChecklistState = true;
      } catch (error) {
        alert(error);
        console.error(error);
      }
      isRecipientAllowedExtraFileUploads = true;
    } else {
      alert("Failed to request an ID for this request");
    }
  }

  async function deleteForm(event) {
    let id = event.detail.formId;

    console.log(contents);
    contents.forms = contents.forms.filter((form) => {
      return form.id != id;
    });

    contents = contents;

    try {
      await updateContentsAsync(contents);
      allowResetChecklistState = true;
    } catch (error) {
      alert(error);
      console.error(error);
    }
  }

  async function deleteRequest(event) {
    let id = event.detail.requestId;

    contents.requests = contents.requests.filter((e) => {
      return e.id != id;
    });
    contents = contents;

    try {
      await updateContentsAsync(contents);
      allowResetChecklistState = true;
    } catch (error) {
      alert(error);
      console.error(error);
    }
    isRecipientAllowedExtraFileUploads = false;
  }

  async function deleteTemplate(event) {
    let id = event.detail.templateId;

    contents.documents = contents.documents.filter((e) => {
      return e.id != id;
    });
    current_selection_list = contents.documents.map((x) => x.id);
    contents = contents;

    try {
      await updateContentsAsync(contents);
      allowResetChecklistState = true;
    } catch (error) {
      alert(error);
      console.error(error);
    }
  }

  async function getContents(recipientId, checklistId) {
    let request = await fetch(
      `/n/api/v1/contents/${recipientId}/${checklistId}`
    );
    if (request.ok) {
      // If the request was OK, then a contents was found.
      let assignments = await request.json();
      console.log("Found existing contents");
      due_date = assignments.due_days || 1;
      return assignments;
    } else if (request.status == 404) {
      // No existing valid Contents was found, ask the API to create one for us.
      let request = await fetch("/n/api/v1/contents", {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          recipientId: recipientId,
          packageId: checklistId,
        }),
      });

      if (request.ok) {
        allowResetChecklistState = false;
        let new_contents = await request.json();
        console.log("Made new contents");
        due_date = new_contents.due_days;
        return new_contents;
      } else {
        alert("Failed to create a new Contents object for this assignment");
      }
    } else {
      alert("A fatal, unexpected error occured while fetching Contents");
    }
  }

  /* Callback from ChooseTemplateModel */
  async function processSelection(evt) {
    let template_list = evt.detail.templates;

    contents.documents = contents.documents.concat(template_list);
    current_selection_list = contents.documents.map((x) => x.id);
    contents = contents;

    try {
      await updateContentsAsync(contents);
      allowResetChecklistState = true;
    } catch (error) {
      alert(error);
      console.error(error);
    }
  }

  async function doSubmit(contents, append_note) {
    /* Assign this contents to the recipient */
    let reply = await assignContents(contents, append_note);
    if (reply.ok) {
      showToast(`Success! Checklist sent.`, 3000, "white", "MM");
      setTimeout(() => {
        window.location.hash = "#dashboard";
        window.location.reload();
      }, 3000);
    } else {
      alert("An error occured while assigning this package");
    }
  }

  /* Check if all the RSDs in the contents are customized for the recipient */
  function areRsdsCustomized(contents) {
    if (contents.documents.length == 0) {
      /* No documents */
      return true;
    }

    let rsds = contents.documents.filter((x) => x.is_rspec && x.type === 0);
    if (rsds.length == 0) {
      /* No RSDs */
      return true;
    }

    let all_done = rsds
      .map(
        (x) =>
          x.id in contents.customizations ||
          (prefilled != null && prefilled.includes(x.id))
      )
      .reduce((a, x) => a && x, true);

    return all_done;
  }

  const determineConfirmationDialogBox = () => {
    allowChecklistMultipleRequest === true
      ? (showAddUniqueIdentifierDialog = true)
      : (newChecklistCustomMessage = true);
  };

  /* Callback from Send Checklist button */
  async function handleSubmit(evt) {
    sendChecklistClicked = true;
    ProgressStep = ProgressStep + 1;
    let _checklist = await getChecklist(checklistId);
    allowChecklistMultipleRequest = _checklist.allow_multiple_requests;

    /* Check if all RSD were customized */
    if (areRsdsCustomized(contents)) {
      /* ready to send the checklist. ask to confirm */
      determineConfirmationDialogBox();
    } else {
      /* Ask the user to verify that no customization is required */
      showRSDCustomizeConfirmationDialog = true;
    }
  }

  async function onSubmitChecklist(con, append_note) {
    /* Check if all RSD were customized */
    if (areRsdsCustomized(con)) {
      doSubmit(con, append_note);
    } else {
      commitRSDs(con, append_note);
    }
  }

  async function commitRSDs(contents, append_note) {
    let arr = [];

    for (let doc of contents.documents) {
      if (doc.is_rspec && !(doc.id in contents.customizations)) {
        arr.push(doc);
      }
    }

    let reply = await commitRSDocuments(contents, arr);
    if (reply.ok) {
      doSubmit(contents, append_note);
    } else {
      alert("failed to commit non customized placeholders");
    }
  }

  async function loadContents(recipientId, checklistId) {
    return getContents(recipientId, checklistId).then((c) => {
      contents = c;
      dueDateHumanized =
        c.enforce_due_date && isNullOrUndefined(c.due_days)
          ? DUEDATENOTSET
          : getHumanizedDate(new Date(), c.due_days);
      due_date_group = isNullOrUndefined(c.due_days) ? 4 : 1;
      getRSDsIACPrefilled(c.id, recipientId)
        .then((x) => x.json())
        .then((x) => {
          console.log(x);
          prefilled = x;
        });
      isRecipientAllowedExtraFileUploads = allowFileRequestisChecked =
        contents.allowed_additional_files_uploads;
      current_selection_list = contents.documents.map((x) => x.id);

      // due date personaization default to true
      c.enforce_due_date = true;
      return Promise.resolve(c);
    });
  }

  async function processCustomization(evt) {
    let detail = evt.detail;

    let reply = await customizeDocument(
      contents,
      currentlyCustomized,
      detail.file
    );
    if (reply.ok) {
      /* reload the contents */
      contentsPromise = loadContents(recipientId, checklistId);
      isTemplateSwapped = true;
    } else {
      alert("Failed to customize this document");
    }

    showCustomizeModal = false;
  }

  function beginCustomization(evt) {
    let templateId = evt.detail.templateId;
    swappedTemplateID = templateId;
    let template = contents.documents.find((x) => x.id == templateId);

    if (template == undefined) {
      alert("Cannot find the requested document");
    } else {
      // the template currently being customized ie. prefilled or swapped-IN
      currentlyCustomized = template;
      showCustomizeModal = true;
    }
  }

  async function revertCustomization(contents, evt) {
    let templateId = evt.detail.templateId;
    let template = contents.documents.find((x) => x.id == templateId);

    if (template == undefined) {
      alert("Cannot find the requested document");
    } else {
      let reply = await resetCustomization(contents.id, template.id);
      if (reply.ok) {
        contentsPromise = loadContents(recipientId, checklistId);
      } else {
        alert("Failed to reset the requested document");
      }
    }
  }
  const INVALIDURLMESSAGE = "Error! Invalid url added";

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
      new_file_request = detail.new_file_request;
      new_request_type = detail.new_request_type;
      new_file_request_description = detail.new_file_request_description;
      link_button_name = detail.link_button_name;
      link_button_url = getValidUrlLink(detail.link_button_url.trim());
      track_document_expiration = detail.track_document_expiration;
      is_confirmation_required = detail.is_confirmation_required;

      appendFileRequest();
      if (detail.save_and_add) {
        setTimeout(() => {
          link_button_name = "Start";
          showFillModal = true;
        }, 100);
      }
    }
    return isValidTask;
  }

  function handleRequestModal(new_request_type) {
    let isValidUrl = true;
    if (new_request_type === "task") {
      isValidUrl = isValidTaskRequest();
    }
    if (isValidUrl) {
      showFillModal = false;
      appendFileRequest();
    }
    return isValidUrl;
  }

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

  let new_file_request = "";
  let new_file_request_description = "";
  let link_button_name = "";
  let link_button_url = "";
  let new_request_type = "file";
  let is_confirmation_required = false;
  let track_document_expiration = false;

  let showRSDCustomizeConfirmationDialog = false;

  let showCustomizeModal = false;
  let currentlyCustomized = undefined;

  let showChooseTemplateModal = false;
  let current_selection_list = [];

  let showAddUniqueIdentifierDialog = false;
  let requestedChecklistIdentifier = "";
  let allowChecklistMultipleRequest = false;

  let showConfirmSendChecklistDialog = false;
  let newChecklistCustomMessage = false;
  let customMessage = "";

  function handleUniqueIndetifierInput(event) {
    showAddUniqueIdentifierDialog = false;
    const requestorUniqueIdentifier = event.detail.text;

    handleSubmitChecklist({}, requestorUniqueIdentifier);
  }

  //
  function handleCustomMessageInput(event) {
    customMessage = event.detail.text;
    if (customMessage.length) {
      append_note = customMessage;
      //With Optional Text
      newChecklistCustomMessage = false;
      showConfirmSendChecklistDialog = true;
    } else {
      //No Optional Text
      newChecklistCustomMessage = false;
      showConfirmSendChecklistDialog = true;
    }
  }

  const checklistDueUrgencyText = "ASAP - as soon as possible/Earliest";
  const checklistDueNA = "No set due date";
  const dueDateConfig = (configType) => {
    const { enforce_due_date: enforceDueDate } = contents;
    if (!enforceDueDate) return null;
    switch (configType) {
      case 1:
        return due_date;
      case 2:
        return getDaysDiff(new Date(), selectedDate);
      case 3:
        return 1;
      default:
        return null;
    }
  };

  function handleSubmitChecklist(event, requestorUniqueIdentifier = "") {
    showConfirmSendChecklistDialog = false;
    contents.enforce_due_date = due_date_group !== 4;
    contents.due_days = dueDateConfig(due_date_group);
    const _contents = { ...contents, requestorUniqueIdentifier };
    onSubmitChecklist(_contents, append_note);
  }

  function setLocalStorage(obj) {
    assignedChecklistInfo.set({ ...obj });
  }

  function routeIACSetupFor(doc) {
    window.location.hash = `#iac/setup/rsd/${doc.customization_id}?ro=1&prefill=true`;
  }

  function setupSwapInProcess(content) {
    const { customizations } = content;
    const customization = customizations[swappedTemplateID];

    setLocalStorage({ assigneeId: checklistId });
    routeIACSetupFor(customization);
  }

  let showResetContentsConfirmationBox = false;
  let contentsId = undefined;

  async function handleResetContents(evt) {
    showResetContentsConfirmationBox = false;

    let reply = await deleteDraftContents(contentsId);
    if (reply.ok) {
      showToast(
        "Success! The checklist has been reset!",
        1000,
        "default",
        "MM"
      );
      setTimeout(() => window.location.reload(), 1000);
    } else {
      showToast("Error! Please try again later.", 1000, "error", "MM");
    }
    contentsId = undefined;
  }

  function onClickResetContents({ id }) {
    contentsId = id;
    showResetContentsConfirmationBox = true;
  }

  /**
   * @description handler for add and remove xtra file upload
   *
   * @param currentFlag current checkbox status
   *
   * @returns async callback to add or remove file uploads
   */
  async function handleAddtionalFileUploadStatus(currentFlag) {
    const addNewRequest = currentFlag && !isRecipientAllowedExtraFileUploads;

    // Checkbox unchecked status
    if (!currentFlag) {
      // check if remove extra file upload check status
      if (isRecipientAllowedExtraFileUploads) {
        // delete from contents api
        const toRemoveId = contents.requests.filter(
          (request) => request.flags === 4
        )[0].id;
        const data = { detail: { requestId: toRemoveId } };
        console.log("delete request");
        deleteRequest(data);
      } else {
        // no action required
        return;
      }
    } else if (addNewRequest) {
      // add request api call
      console.log("add request");
      (new_file_request = "PlaceHolder for Recipient File Uploads"),
        (new_request_type = ADDTIONALFILEUPLOADTYPE);
      await appendFileRequest();
    } else {
      // default
      return;
    }
    return;
  }

  async function dragDrop(event) {
    let file_requests = event.detail.file_requests;
    console.log("file_requests", file_requests);
    contents.requests = file_requests;
    contents = contents;

    try {
      await updateContentsAsync(contents);
      allowResetChecklistState = true;
    } catch (error) {
      alert(error);
      console.error(error);
    }
  }

  const getHumanizedDate = (date, addDays = 0) => {
    return addDates(date, addDays);
  };

  // function Reactive on allow extra file upload checkbox state change
  $: handleAddtionalFileUploadStatus(allowFileRequestisChecked);

  const style = `
    width: auto;
    color: var(--text-secondary);
    border-radius: .375em;
    padding: 0.5rem 0.5rem;
  `;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_toolbar: true,
    collapsed: true,
    allowHandleHeaderClick: true,
    disableCollapse: true,
    has_z_index: false,
  };

  const getDuedate = (offsetDays, calenderDate, switcher) => {
    switch (switcher) {
      case 1:
        dueDateHumanized = getHumanizedDate(new Date(), offsetDays);
        break;
      case 2:
        dueDateHumanized = getHumanizedDate(calenderDate);
        break;
      case 3:
        dueDateHumanized = getHumanizedDate(new Date(), 1);
        break;
      default:
        dueDateHumanized = DUEDATENOTSET;
        break;
    }
  };

  $: getDuedate(due_date, selectedDate, due_date_group);
  let fileRetentionType = 0;

  const fileRetentionOptions = [
    { text: "7 days", value: 7 },
    { text: "15 days", value: 15 },
    { text: "30 days", value: 30 },
  ];

  let defaultOptionIndex = 2;
  let fileRetentionPeriod = -1;
  let fileRetentionDropdownValue = -1;

  const handleFileRetentionChange = (newValue) => {
    if (fileRetentionDropdownValue !== fileRetentionPeriod) {
      fileRetentionPeriod = fileRetentionDropdownValue;
    }
  };

  $: handleFileRetentionChange(fileRetentionDropdownValue);
</script>

{#await contentsPromise then contents}
  <div class="mobile-navbar">
    <NavBar
      navbar_spacer_classes="navbar_spacer_pb1"
      backLink=" "
      backLinkHref="#recipients"
      showCompanyLogo={false}
      middleText={`${capitalizeFirstLetter(contents.title)}`}
      middleSubText={`
        ${capitalizeFirstLetter(contents.recipient.name)}
        ${contents.recipient.company ? ` (${contents.recipient.company})` : ""}
        ${contents.recipient.email ? `&lt;${contents.recipient.email}&gt;` : ""}
      `}
    />
  </div>

  <div class="desktop-navbar">
    <NavBar
      navbar_spacer_classes="navbar_spacer_pb1"
      backLink=" "
      backLinkHref="#recipients"
    >
      <div class="information">
        <div class="content-information">
          <span style="font-weight: 600; font-size: 18px;" class="overflow-text"
            >{capitalizeFirstLetter(contents.title)}</span
          >
          <span
            class="overflow-text"
            style="margin: 0; padding: 0 0 0 5px; font-size: 16px;"
            >{"(" +
              capitalizeFirstLetter(contents.description) +
              ")" +
              " (From: " +
              currentRequestorCompany +
              ")"}</span
          >
        </div>
        <div class="dates text-center">
          <p style="font-size: 16px;" class="name">
            <span>{capitalizeFirstLetter(contents.recipient.name)}</span>
            <span>{"(" + contents.recipient.company + ")"}</span>
            <span class="desktop-only"
              >{"<" + contents.recipient.email + ">"}</span
            >
          </p>
          <div style="font-size: 14px; font-weight: 600">
            Due date: {dueDateHumanized}
          </div>
        </div>
      </div>
    </NavBar>
  </div>
{/await}

<div class="container">
  {#await contentsPromise}
    <p>Loading...</p>
  {:then _contents}
    <!-- Not Sure why this code exist's that's why commenting not deleting -->
    <!-- {#if max_tab != min_tab}
      <div class="progress-tab">
        <ProgressTab
          elements={["Customize", "Summary"]}
          current={current_tab}
        />
      </div>
    {/if} -->
    <div class="progress-tab">
      <ProgressTab
        elements={[
          "Select checklist/ recipient",
          "Personalize; add/ remove items",
          "Settings",
          "Send",
        ]}
        current={ProgressStep}
      />
    </div>

    {#if current_tab == 0}
      <div class="reset-button">
        <span>
          <Button
            text="Reset Checklist"
            disabled={!allowResetChecklistState}
            color="white"
            onClickHandler={() => onClickResetContents(_contents)}
          />
        </span>
      </div>

      <Panel {style} {...panelProps} title="Templates">
        <ChecklistDocumentTable
          on:deleteTemplate={deleteTemplate}
          on:customizeTemplate={beginCustomization}
          on:revertTemplate={(evt) => {
            revertCustomization(contents, evt);
          }}
          documents={contents.documents}
          contentsId={contents.id}
          recipientId={contents.recipient.id}
          customizations={contents.customizations}
        />

        <p class="add">
          <span
            on:click={() => {
              showChooseTemplateModal = true;
            }}
          >
            <Button color="primary" text="Add Document" />
          </span>
        </p>
      </Panel>

      <Panel {style} {...panelProps} title="Requests">
        <ChecklistFileRequestsTable
          on:deleteRequest={deleteRequest}
          on:dragDrop={dragDrop}
          draggable={false}
          file_requests={contents.requests.filter((req) => req.flags !== 4)}
          showEmptyText={true}
        />
        <div
          style="display: flex; justify-content: space-between; align-items: center"
        >
          <Switch
            bind:checked={allowFileRequestisChecked}
            text={`${ALLOWEXTRAFILESTOUPLOADTEXT}`}
            action={switchAdditionalFiles}
          />
          <p class="add">
            <span
              on:click={() => {
                showFillModal = true;
              }}
            >
              <Button color="white" text="Add Request" />
            </span>
          </p>
        </div>
      </Panel>
      <br />
      <Panel {style} {...panelProps} title="Forms">
        <ChecklistFormsTable
          on:deleteForm={deleteForm}
          forms={contents.forms}
          contentsId={contents.id}
          showEmptyText={true}
          allowEdit={true}
          {checklistId}
        />
        <p class="add">
          <span
            on:click={() => {
              showFormCreateModal = true;
              formStore.reset();
            }}
          >
            <Button color="white" text="Add Form" />
          </span>
        </p>
      </Panel>
    {/if}

    {#if current_tab == 1}
      <section class="templates">
        <div class="header">Additional/ unrequested file uploads</div>
        <div style="font-weight: bolder;">
          <Switch
            bind:checked={allowFileRequestisChecked}
            text={`${ALLOWEXTRAFILESTOUPLOADTEXT}`}
            action={switchAdditionalFiles}
          />
        </div>
        <div class="header">Due Date</div>
        <div style="font-weight: bolder;">
          {#if contents?.recipient?.start_date == undefined || contents?.recipient?.start_date == null || contents?.recipient?.start_date == ""}
            Recipient start date: -
          {:else}
            Recipient start date: {getHumanizedDate(
              new Date(contents?.recipient?.start_date)
            )}
          {/if}
        </div>
        <div class="due-date-option" on:click={() => (due_date_group = 1)}>
          <input
            type="radio"
            bind:group={due_date_group}
            name="due_date_group"
            value={1}
          />
          <span class="day-send-text">Days after sending </span>
          <div class="day-send-actions">
            <div class="btn-group">
              <Button
                disabled={due_date <= MINDUEDATE || due_date_group === 2
                  ? true
                  : false}
                text="-"
                textStyle="font-size: 24px"
                onClickHandler={() => (due_date -= 1)}
              />
              <span>{due_date || 1}</span>
              <Button
                disabled={due_date_group === 2 ||
                due_date_group === 3 ||
                due_date_group === 4
                  ? true
                  : false}
                text="+"
                textStyle="font-size: 24px"
                onClickHandler={() => (due_date += DUEDATESTEP)}
              />
            </div>
            <div class="flex items-center">
              {due_date_group === 1 ? ` ${dueDateHumanized}` : ""}
            </div>
          </div>
        </div>

        <div class="due-date-option" on:click={() => (due_date_group = 2)}>
          <input
            type="radio"
            bind:group={due_date_group}
            name="due_date_group"
            value={2}
          />
          <span class="specific-send-text">Select specific dates</span>
          <span>
            <Flatpickr
              options={flatpickrOptions}
              bind:value={selectedDate}
              element="#date-picker"
            >
              <div class="flatpickr" id="date-picker">
                <input type="text" placeholder="Select Date.." data-input />
              </div>
            </Flatpickr>
          </span>
        </div>

        <div class="due-date-option">
          <input
            type="radio"
            id="urgency-due-date"
            bind:group={due_date_group}
            name="due_date_group"
            value={3}
          />
          <label for="urgency-due-date">{checklistDueUrgencyText}</label>
        </div>

        <div class="due-date-option">
          <input
            type="radio"
            id="no-due-date"
            bind:group={due_date_group}
            name="due_date_group"
            value={4}
          />
          <label for="no-due-date">{checklistDueNA}</label>
        </div>
      </section>
    {/if}
  {:catch err}
    <p>Failed to load the contents information: {err}</p>
  {/await}
</div>

{#if showFormEdit}
  <EditFormModal
    title={isFormPreview ? "Form Preview" : "Form Editor"}
    on:close={() => {
      formStore.reset();
      showFormEdit = false;
      isFormPreview = false;
      formTitle = "";
      formDescription = "";
    }}
  >
    <div class="form-container">
      <div class="tooltip" style="position: relative;">
        <div
          style="position: absolute;
          left: 202px;
          top: -52px;
          cursor: pointer;
          font-size: 26px;
          display: flex;
          align-items: center;"
          on:click={() => {
            isFormPreview = !isFormPreview;
          }}
        >
          {#if isFormPreview}
            <span
              style="font-size: 14px;
        margin-right: 6px;
        width: 90px;">Show preview</span
            >
            <FAIcon iconStyle="regular" icon="eye-slash" />
          {:else}
            <span
              style="font-size: 14px;
        margin-right: 6px;
        width: 90px;">Hide preview</span
            >
            <FAIcon iconStyle="regular" icon="eye" />
          {/if}
          <span class="tooltiptext">Preview</span>
        </div>
      </div>
      <div style="width: 650px;">
        <div style="padding-top: 12px;">
          {#if !isFormPreview}
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
        {#each $formStore.questions.formFields as question, index}
          <div style="padding-top: 12px;">
            {#if !isFormPreview}
              <Card
                setSelected={() => {
                  currentIndex = index;
                }}
                isSelected={currentIndex == index ? true : false}
              >
                <Question {question} questionIndex={index} />
                <FormCommands {question} {index} />
              </Card>
            {:else}
              <FormElementRenderer {question} readOnly={true} />
            {/if}
          </div>
        {/each}
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
                addForm();
                showFormEdit = false;
                isFormPreview = false;
              }
            }}
          >
            <Button color="secondary" text="Create Form" />
          </span>
        </div>
      </div>
    </div>
  </EditFormModal>
{/if}

{#if showFormCreateModal}
  <Modal
    on:close={() => {
      showFormCreateModal = false;
      formTitle = "";
      formDescription = "";
      //need to reset, make sure that store is empty
      formStore.reset();
    }}
    title="Create Form"
  >
    <h3>Create Form</h3>
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
    </div>
    <div class="modal-buttons">
      <span
        style="width: 100%;"
        on:click={() => {
          showFormCreateModal = false;
          showFormEdit = true;
          formStore.addDetails(formTitle, formDescription);
        }}
      >
        <Button
          disabled={formTitle.trim() === ""}
          color="secondary"
          text="Create form"
        />
      </span>
      <span
        style="width: 45%; margin-left: 15px;"
        on:click={() => {
          showChooseExistingForm = true;
          showFormCreateModal = false;
        }}
      >
        <Button color="light" text="Choose from existing" />
      </span>
    </div>
  </Modal>
{/if}

{#if showChooseExistingForm}
  <ChooseExistingFormModal
    on:close={() => {
      formStore.resetQuestions();
      showChooseExistingForm = false;
    }}
    isRecipientAssign={true}
    {recipientId}
    {checklistId}
    {contents}
    callback={loadContents}
  />
{/if}

{#if showFillModal}
  <AddRequestModal
    on:close={() => {
      showFillModal = false;
      new_file_request = "";
      new_file_request_description = "";
      link_button_name = "";
      link_button_url = "";
      new_request_type = "file";
    }}
  >
    <CheckListForm
      {new_request_type}
      {new_file_request}
      {new_file_request_description}
      {link_button_name}
      {link_button_url}
      allow_file_requestis_checked={allowFileRequestisChecked}
      modalView={true}
      on:add={(ev) => handleAddRequest(ev)}
      on:cancel={() => {
        showFillModal = false;
      }}
    />
  </AddRequestModal>
{/if}

{#if showChooseTemplateModal}
  <ChooseTemplateModal
    on:selectionMade={processSelection}
    on:close={() => (showChooseTemplateModal = false)}
    default_selection_list={current_selection_list}
  />
{/if}

{#if showCustomizeModal}
  <UploadFileModal
    requireIACwarning={true}
    multiple={false}
    uploadHeaderText="Customize {currentlyCustomized.name} for {contents
      .recipient.name}"
    specialText="After uploading a document, you can add fields to be filled/ signed."
    on:done={processCustomization}
    on:close={() => (showCustomizeModal = false)}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if isTemplateSwapped}
  <div class="container">
    <ConfirmationDialog
      yesText="Yes"
      yesColor="primary"
      noText="No"
      noColor="light"
      question="Proceed to adding fields and pre-filling document?"
      on:close={() => {
        isTemplateSwapped = false;
      }}
      on:yes={() => {
        setupSwapInProcess(contents);
      }}
    />
  </div>
{/if}

{#if showRSDCustomizeConfirmationDialog}
  <ConfirmationDialog
    yesText="Yes - Send As Is"
    yesColor="danger"
    noText="No, customize"
    noColor="primary"
    question="Some placeholder documents were not customized - are you sure you want to send the checklist as is (leaving the placeholders in)?"
    on:close={() => {
      showRSDCustomizeConfirmationDialog = false;
      ProgressStep = ProgressStep - 1;
      sendChecklistClicked = false;
    }}
    on:yes={() => {
      showRSDCustomizeConfirmationDialog = false;
      determineConfirmationDialogBox();
    }}
  />
{/if}

{#if showAddUniqueIdentifierDialog}
  <ConfirmationDialog
    title={"Add Unique Reference"}
    details={"If you're sending this checklist to a contact more than once, enter an optional reference below to tell it apart (i.e. 2021 Q3, claim 1234, etc)."}
    responseBoxEnable="true"
    responseBoxDemoText="Enter Reference Input"
    responseBoxText={requestedChecklistIdentifier}
    yesText="Send"
    noText="Cancel Send"
    yesColor="primary"
    noColor="gray"
    on:message={handleUniqueIndetifierInput}
    on:yes={""}
    on:close={() => {
      showAddUniqueIdentifierDialog = false;
      sendChecklistClicked = false;
      ProgressStep = ProgressStep - 1;
    }}
  />
{/if}

{#if showConfirmSendChecklistDialog}
  {#if checkStatusConfirmation !== true}
    <ConfirmationDialog
      title={"Confirmation"}
      details={"The other party will receive a link in an email to complete the checklist. If you need to unsend or delete this request, go to the dashboard, find the request, then click the unsend button on the hamburger menu on the right. You can also delete from Contacts > Details (hamburger menu next to the contact's name)."}
      yesText="Send"
      noText="Cancel Send"
      yesColor="primary"
      noColor="gray"
      checkBoxEnable={"enable"}
      checkBoxText={"Don't ask me this again"}
      on:yes={handleSubmitChecklist}
      on:close={() => {
        showConfirmSendChecklistDialog = false;
        ProgressStep = ProgressStep - 1;
        sendChecklistClicked = false;
      }}
      on:hide={(event) => {
        if (event?.detail) {
          localStorage.setItem(
            "dontShowConfirmationSendChecklist",
            event?.detail
          );
        } else {
          localStorage.setItem(
            "dontShowConfirmationSendChecklist",
            event?.detail
          );
        }
      }}
    />
  {:else}
    {handleSubmitChecklist()}
  {/if}
{/if}

{#if showChecklistGuideDialog}
  {#if checklistGuideDialogStatus !== true}
    <ConfirmationDialog
      title={"Personalize Checklist"}
      details={"Personalize this checklist for the specific recipient before sending. You can:"}
      hideText={"Got it"}
      hideColor={"white"}
      checkBoxEnable={"enable"}
      checkBoxText={"Don't ask me this again"}
      guidePointsEnable={"enable"}
      {guidePoints}
      on:yes={""}
      on:close={(event) => {
        if (event?.detail) {
          localStorage.setItem("dontshowChecklistGuideDialog", event?.detail);
        } else {
          localStorage.setItem("dontshowChecklistGuideDialog", false);
        }
        showChecklistGuideDialog = false;
      }}
      on:hide={(event) => {
        if (event?.detail) {
          localStorage.setItem("dontshowChecklistGuideDialog", event?.detail);
        } else {
          localStorage.setItem("dontshowChecklistGuideDialog", false);
        }
        showChecklistGuideDialog = false;
      }}
    />
  {/if}
{/if}

{#if showResetContentsConfirmationBox}
  <ConfirmationDialog
    question="This will remove the previously created draft and update the checklist based on current master checklist. Are you sure?"
    yesText="Yes, Reset"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    on:yes={handleResetContents}
    on:close={() => {
      showResetContentsConfirmationBox = false;
    }}
  />
{/if}

{#if newChecklistCustomMessage}
  <ConfirmationDialog
    title="Custom Message (Optional)"
    details={"This will appear in the notification email to the recipient."}
    yesText="Send"
    noText="Cancel"
    yesColor="primary"
    noColor="white"
    textAreaDemoText={"Custom Message"}
    textAreaEnable="{true};"
    textAreaText={customMessage}
    noLeftAlign={true}
    on:close={() => {
      newChecklistCustomMessage = false;
      showConfirmSendChecklistDialog = true;
    }}
    on:yes={""}
    on:message={handleCustomMessageInput}
  />
{/if}

<div class="buttom-nav">
  <div class="navbar">
    <span
      on:click={() => {
        current_tab == min_tab ? current_tab : current_tab--;
        ProgressStep = ProgressStep - 1;
      }}
    >
      <Button color="light" disabled={current_tab == min_tab} text="Back" />
    </span>

    {#if current_tab == max_tab}
      <span on:click={sendChecklistClicked ? () => {} : handleSubmit}>
        <Button
          text="Send Checklist"
          disabled={sendChecklistClicked}
          color="secondary"
        />
      </span>
    {:else}
      <span
        on:click={() => {
          current_tab == max_tab ? current_tab : current_tab++;
          ProgressStep = ProgressStep + 1;
        }}
      >
        <Button text="Next" color="secondary" />
      </span>
    {/if}
  </div>
</div>

<style>
  :global(.flatpickr-calendar) {
    font-family: Nunito, sans-serif;
  }

  :global(.flatpickr-day.selected) {
    background: #2a2f34 !important;
    -webkit-box-shadow: none;
    box-shadow: none;
    color: #fff;
    border-color: #2a2f34 !important;
  }

  :global(.flatpickr-months .flatpickr-next-month:hover svg) {
    fill: #2a2f34 !important;
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

  .form-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
    margin-top: 25px;
  }

  .required {
    color: rgb(221, 38, 38);
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

  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
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
  .buttom-nav {
    background: #f0f5fb;
    box-shadow: 0px -7px 20px rgba(0, 0, 0, 0.08);
    overflow: hidden;
    position: fixed;
    right: 0;
    bottom: 0;
    left: 0;
    width: 100%;
    justify-content: center;
    box-sizing: border-box;
    z-index: 10;
  }

  .navbar {
    display: flex;
    width: 100%;
    padding: 1rem;
    align-items: center;
    margin-bottom: 0.5rem;
    justify-items: center;
    justify-content: space-between;
    box-sizing: border-box;
  }
  .navbar span {
    box-sizing: border-box;
    width: 90%;
    justify-self: center;
  }

  .reset-button {
    display: flex;
    justify-content: end;
    margin-bottom: 1rem;
  }

  .add {
    display: flex;
    justify-content: end;
  }

  .progress-tab {
    margin-top: 5%;
    display: flex;
    flex-flow: row nowrap;
    justify-content: center;
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

  .templates {
    display: grid;
    gap: 20px;
  }

  .due-date-option {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .day-send-text {
    width: 135px;
  }
  .day-send-actions {
    display: flex;
    gap: 8px;
  }

  .btn-group {
    display: grid;
    grid-auto-flow: column;
    gap: 6px;
    align-items: center;
  }

  .specific-send-text {
    width: 146px;
  }

  .dates > .name {
    margin: 0;
  }

  .name > span {
    overflow-wrap: break-word;
    white-space: nowrap;
  }

  .container {
    padding-left: 2rem;
    padding-right: 2rem;
    padding-bottom: 4rem;
  }

  .mobile-navbar {
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
  @media only screen and (max-width: 780px) {
    .information {
      font-size: 16px;
      line-height: 22px;
    }

    .dates {
      display: block !important;
    }

    .dates .name {
      padding: 0;
      padding-bottom: 0.5rem;
      margin: 0;
    }

    .add span {
      width: 100%;
    }
  }

  @media only screen and (min-width: 480px) {
    .navbar span {
      width: 250px;
      justify-self: right;
      margin-right: 0.5rem;
    }
  }

  @media only screen and (max-width: 767px) {
    .container {
      padding-left: 0.5rem;
      padding-right: 0.5rem;
    }
    .progress-tab {
      display: none;
    }
    .mobile-navbar {
      display: block;
    }
    .desktop-navbar {
      display: none;
    }
    .desktop-only {
      display: none;
    }
    .day-send-actions {
      flex-direction: column;
    }
  }

  @media only screen and (max-width: 480px) {
    .information {
      font-size: 12px;
      line-height: 14px;
      width: 50%;
    }
    .content-information {
      flex-direction: column;
    }
    .overflow-text {
      display: unset;
    }
  }
  /* 320 */
  @media only screen and (max-width: 320px) {
    .dates {
      display: none !important;
    }
  }
</style>
