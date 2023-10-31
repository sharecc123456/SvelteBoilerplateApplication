<script>
  import FAIcon from "Atomic/FAIcon.svelte";
  import Button from "Atomic/Button.svelte";
  import ChecklistRow from "Components/Requestor/ChecklistRow";
  import CabinetRow from "Components/Requestor/CabinetRow";
  import ChecklistHeader from "Components/Requestor/ChecklistHeader.svelte";
  import CabinetHeader from "Components/Requestor/CabinetHeader.svelte";
  import { loadDashboardForRecipient } from "BoilerplateAPI/Recipient";
  import {
    archiveAssignment,
    unArchiveAssignment,
  } from "BoilerplateAPI/Assignment";
  import {
    getArchivedAssignments,
    unsendAssignment,
  } from "BoilerplateAPI/Assignment";
  import { deleteFormSubmission, unsendForm } from "BoilerplateAPI/Form";
  import { onMount } from "svelte";
  import { getCabinet } from "BoilerplateAPI/Recipient";
  import ToastBar from "Atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";
  import Loader from "Components/Loader.svelte";
  import Modal from "Components/Modal.svelte";
  import UploadFileModal from "Modals/UploadFileModal.svelte";
  import { templateManualUpload } from "BoilerplateAPI/Template";
  import {
    fileRequestManualUpload,
    hasExpirationValueChanged,
  } from "BoilerplateAPI/FileRequest.js";
  import {
    getCabinetDownloadUrl,
    getDocumentDownloadUrl,
    isIACCompatibleType,
    requestorTemplateNonIACExtensions,
    getRequestorOpenDocPreviewLink,
    getChecklistDownloadUrl,
  } from "../../../../../helpers/fileHelper";
  import ChooseChecklistModal from "Modals/ChooseChecklistModal.svelte";
  import ChooseTemplateModal from "Modals/ChooseTemplateModal.svelte";
  import { createTemplate } from "../../../../../api/Template";
  import {
    directSendTemplates,
    directSendChecklist,
    directSendUploadedTemplates,
  } from "../../../../../api/Template";
  import {
    createAndSendChecklist,
    requires_iac_fill,
  } from "../../../../../api/TemplateGuide.js";
  import {
    deleteRecipientCabinetId,
    replaceRecipientCabinetId,
  } from "../../../../../api/Cabinet";

  import { remindNowV2, setupRSDDocument } from "../../../../../api/Checklist";
  import assignedChecklistInfo from "../../../../../localStorageStore";
  import AddExpirationDate from "../../../../components/AddExpirationDate.svelte";
  import { requestExpirationInfo } from "BoilerplateAPI/RecipientPortal";
  import {
    CURRENTLYSELECTEDRECIPIENT,
    DOARCHIVE,
  } from "../../../../../helpers/constants";
  import { resetRequestorSignatureFields } from "../../../../../helpers/Requester/Dashboard";

  export let recipientId;
  let assignments = [];

  let archives = [];
  export let cabinetPromise = new Promise();
  let showUploadModal = false;
  export let recipient = {};
  let ifConfirmed = undefined;
  let loadingAssignment = true;
  let loadingArchive = true;
  let showConfirmationDialog = false;
  let showUnsendPromt = false;
  let fillViewModal = false;
  let assignment_chevron = [];
  let archive_chevron = [];
  let unsendThis;
  let delete_data;
  let showConfirmationDeleteFile = false;
  let fillText = "";
  let fillName = "";
  let pid = null;
  let rid = null;
  let itemToBeViewed = null;
  let showItemPopUp = false;
  let manualUploadData = {};
  let showSelectChecklistModal = false;
  let assigning_for = undefined;

  let showIACSignatureResetConfirmation = false;
  let iacFilldata = {};

  const loadAssignment = async () => {
    try {
      loadingAssignment = true;
      const recipientData = await loadDashboardForRecipient(recipientId, {});
      assignments = recipientData?.checklists || [];
      assignment_chevron = new Array(assignments.length).fill(false);
      if (localStorage.getItem("docTabActiveChecklist")) {
        const activeId = localStorage.getItem("docTabActiveChecklist");
        if (activeId !== -1) assignment_chevron[activeId] = true;
        localStorage.setItem("docTabActiveChecklist", null);
      }
      loadingAssignment = false;
    } catch (err) {
      console.error(err);
    }
  };

  const loadArchive = async () => {
    try {
      loadingArchive = true;
      archives = await getArchivedAssignments(recipientId).catch((err) =>
        console.log(err)
      );
      archive_chevron = new Array(assignments.length).fill(false);
      if (localStorage.getItem("docTabActiveArchive")) {
        const activeArchiveId = localStorage.getItem("docTabActiveArchive");
        if (activeArchiveId !== -1) archive_chevron[activeArchiveId] = true;
        localStorage.setItem("docTabActiveArchive", null);
      }
      loadingArchive = false;
    } catch (err) {
      console.error(err);
    }
  };
  onMount(async () => {
    try {
      // await loadAssignment(); replacing this with a single fuction to load both
      await loadActiveAndDeletedAssignments();
      await loadArchive();
    } catch (err) {}
  });

  const deleteCabinetFile = async (document) => {
    const reply = await deleteRecipientCabinetId(recipientId, document.id);
    if (reply.ok) {
      showToast(
        `Cabinet "${document.name}" has been deleted.`,
        1500,
        "default",
        "MM"
      );
      cabinetPromise = getCabinet(recipientId);
    } else {
      showToast(
        "Something went wrong while uploading this file",
        1500,
        "error",
        "MM"
      );
    }
  };

  const replaceCabinetFile = async (evt) => {
    let cabinet = evt.detail;
    const { replaceId, rId } = replaceCabinetData;
    const reply = await replaceRecipientCabinetId(cabinet, rId, replaceId);
    if (reply.ok) {
      showToast(
        `Cabinet "${replaceCabinetData.name}" has been replaced.`,
        1500,
        "default",
        "MM"
      );
      cabinetPromise = getCabinet(recipientId);
    } else {
      showToast("Something went wrong while replace file", 1500, "error", "MM");
    }
    showCabinetFileReplaceUploadModal = false;
  };

  let showCabinetFileDeleteConfirmationDialogBox = false;
  let showCabinetFileReplaceUploadModal = false;
  let cabibetFileToDelete;
  let replaceCabinetData = {};

  const handleCabinetClick = async (document, ret) => {
    switch (ret) {
      case 1:
        cabibetFileToDelete = document;
        showCabinetFileDeleteConfirmationDialogBox = true;
        break;
      case 2:
        const downloadUrl = getCabinetDownloadUrl(recipientId, document);
        window.location = downloadUrl;
        break;
      case 3:
        // Replace
        replaceCabinetData = {
          replaceId: document.id,
          name: document.name,
          rId: recipientId,
        };
        showCabinetFileReplaceUploadModal = true;
        break;
      default:
        showToast("No such options", 1500, "error", "MM");
    }
  };

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

  const handleFormDropDown = async (ret, form, assignment, recipient_id) => {
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
          showConfirmationDeleteFile = true;
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
        window.location.hash = `#recipient/${recipient_id}/details/data?filter=fs&fs=${form.submission_id}&showText=${showText}`;
        window.location.reload();
        break;
      default:
        alert("Dropdown Fault");
        break;
    }
  };

  function handleAssignmentDropdownClick(
    assignment,
    ret,
    request = "Oops",
    recipient_id
  ) {
    if (ret == 1) {
      /* Archive */
      archiveAssignment(assignment.id).then(async () => {
        showToast(
          `Checklist "${assignment.name}" has been archived.`,
          3000,
          "default",
          "MM"
        );
        await loadAssignment();
        await loadArchive();
      });
    } else if (ret == 2) {
      /* Unsend / Delete */
      unsendThis = assignment;
      showUnsendPromt = true;
    } else if (ret == 3) {
      //print
      if (request.type == "file") {
        printJS(`/n/api/v1/dproxy/${request.value}`);
      } else {
        const downloadUrl = getDocumentDownloadUrl(assignment, request);
        printJS(downloadUrl);
      }
    } else if (ret == 4) {
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
    } else if (ret === 6) {
      /* Un Archiving checklist assignment */
      unArchiveAssignment(assignment.id).then(async (x) => {
        if (x.ok) {
          showToast(
            `Checklist "${assignment.name}" has been un archived.`,
            3000,
            "default",
            "MM"
          );
          await loadAssignment();
          await loadArchive();
        } else {
          showToast(
            `Error Checklist "${assignment.name}" could not be unarchived.`,
            3000,
            "error",
            "MM"
          );
        }
      });
    } else if (ret === 7) {
      // manual file upload
      manualUploadData = {
        type: "file",
        assignId: assignment.id,
        id: request.id,
      };
      showUploadModal = true;
    } else if (ret === 8) {
      showExpirationTrackEditBox = true;
      reqEditingExpirationInfo = request;
    } else if (ret === 9) {
      const hash = getRequestorOpenDocPreviewLink(assignment, request);
      window.open(hash, "_blank");
    } else if (ret === 10) {
      let showText = `${assignment.name} @ ${assignment.received_date.date}`;
      window.location.hash = `#recipient/${recipient_id}/details/data?filter=cs&cs=${assignment.contents_id}&showText=${showText}`;
      window.location.reload();
    } else if (ret === 11) {
      iacFilldata = {
        iacDocId: request.iac_document_id,
        contentsId: assignment.contents_id,
        recipientId: assignment.recipient_id,
      };
      showIACSignatureResetConfirmation = true;
    } else if (ret === 12) {
      window.location = getChecklistDownloadUrl(4, assignment.id);
    }
  }

  let reminderInfo = {};
  function tryRemindNow(packageId, recipientId, lastReminderInfo) {
    showConfirmationDialog = true;
    pid = packageId;
    rid = recipientId;
    reminderInfo = lastReminderInfo;
  }

  async function handleRemindMessage(event) {
    let remindMsg = event.detail.text;
    if (pid != null && rid != null && pid != "ALL") {
      await remindNowV2(pid, rid, remindMsg);
      showConfirmationDialog = false;
      await loadAssignment();
      showToast(`Reminder email has been sent`, 3000, "default", "BM");
    } else if (pid == "ALL") {
      remindNowV2("ALL", rid, remindMsg);
      showConfirmationDialog = false;
      showToast(`Reminder email has been sent`, 3000, "default", "BM");
    } else {
      showConfirmationDialog = false;
      alert(pid);
      alert(rid);
      alert("Critical Error with Remind");
      console.log(
        "Remind now email could not send pid = " + pid + "rid = " + rid
      );
    }
  }

  const unsendChecklist = async () => {
    try {
      await unsendAssignment(unsendThis.id).catch(() => {
        console.error(err);
      });

      showToast(
        `Checklist "${unsendThis.name}" has been unsent.`,
        3000,
        "default",
        "BM"
      );
      unsendThis = null;
      showUnsendPromt = false;
      await loadActiveAndDeletedAssignments();
      await loadArchive();
    } catch (err) {
      console.error(err);
    }
  };

  const showViewModal = (file) => {
    fillName = file.name;
    fillText = file.value;
    fillViewModal = true;
  };

  const handleItemPopup = (item) => {
    itemToBeViewed = item;
    showItemPopUp = true;
  };

  async function uploadCabinet(evt) {
    let cabinet = evt.detail;
    let fd = new FormData();
    fd.append("name", cabinet.name);
    fd.append("upload", cabinet.file);
    let reply = await fetch(`/n/api/v1/recipient/${recipientId}/cabinet`, {
      method: "POST",
      credentials: "include",
      body: fd,
    });
    if (reply.ok) {
      cabinetPromise = getCabinet(recipientId);
      showUploadModal = false;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }

  const toggleActiveChevron = (id) => {
    assignment_chevron[id] = !assignment_chevron[id];
  };
  const toggleArchiveChevron = (id) => {
    archive_chevron[id] = !archive_chevron[id];
  };

  function assignPackage(evt) {
    let detail = evt.detail;
    let packageId = detail.checklistId;

    window.location.hash = `#recipient/${assigning_for.id}/assign/${packageId}`;
  }

  const ACTIONBUTTONTYPE = 1;
  const MODALBUTTONTYPE = 3;
  const NORECIPIENTBUTTONTYPE = 4;

  let optionsColor = "white";
  let newRequestModal = false;
  let bulkUploadFiles = false;
  let showItemChooseOptionBox = false;
  let showChooseTemplateModal = false;
  let existingTemplateGuide = false;
  let showChecklistActions = false;
  let showNewChecklistActions = false;
  let showTemplateUploadFile = false;

  let uploadedTemplate = undefined;
  let showTemplateTypeSelectionBox = false;

  let selectedTemplates = [];
  let defaultChecklistName = "";
  let isIACCompatible = false;
  const options = [
    {
      id: 0,
      title: "Send checklist",
      callbackfunc: () => (showSelectChecklistModal = true),
      icon: "clipboard-list",
      clicked: false,
      type: MODALBUTTONTYPE,
      order: 1,
      category: "send",
    },
    {
      id: 1,
      title: "Single request, action required",
      callbackfunc: () => (showItemChooseOptionBox = true),
      icon: "file-contract",
      clicked: false,
      type: MODALBUTTONTYPE,
      order: 2,
      category: "send",
    },
    {
      id: 2,
      title: "Securely send files, no action required",
      callbackfunc: () => (bulkUploadFiles = true),
      icon: "file-upload",
      clicked: false,
      type: ACTIONBUTTONTYPE,
      order: 3,
      category: "send",
    },
  ];

  const templateSendTypeOptions = () => [
    {
      title: "Add online form filling and signatures",
      callback: () => SetupForRSD(uploadedTemplate.id),
      icon: "file-contract",
      disabled: !isIACCompatible,
    },
    {
      title: "No, send as is",
      callback: () => SendUploadedTemplates(),
      icon: "plane",
      disabled: false,
    },
  ];

  async function SetupForRSD(rawDocId) {
    const reply = await setupRSDDocument(rawDocId, assigning_for.id);
    if (reply.ok) {
      let { checklist_id, contents_id } = await reply.json();
      assignedChecklistInfo.set({
        contentsId: contents_id,
        assigneeId: checklist_id,
        recipientId: assigning_for.id,
      });
      const newHash = `#iac/setup/template/${rawDocId}?directSend=true`;
      window.location.hash = newHash;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }

  const onSelectOption = (selectedobj) => {
    selectedobj.clicked = true;
    if (selectedobj.type === NORECIPIENTBUTTONTYPE) {
      selectedobj.callbackfunc();
    } else if (selectedobj.type === ACTIONBUTTONTYPE) {
      selectedobj.callbackfunc();
    } else if (selectedobj.type === MODALBUTTONTYPE) {
      if (selectedobj.title == "Send checklist") {
        newRequestModal = false;
        showChecklistActions = true;
      } else {
        newRequestModal = false;
        selectedobj.callbackfunc();
      }
    } else {
      window.location.hash = selectedobj.hash;
    }
  };

  const resetOptionsClickState = () => {
    options.forEach((option) => (option.clicked = false));
  };

  const processFileUploads = async (evt) => {
    let { name, file } = evt.detail;

    let reply = await directSendTemplates(name, file, assigning_for.id);
    bulkUploadFiles = false;
    if (reply.ok) {
      showToast(
        "File sent, the recipient will be notified in an email",
        2000,
        "default",
        "MM"
      );
    } else {
      showToast(
        "Something went wrong while Sending the files",
        1000,
        "error",
        "MM"
      );
    }
  };

  const templateChooseOption = [
    {
      title: "Send Existing Template",
      callback: () => (showChooseTemplateModal = true),
      icon: "copy",
    },
    {
      title: "Upload New Template",
      callback: () => (showTemplateUploadFile = true),
      icon: "file-upload",
    },
  ];

  let checklistActions = [
    {
      evt: "existing",
      description: "Use a saved/ existing checklist",
      icon: "clipboard-list-check",
    },
    { evt: "new", description: "Create new checklist", icon: "plus-circle" },
  ];

  let newChecklistActions = [
    {
      evt: "futureUse",
      description: "Save checklist for future use with other recipients",
      icon: "save",
    },
    {
      evt: "oneTime",
      description: "One time use (does not save to checklists)",
      icon: "sun-dust",
    },
  ];
  async function processExisitingTemplateSelection(evt) {
    selectedTemplates = evt.detail.templates;
    defaultChecklistName = selectedTemplates[0].name;
    existingTemplateGuide = true;
  }

  async function processChecklist(event) {
    existingTemplateGuide = false;
    const createdchecklist = await createAndSendChecklist(
      event.detail,
      selectedTemplates
    );
    if (createdchecklist.ok) {
      handleChecklistCreated(createdchecklist.id);
    }
  }

  async function handleChecklistCreated(checklistId) {
    showItemChooseOptionBox = false;
    if (requires_iac_fill(selectedTemplates)) {
      window.location.hash = `#recipient/${assigning_for.id}/assign/${checklistId}`;
    } else {
      let reply = await directSendChecklist(checklistId, assigning_for.id);
      if (reply.ok) {
        showToast(
          "Checklist sent, the recipient will be notified in an email",
          2000,
          "default",
          "MM"
        );
      } else {
        showToast(
          "Something went wrong while Sending the checklist",
          1000,
          "error",
          "MM"
        );
      }
    }
    assigning_for.id = null;
  }

  async function processNewTemplate(evt) {
    const { name, file, checkBoxStatus } = evt.detail;
    const archiveFlag = !checkBoxStatus;

    const templateReply = await createTemplate(name, file, archiveFlag);

    if (templateReply.ok) {
      let template = await templateReply.json();
      uploadedTemplate = template;
      isIACCompatible = isIACCompatibleType(file);
      showTemplateUploadFile = false;
      showTemplateTypeSelectionBox = true;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }

  const SendUploadedTemplates = async () => {
    console.log(uploadedTemplate);
    let reply = await directSendUploadedTemplates(
      uploadedTemplate.id,
      assigning_for.id
    );
    showTemplateTypeSelectionBox = false;
    if (reply.ok) {
      showToast(
        "File sent, the recipient will be notified in an email",
        2000,
        "default",
        "MM"
      );
    } else {
      showToast(
        "Something went wrong while Sending the files",
        1000,
        "error",
        "MM"
      );
    }
  };

  let deleted = [];
  const loadActiveAndDeletedAssignments = async () => {
    try {
      const recipientData = await loadDashboardForRecipient(recipientId, {
        show_deleted_checklists: true,
        show_in_dashboard: recipient.show_in_dashboard,
      });
      const allChecklists = recipientData?.checklists || [];
      const activeCl = [];
      const deletedCl = [];
      const DELETED_STATUS = [9, 10];
      allChecklists.forEach((cl) => {
        if (DELETED_STATUS.includes(cl.state.status)) {
          deletedCl.push(cl);
        } else {
          activeCl.push(cl);
        }
      });
      assignments = activeCl;
      deleted = deletedCl;
      console.log({ allChecklists, activeCl, deletedCl });
    } catch (err) {
      console.error(err);
    }
    loadingAssignment = false;
  };
</script>

<div class="header">
  <h3>Active Checklists</h3>
  <span
    on:click={() => {
      newRequestModal = true;
      assigning_for = recipient;
    }}
  >
    <Button color="secondary" text="Send New Request" />
  </span>
</div>
<div class="table">
  {#if loadingAssignment}
    <Loader loading />
  {:else}
    {#if !assignments?.length}
      <div class="empty_state">
        <p class="empty_state_child">
          <FAIcon icon="file-alt" iconSize="2x" iconStyle="regular" />
        </p>
        <p class="empty_state_child">
          No checklists or documentation to display.
        </p>
      </div>
    {:else}
      <ChecklistHeader {...{ assignments }} />
    {/if}
    {#each assignments as checklist}
      <ChecklistRow
        {...{
          checklist_chevron: assignment_chevron,
          toggleChevron: toggleActiveChevron,
          checklist,
          recipient,
          handleItemPopup,
          showViewModal,
          fillText,
          tryRemindNow,
          handleAssignmentDropdownClick,
          handleFormDropDown,
        }}
      />
    {/each}
  {/if}
</div>

<!-- end activity -->

<div class="dashboard">
  <div class="header">
    <h3>Archived Checklists</h3>
  </div>
  <div class="table">
    {#if loadingArchive}
      <Loader loading />
    {:else if archives.length}
      <ChecklistHeader {...{ assignments: archives }} />
      {#each archives as checklist}
        <ChecklistRow
          {...{
            checklist_chevron: archive_chevron,
            checklist,
            recipient,
            archived: true,
            handleItemPopup,
            toggleChevron: toggleArchiveChevron,
            handleAssignmentDropdownClick,
          }}
        />
      {/each}
    {:else}
      <div class="empty_state">
        <p class="empty_state_child">
          <FAIcon icon="file-alt" iconSize="2x" iconStyle="regular" />
        </p>
        <p class="empty_state_child">
          No checklists or documentation to display.
        </p>
      </div>
    {/if}
  </div>
</div>

<div class="cabinet">
  <div class="header">
    <h3>Internal Filing Cabinet</h3>
    <span
      on:click={() => {
        showUploadModal = true;
      }}
    >
      <Button icon="plus" text="Add Document" color="light" />
    </span>
  </div>
  <div class="table">
    {#await cabinetPromise}
      <Loader loading />
    {:then cabinet}
      {#if cabinet.length}
        <ChecklistHeader />
        {#each cabinet as document}
          <CabinetRow
            {...{ document, recipientId, handleItemPopup, handleCabinetClick }}
          />
        {/each}
      {:else}
        <div class="empty_state">
          <p class="empty_state_child">
            <FAIcon icon="file-alt" iconSize="2x" iconStyle="regular" />
          </p>
          <p class="empty_state_child">
            No checklists or documentation to display.
          </p>
        </div>
      {/if}
    {:catch err}
      <p>Failed to load cabinet...</p>
    {/await}
  </div>
</div>

<div class="dashboard">
  <div class="header">
    <h3>Deleted Checklists</h3>
  </div>
  <div class="table">
    {#if loadingAssignment}
      <Loader loading />
    {:else if deleted.length}
      <ChecklistHeader {...{ assignments: deleted }} />
      {#each deleted as checklist}
        <ChecklistRow
          {...{
            checklist_chevron: archive_chevron,
            checklist,
            recipient,
            handleItemPopup,
            toggleChevron: toggleArchiveChevron,
            handleAssignmentDropdownClick,
          }}
        />
      {/each}
    {:else}
      <div class="empty_state">
        <p class="empty_state_child">
          <FAIcon icon="file-alt" iconSize="2x" iconStyle="regular" />
        </p>
        <p class="empty_state_child">
          No checklists or documentation to display.
        </p>
      </div>
    {/if}
  </div>
</div>

{#if showSelectChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={assignPackage}
    on:close={() => {
      showSelectChecklistModal = false;
      assigning_for = undefined;
    }}
  />
{/if}

{#if showItemPopUp}
  <ConfirmationDialog
    title="Item Details"
    itemDisplay={itemToBeViewed}
    popUp={true}
    on:yes={() => {
      // decideView(itemToBeViewed);
    }}
    on:close={() => {
      showItemPopUp = false;
      itemToBeViewed = null;
    }}
  />
{/if}

{#if showUnsendPromt}
  <ConfirmationDialog
    question={`Are you sure you want to Unsend / Delete this Checklist from this Recipient? This action can not be reverted.`}
    yesText="Yes, Delete"
    noText="No, Keep it"
    yesColor="danger"
    noColor="gray"
    on:yes={unsendChecklist}
    on:close={() => {
      unsendThis = null;
      showUnsendPromt = false;
    }}
  />
{/if}

{#if showConfirmationDeleteFile}
  <ConfirmationDialog
    question="Are you sure you want to unsend this item? The recipient will no longer be able to complete it. This cannot be undone."
    yesText="Yes, Delete"
    noText="No, Keep It"
    yesColor="danger"
    noColor="gray"
    on:yes={() => {
      if (delete_data.target_type == "form") {
        if (delete_data.action == "delete") {
          deleteFormSubmission(delete_data.target_id)
            .then(() => {
              showToast(`Deleted successfully`, 2000, "default", "MM");
              loadActiveAndDeletedAssignments();
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
              showToast(`Unsent successfully`, 2000, "default", "MM");
              loadActiveAndDeletedAssignments();
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
      showConfirmationDeleteFile = false;
    }}
    on:close={() => {
      showConfirmationDeleteFile = false;
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

{#if showSelectChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={assignPackage}
    on:close={() => {
      showSelectChecklistModal = false;
      showChecklistActions = true;
      resetOptionsClickState();
    }}
  />
{/if}

{#if bulkUploadFiles}
  <UploadFileModal
    multiple={true}
    specializedFor="directSendRequests"
    allowAllFileTypes={true}
    on:done={processFileUploads}
    on:close={() => {
      bulkUploadFiles = false;
      resetOptionsClickState();
    }}
  />
{/if}

{#if showItemChooseOptionBox}
  <ConfirmationDialog
    title={"Choose Options"}
    hideText="Close"
    hideColor="white"
    hyperLinks={templateChooseOption}
    hyperLinksColor="black"
    on:close={(event) => {
      newRequestModal = true;
      showItemChooseOptionBox = false;
      resetOptionsClickState();
    }}
    on:hide={(event) => {
      showItemChooseOptionBox = false;
      if (event.detail) {
        const callbackHandler = event.detail.callback;
        callbackHandler();
      }
      resetOptionsClickState();
    }}
  />
{/if}

{#if showChooseTemplateModal}
  <ChooseTemplateModal
    fullScreenDisplay={true}
    on:selectionMade={processExisitingTemplateSelection}
    on:close={() => {
      showChooseTemplateModal = false;
      showItemChooseOptionBox = true;
    }}
  />
{/if}

{#if existingTemplateGuide}
  <ConfirmationDialog
    title={"Checklist"}
    responseBoxEnable={true}
    details={"Checklist Name"}
    responseBoxDemoText="checklist name"
    responseBoxText={defaultChecklistName}
    on:message={processChecklist}
    yesText="Send"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    checkBoxEnable={"enable"}
    requiresResponse={true}
    checkBoxText={"Save checklist for future use?"}
    on:close={() => {
      existingTemplateGuide = false;
      resetOptionsClickState();
    }}
    on:yes={""}
  />
{/if}

{#if showChecklistActions}
  <ConfirmationDialog
    title={"New or existing checklist"}
    hideText="Close"
    hideColor="white"
    actionsColor="black"
    actions={checklistActions}
    on:close={() => {
      showChecklistActions = false;
      newRequestModal = true;
    }}
    on:hide={() => {
      showChecklistActions = false;
      newRequestModal = true;
    }}
    on:new={() => {
      showChecklistActions = false;
      showNewChecklistActions = true;
    }}
    on:existing={() => {
      showChecklistActions = false;
      const selectedOption = options.filter(
        (option) => option.clicked === true
      )[0];
      selectedOption.callbackfunc();
    }}
  />
{/if}

{#if showNewChecklistActions}
  <ConfirmationDialog
    title={"New checklist"}
    hideText="Close"
    hideColor="white"
    actionsColor="black"
    actions={newChecklistActions}
    on:close={() => {
      showNewChecklistActions = false;
      showChecklistActions = true;
    }}
    on:hide={() => {
      showNewChecklistActions = false;
      showChecklistActions = true;
    }}
    on:futureUse={() => {
      showNewChecklistActions = false;
      window.location.hash = `#checklists/new?${encodeURIComponent(
        `${CURRENTLYSELECTEDRECIPIENT}=${recipientId}`
      )}`;
    }}
    on:oneTime={() => {
      showNewChecklistActions = false;
      window.location.hash = `#checklists/new?${encodeURIComponent(
        `${CURRENTLYSELECTEDRECIPIENT}=${recipientId}&${DOARCHIVE}=true`
      )}`;
    }}
  />
{/if}

{#if showTemplateUploadFile}
  <UploadFileModal
    multiple={false}
    requireIACwarning={true}
    specializedFor="newTemplate"
    showCheckbox={true}
    checkBoxText="Save template for future use?"
    checkBoxStatus={false}
    on:done={processNewTemplate}
    allowNonIACFileTypes={requestorTemplateNonIACExtensions}
    on:close={() => {
      showTemplateUploadFile = false;
      showItemChooseOptionBox = true;
    }}
  />
{/if}

{#if showCabinetFileReplaceUploadModal}
  <UploadFileModal
    uploadHeaderText="Replace Cabinet File"
    multiple={false}
    allowNonIACFileTypes={requestorTemplateNonIACExtensions}
    on:done={replaceCabinetFile}
    on:close={() => {
      showCabinetFileReplaceUploadModal = false;
    }}
  />
{/if}

{#if showTemplateTypeSelectionBox}
  <ConfirmationDialog
    title={"Add online form filling & signatures?"}
    hideText="Cancel"
    hideColor="white"
    hyperLinks={templateSendTypeOptions()}
    hyperLinksColor="white"
    on:close={(event) => {
      showTemplateTypeSelectionBox = false;
      resetOptionsClickState();
    }}
    on:hide={(event) => {
      showTemplateTypeSelectionBox = false;

      if (event.detail) {
        const callbackHandler = event.detail.callback;
        callbackHandler();
      }
      resetOptionsClickState();
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
    question={`Please enter a note for your reminder, if the note is not changed it will send the default one to the recipient.`}
    responseBoxEnable="true"
    responseBoxText="Please complete this as soon as possible, Thanks!"
    responseBoxDemoText="Enter reminder note here"
    showReminderInfo={true}
    lastReminderInfo={reminderInfo}
    yesText="Send"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    on:message={handleRemindMessage}
    on:yes={ifConfirmed}
    on:close={() => {
      showConfirmationDialog = false;
    }}
  />
{/if}

{#if showUploadModal}
  <UploadFileModal
    specializedFor={manualUploadData.type == "document"
      ? "none"
      : manualUploadData.type == "file"
      ? "file"
      : "cabinet"}
    multiple={false}
    allowNonIACFileTypes={requestorTemplateNonIACExtensions}
    on:done={(evt) => {
      if (manualUploadData.type == "document") {
        templateManualUpload(
          manualUploadData.assignId,
          manualUploadData.id,
          evt.detail.file
        ).then(() => {
          // hide the modal
          showUploadModal = false;
          loadAssignment();
          loadArchive();
        });
      } else if (manualUploadData.type == "file") {
        fileRequestManualUpload(
          manualUploadData.assignId,
          manualUploadData.id,
          evt.detail.file
        ).then(() => {
          // hide the modal
          showUploadModal = false;
          loadAssignment();
          loadArchive();
        });
      } else uploadCabinet(evt);
    }}
    on:close={() => {
      showUploadModal = false;
    }}
  />
{/if}

{#if newRequestModal}
  <Modal
    on:close={() => {
      newRequestModal = false;
    }}
  >
    <div
      style="display: flex;
    flex-direction: column;
    align-items: center;"
    >
      <span class="modal-header"> Send New Request </span>
      <span style="min-width: 350px;">
        {#each options as Link, i}
          {#if i < 4}
            <span
              on:click={() => {
                onSelectOption(Link);
                newRequestModal = false;
              }}
            >
              <span class="inner-space">
                <Button
                  icon={Link?.icon}
                  color={optionsColor}
                  text={Link?.title}
                  halfWidth={false}
                  iconLocation="floatLeft"
                  floatLeft={true}
                  style="display: flex; text-align: left;"
                />
              </span>
            </span>
            <br />
          {/if}
        {/each}
      </span>
      <span
        style="width:25%;"
        on:click={() => {
          newRequestModal = false;
        }}
      >
        <Button color={optionsColor} text={"Close"} halfWidth={false} />
      </span>
    </div>
  </Modal>
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

<style>
  .modal-header {
    width: 100%;
    font-family: sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    margin-bottom: 0.5rem;
  }

  * {
    box-sizing: border-box;
  }

  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 0 auto;
  }

  .table {
    /* padding-top: 2rem; */
    padding-top: 1rem;
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    width: 100%;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .header h3 {
    font-size: 18px;
    line-height: 28px;
    margin: 1rem 0;
    font-family: "Lato", sans-serif;
  }
  .cabinet {
    padding-top: 2rem;
  }

  .empty_state {
    position: relative;
    top: -20px;
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
  }

  .empty_state_child {
    font-size: 14px;
    margin: 0px;
    color: #999;
    text-align: center;
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
  @media only screen and (max-width: 767px) {
    .header h3 {
      font-size: 18px;
      line-height: 20px;
      margin: 1rem 0;
    }
  }
</style>
