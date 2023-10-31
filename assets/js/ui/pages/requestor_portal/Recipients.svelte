<script>
  import { add_contact_modal } from "./../../../store";
  import Button from "../../atomic/Button.svelte";
  import ChooseChecklistModal from "../../modals/ChooseChecklistModal.svelte";
  import ImportContactsFromFile from "../../modals/ImportContactsFromFile.svelte";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import AddNewContact from "../../components/Requestor/AddNewContact.svelte";
  import TablePager from "Components/TablePager.svelte";
  import Dropdown from "../../components/Dropdown.svelte";
  import Modal from "../../modals/Modal.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import ChooseTemplateModal from "../../modals/ChooseTemplateModal.svelte";
  import AddNewContactModal from "../../modals/AddNewContactModal.svelte";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import RecipientMobileView from "../../components/Recipient/RecipientMobileView.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import EmptyDefault from "../../util/EmptyDefault.svelte";
  import Loader from "../../components/Loader.svelte";
  import Switch from "../../components/Switch.svelte";
  import TableSorter from "../../components/TableSorter.svelte";
  import {
    newRecipient,
    deleteRecipient,
    getRecipients,
    getRecipientsPaginated,
    SORT_FIELDS,
    RECIPIENT_DROPDOWN_ACTIONS,
    recipientRestore,
    getRecipient,
  } from "BoilerplateAPI/Recipient";
  import { assignContents } from "BoilerplateAPI/Assignment";
  import { showErrorMessage } from "Helpers/Error";
  import { uploadCabinet } from "BoilerplateAPI/Cabinet";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import { debounce, setLocalStorage, getLocalStorage } from "Helpers/util";
  import {
    unHideRecipient,
    SHOW_DELETED_RECIPIENT_KEY,
  } from "../../../api/Recipient";
  import { checkIfExists } from "../../../api/User";
  import {
    directSendTemplates,
    directSendChecklist,
  } from "../../../api/Template.js";
  import {
    createAndSendChecklist,
    requires_iac_fill,
  } from "../../../api/TemplateGuide.js";
  import { onMount } from "svelte";
  import { DELETECONFIRMATIONTEXT } from "../../../constants";
  import AddNewGoogleContact from "../../modals/AddNewGoogleContact.svelte";
  import Tag from "Atomic/Tag";
  let showAddNewGoogleContact = false;
  let search_value = "";
  let showSelectChecklistModal = false;
  let showSelectChecklistModalForBulk = false;
  let showSelectChecklistAfterBulkImportModal = false;
  let showUserGuideOption = false;
  let showNewUserGuideOption = false;
  let showNewUserSubGuideOption = false;
  let showDirectSendUpload = false;
  let showCabinetUploadModal = false;
  let cabinetRecipientId = undefined;
  let assigning_for = undefined;
  let showInDashboardConfirmationBox = false;
  let enableRecipientDashboard = -1;
  let checkedRecipients = [];
  let showHeaderBtn = true;
  let showBulkSendBtn = true;
  let showActiveElements = false;
  let zindex;
  let recipientRowClass = "recipient-td action";
  let showConfirmSendChecklistDialog = false;
  let ConfirmSendChecklistButtonFlag = false;
  let showBulkAssignConfirmationBox = false;
  let showConfirmDialogForImportedContacts = false;
  let checklistId = undefined;
  let oldRecipients;
  $: if (showActiveElements) {
    zindex = 999;
    recipientRowClass = "recipient-td active";
  } else {
    zindex = 12;
    recipientRowClass = "recipient-td action";
  }
  $: console.log(checkedRecipients);
  let showImportContactsFromFileBox = false;
  let recipients = Promise.resolve([]);
  let recipientLength = 0;
  let actions = [
    { evt: "send", description: "Send files/ request", icon: "plane" },
    { evt: "add", description: "Add internal files", icon: "cabinet-filing" },
    { evt: "edit", description: "Edit", icon: "info-circle" },
  ];
  let tagsSelected = [];

  let subActions = [
    {
      evt: "checklists",
      description: "Saved checklist",
      icon: "clipboard-list",
    },
    {
      evt: "file",
      description: "File only (no response)",
      icon: "file-upload",
    },
    { evt: "request", description: "Single request", icon: "copy" },
  ];
  let checkStatusNewUserGuideOption;
  let submitClicked = false;

  async function unHideContact() {
    showInDashboardConfirmationBox = false;
    let reply = await unHideRecipient(enableRecipientDashboard);
    if (reply.ok) {
      search_value = "";
      loadRecipientData();
    }
  }
  async function handleBulkSend() {
    await recipients.then((recps) => {
      // https://bugs.internal.boilerplate.co/issues/10451
      // I'm not sure why this is here. - Lev
      if (false && recps.length < 2) {
        showToast(
          "To Bulk Send, you need to choose at least two contacts. Please select more and try again.",
          2000,
          "error",
          "BM"
        );
        return;
      }
      showActiveElements = true;
      showHeaderBtn = false;
      showBulkSendBtn = false;
    });
  }
  function handleSendAssign() {
    if (checkedRecipients.length <= 1) {
      showToast("Please select more than one contact!", 3000, "error", "MM");
      return;
    }
    showActiveElements = false;
    showHeaderBtn = true;
    showBulkSendBtn = !showBulkSendBtn;
    showSelectChecklistModalForBulk = true;
    assigning_for = checkedRecipients;
  }

  function handleCheckRecipient(recp) {
    const recpIndex = checkedRecipients.findIndex(
      (crecp) => crecp.id === recp.id
    );
    if (recpIndex == -1) checkedRecipients = [...checkedRecipients, recp];
    else
      checkedRecipients = [
        ...checkedRecipients.slice(0, recpIndex),
        ...checkedRecipients.slice(recpIndex + 1),
      ];

    console.log({ recp, recpIndex, checkedRecipients });
    assigning_for = recp;
    const alreadyChecked =
      checkedRecipients.find((crecp) => crecp.id === recp.id) || false;
    if (
      !alreadyChecked &&
      recp.deleted &&
      !hideRecipientDeleteConfirmationStatus
    ) {
      handleRecipientDeletedClick(true);
      return;
    }

    //handleBulkSelect();
  }

  function getRecipientActions(recipientRow, allowDetails) {
    // TODO: allow dropdown order by the key rather than order of array
    let commonActions = [
      {
        text: "Assign",
        icon: "address-book",
        iconStyle: "solid",
        ret: RECIPIENT_DROPDOWN_ACTIONS.ASSIGN,
      },
      {
        text: "Send new request",
        icon: "inbox-out",
        iconStyle: "solid",
        ret: RECIPIENT_DROPDOWN_ACTIONS.SEND_NEW_REQUEST,
      },
      {
        text: "Details / Edit",
        icon: "info-circle",
        iconStyle: "solid",
        ret: RECIPIENT_DROPDOWN_ACTIONS.DETAILS,
        disabled: !allowDetails,
      },
      {
        text: "View Documents",
        icon: "eye",
        iconStyle: "solid",
        ret: RECIPIENT_DROPDOWN_ACTIONS.VIEW_DOCUMENTS,
      },
      {
        text: "Add to Filing Cabinet",
        icon: "cabinet-filing",
        iconStyle: "solid",
        ret: RECIPIENT_DROPDOWN_ACTIONS.ADD_FILE_CABINET,
      },
    ];

    if (recipientRow.deleted) {
      return [
        ...commonActions,
        {
          text: "Restore",
          icon: "trash-can-arrow-up",
          iconStyle: "solid",
          ret: RECIPIENT_DROPDOWN_ACTIONS.RESTORE,
        },
      ];
    }

    if (!recipientRow.show_in_dashboard) {
      let x = [
        ...commonActions,
        {
          text: "Show in Dashboard",
          icon: "eye",
          iconStyle: "solid",
          ret: RECIPIENT_DROPDOWN_ACTIONS.SHOW_IN_DASHBOARD,
        },
        {
          text: "Delete",
          icon: "trash",
          iconStyle: "solid",
          ret: RECIPIENT_DROPDOWN_ACTIONS.DELETE,
        },
      ];
      console.log(x);
      return x;
    }
    return [
      ...commonActions,
      !recipientRow.deleted && {
        text: "Delete",
        icon: "trash",
        iconStyle: "solid",
        ret: RECIPIENT_DROPDOWN_ACTIONS.DELETE,
      },
    ];
  }
  let newR = {
    name: "",
    organization: "",
    company_id: 0,
    email: "",
    newRecipientFirstName: "",
    newRecipientLastName: "",
    phone_number: "",
    start_date: "",
    tags: [],
  };

  let newContactObj = null;
  let newContactId;
  let showConfirmationDialog = false;
  let showChooseTemplateModal = false;
  let existingTemplateGuide = false;
  let recipientToBeDeleted = undefined;

  async function tryDeleteRecipient(event, recipient, confirmed) {
    const { text: deleteTextMessage } = event.detail;
    if (DELETECONFIRMATIONTEXT != deleteTextMessage.toLowerCase()) {
      showToast(`Please type ${DELETECONFIRMATIONTEXT}!`, 1000, "error", "MM");
      return;
    }

    let reply = await deleteRecipient(recipient.id);
    if (reply.ok) {
      search_value = "";
      showToast(`Success! Contact deleted.`, 1500, "default", "MM");
      showConfirmationDialog = false;
      loadRecipientData();
    } else {
      let error = await reply.json();
      showErrorMessage("recipient", error.error);
      showConfirmationDialog = false;
    }
  }

  const userGuideOptions = [
    {
      title: "Send Existing Checklist",
      callback: () => (showSelectChecklistModal = true),
      icon: "clipboard-list",
    },
    {
      title: "Single Template",
      callback: () => (showChooseTemplateModal = true),
      icon: "paper-plane",
    },
    {
      title: "Securely send files, no return action",
      callback: () => (showDirectSendUpload = true),
      icon: "file-upload",
    },
  ];
  async function processFileUploads(evt) {
    let { name, file } = evt.detail;
    let reply = await directSendTemplates(name, file, assigning_for.id);
    showDirectSendUpload = false;
    loadRecipientData(page);
    if (reply.ok) {
      showToast("Send Files Successfully", 1000, "default", "MM");
    } else {
      showToast(
        "Something went wrong while Sending the files",
        1000,
        "error",
        "MM"
      );
    }
  }
  function dropdownClick(recipient, actionId) {
    switch (actionId) {
      case RECIPIENT_DROPDOWN_ACTIONS.DETAILS:
        window.location.hash = `#recipient/${recipient.id}/details/user`;
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.DELETE:
        recipientToBeDeleted = recipient;
        showConfirmationDialog = true;
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.ADD_FILE_CABINET:
        cabinetRecipientId = recipient.id;
        showCabinetUploadModal = true;
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.SHOW_IN_DASHBOARD:
        showInDashboardConfirmationBox = true;
        enableRecipientDashboard = recipient.id;
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.VIEW_DOCUMENTS:
        window.location.hash = `#recipient/${recipient.id}`;
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.SEND_NEW_REQUEST:
        if (!showActiveElements) {
          assigning_for = recipient;
        } else {
          //if it is bulk selection make a selection
          //checking duplication
          if (checkedRecipients.some((rcp) => rcp.id === recipient.id)) {
            checkedRecipients = checkedRecipients.filter(
              (rcp) => rcp.id !== recipient.id
            );
          } else {
            checkedRecipients = [...checkedRecipients, recipient];
          }
        }
        showUserGuideOption = true;
        assigning_for = recipient;
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.ASSIGN:
        if (!showActiveElements) {
          showSelectChecklistModal = true;
          assigning_for = recipient;
        } else {
          //if it is bulk selection make a selection
          //checking duplication
          if (checkedRecipients.some((rcp) => rcp.id === recipient.id)) {
            checkedRecipients = checkedRecipients.filter(
              (rcp) => rcp.id !== recipient.id
            );
          } else {
            checkedRecipients = [...checkedRecipients, recipient];
          }
        }
        break;
      case RECIPIENT_DROPDOWN_ACTIONS.RESTORE:
        newContactId = recipient.id;
        handleRecipientRestoration();
        break;

      default:
        alert(`${recipient.name} -> ${actionId}`);
        break;
    }
  }

  let showDeleteRestoreModal = false;
  const handleRecipientRestoration = async () => {
    const recp = await getRecipient(newContactId);
    const restored = await handleRecipientRestore(recp);
    if (restored) {
      showDeleteRestoreModal = false;
      resetAddContactModal();
      assigning_for = recp;
      newContactObj = Object.assign({}, recp);
      if (newContactId) {
        showNewUserGuideOption = true;
      }
    }
  };

  const resetAddContactModal = () => {
    search_value = "";
    Object.keys(newR).forEach((key) => {
      if (key === "tags") {
        newR[key] = [];
      } else {
        newR[key] = "";
      }
    });
    $add_contact_modal = false;
  };

  async function submitRecipient() {
    /* collect the data we need */
    newR.name = `${newR.newRecipientFirstName} ${newR.newRecipientLastName}`;
    newR.start_date = new Date(newR.start_date);
    checkStatusNewUserGuideOption = JSON.parse(
      localStorage.getItem("dontShowNewUserGuideOption")
    );
    newR.tags = tagsSelected.map((x) => x.id);

    /* submit the information */
    let reply = await newRecipient(newR);
    if (reply.ok) {
      loadRecipientData();
      newContactObj = Object.assign({}, newR);
      // reset the values of the object
      resetAddContactModal();

      reply.json().then((response) => {
        newContactId = response?.id;
        assigning_for = response;
        if (newContactId) {
          showNewUserGuideOption = true;
        }
      });
      submitClicked = false;
      return true;
    } else {
      if (reply.status === 400) {
        const { error, is_deleted, id } = await reply.json();
        const alreadyExists = error === "already_exists";
        if (alreadyExists && is_deleted) {
          newContactId = id;
          showDeleteRestoreModal = true;
        } else showToast("User already exists", 1000, "default", "MM");
        search_value = newR.email;
        submitClicked = false;
      }
    }
  }
  const handleSubmitChecklist = async () => {
    let promises = [];
    checkedRecipients.forEach((rec) => {
      let contentsPromise = loadContents(rec.id, checklistId);
      promises = [...promises, contentsPromise];
    });
    await Promise.all(promises)
      .then((promises) => {
        promises.forEach(async (promise, i) => {
          let reply = await assignContents(promise);
          if (reply.ok) {
            showConfirmSendChecklistDialog = false;
            ConfirmSendChecklistButtonFlag = false;
            checkedRecipients = [];
            showToast(
              `Success! Checklist sent. The other party will receive a link in an email to complete the checklist. If you need to unsend or delete this request, go to the dashboard, find the request, then click the unsend button on the hamburger menu on the right.`,
              3000,
              "white",
              "MM"
            );
          }
        });
      })
      .catch((error) => alert("Something wrong: ", error.message));
    showSelectChecklistModalForBulk = false;
  };

  const handleSubmitChecklistBulkImport = async () => {
    let recipients = await getRecipients();
    let ids = await oldRecipients();

    //we need to remove the old recipients we only need the fresh imported list
    let filteredRecipients = recipients.filter((item) => {
      if (!ids.includes(item.id)) {
        return true;
      }
    });

    //now assign it to the recipients

    let promises = [];
    filteredRecipients.forEach((rec) => {
      let contentsPromise = loadContents(rec.id, checklistId);
      promises = [...promises, contentsPromise];
    });
    await Promise.all(promises)
      .then((promises) => {
        promises.forEach(async (promise, i) => {
          let reply = await assignContents(promise);
          if (reply.ok) {
            showConfirmDialogForImportedContacts = false;
            showToast(
              `Success! Checklist sent. The other party will receive a link in an email to complete the checklist. If you need to unsend or delete this request, go to the dashboard, find the request, then click the unsend button on the hamburger menu on the right.`,
              3000,
              "white",
              "MM"
            );
            window.location = "/n/requestor#dashboard";
          }
        });
      })
      .catch((error) => alert("Something wrong: ", error.message));
  };
  //stolen from recipientAssign.svelte
  const loadContents = async (recipientId, checklistId) => {
    return getContents(recipientId, checklistId).then(async (c) => {
      return c;
    });
  };
  const getContents = async (recipientId, checklistId) => {
    let request = await fetch(
      `/n/api/v1/contents/${recipientId}/${checklistId}`
    );
    if (request.ok) {
      // If the request was OK, then a contents was found.
      let assignments = await request.json();
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
        let new_contents = await request.json();
        return new_contents;
      } else {
        alert("Failed to create a new Contents object for this assignment");
      }
    } else {
      alert("A fatal, unexpected error occured while fetching Contents");
    }
  };
  const setChecklistId = (event) => {
    let detail = event.detail;
    let packageId = detail.checklistId;
    checklistId = packageId;
  };
  function assignPackage(evt) {
    let detail = evt.detail;
    let packageId = detail.checklistId;
    if (Array.isArray(assigning_for)) {
      const idArr = assigning_for.map((item) => item.id);
      const joinedIds = idArr.join("");
      window.location.hash = `#recipient/${joinedIds}/assign/${packageId}`;
    } else {
      window.location.hash = `#recipient/${assigning_for.id}/assign/${packageId}`;
    }
  }
  let scrollY;

  function searchContact() {
    checkIfExists(newR.email).then(({ exists }) => {
      if (exists) search_value = newR.email;
      else search_value = "";
      loadRecipientData();
    });
  }
  const handleEmailEntered = debounce(() => searchContact());

  // pagination stuff
  let page = 1;
  let totalPages = 1;
  let recipientsData = [];
  let hasNext = false;
  let loading = true;
  let sort = SORT_FIELDS.NAME;
  let sortDirection = "asc";

  const loadRecipientData = async (targetPage = 1) => {
    loading = true;
    try {
      const params = {
        page: targetPage,
        search: search_value || "",
        sort,
        sort_direction: sortDirection,
        show_deleted_recipients,
      };

      const res = await getRecipientsPaginated(params);

      page = res.page;
      recipientsData = res.data;
      totalPages = res.total_pages;
      hasNext = res.has_next;
      recipientLength = res.count;
    } catch (err) {
      console.error(err);
      page = 1;
      totalPages = 1;
      recipientsData = [];
      hasNext = false;
      recipientLength = 0;
    }
    loading = false;
    checkedRecipients = checkedRecipients;
  };

  const handleNextPage = () => {
    if (hasNext) loadRecipientData(page + 1);
  };

  const handlePrevPage = () => {
    if (page > 1) loadRecipientData(page - 1);
  };

  const handleServerSearch = () => {
    loadRecipientData();
  };

  const sortRecipientData = (_targetSort = "name") => {
    // direction change
    if (sort === _targetSort)
      sortDirection = sortDirection === "asc" ? "desc" : "asc";
    else {
      // sort change
      sort = _targetSort;
      sortDirection = "asc";
    }

    loadRecipientData();
  };

  onMount(async () => {
    firstLoad = false;
    try {
      await loadRecipientData();
    } catch (err) {
      console.error(err);
    }
  });
  // pagination stuff
  let showChecklistModal = false;

  const assignPackageForNewContact = (evt) => {
    let detail = evt.detail;
    let packageId = detail.checklistId;
    window.location.hash = `#recipient/${newContactId}/assign/${packageId}`;
  };

  let selectedTemplates, defaultChecklistName;
  async function processExisitingTemplateSelection(evt) {
    selectedTemplates = evt.detail.templates;
    defaultChecklistName = selectedTemplates[0].name;
    showUserGuideOption = false;
    showChooseTemplateModal = false;
    existingTemplateGuide = true;
  }

  async function processChecklist(event) {
    existingTemplateGuide = false;
    showUserGuideOption = false;
    const createdchecklist = await createAndSendChecklist(
      event.detail,
      selectedTemplates
    );
    if (createdchecklist.ok) {
      handleChecklistCreated(createdchecklist?.id);
    }
  }

  async function handleChecklistCreated(checklistId) {
    if (requires_iac_fill(selectedTemplates)) {
      window.location.hash = `#recipient/${assigning_for.id}/assign/${checklistId}`;
    } else {
      let reply = await directSendChecklist(checklistId, assigning_for.id);
      loadRecipientData(page);
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
    showChooseTemplateModal = false;
    assigning_for.id = null;
  }

  let showRecipientDeleteConfirmation = false;
  let sendToDeletedContact = false;
  const SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY =
    "dontShowRecipientDeleteConfirmation";
  let hideRecipientDeleteConfirmationStatus = JSON.parse(
    localStorage.getItem(SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY)
  );
  let bulkSendConfirmation = false;

  const assignAndSend = () => {
    showUserGuideOption = true;
  };

  const handleRecipientDeletedClick = (bulkSend = false) => {
    bulkSendConfirmation = bulkSend;
    showRecipientDeleteConfirmation = true;
  };

  // Note: Dont know what the function does here
  const handleRecipientDeleteConfirmation = () => {
    sendToDeletedContact = true;
    showRecipientDeleteConfirmation = false;
    if (bulkSendConfirmation) {
      handleBulkSelect(assigning_for);
      return;
    }
    assignAndSend();
  };
  const handleBulkSelect = () => {
    const recp = assigning_for;
    assigning_for = undefined;
    const recpIndex = checkedRecipients.findIndex(
      (crecp) => crecp.id === recp.id
    );
    if (recpIndex == -1) checkedRecipients = [...checkedRecipients, recp];
    else
      checkedRecipients = [
        ...checkedRecipients.slice(0, recpIndex),
        ...checkedRecipients.slice(recpIndex + 1),
      ];
    console.log({ msg: "handleBulkSelect", recpIndex, checkedRecipients });
  };

  let showDeletedVal = getLocalStorage(SHOW_DELETED_RECIPIENT_KEY);
  let show_deleted_recipients = getLocalStorage(SHOW_DELETED_RECIPIENT_KEY);
  let firstLoad = true;
  const handleShowDelete = (show) => {
    if (firstLoad) return;
    setLocalStorage(SHOW_DELETED_RECIPIENT_KEY, show);
    show_deleted_recipients = show;
    loadRecipientData();
  };

  $: handleShowDelete(showDeletedVal);
  const handleRecipientRestore = async (recp) => {
    try {
      const reply = await recipientRestore(recp.id);
      if (!reply.ok) throw new Error("Unknown Error");
      loadRecipientData(page);
      return true;
    } catch (err) {
      console.error(err);
      alert("Error occured while restoring Contact Id:", recp.id);
      return false;
    }
  };
</script>

<svelte:window
  bind:scrollY
  on:keydown={(evt) => {
    if (evt.key == "Escape") {
      showActiveElements = false;
      showHeaderBtn = true;
      showBulkSendBtn = true;
    }
  }}
/>
{#if showActiveElements}
  <div
    class="shadow-background"
    on:click|self={() => {
      zindex = 12;
      showActiveElements = false;
      showHeaderBtn = true;
      showBulkSendBtn = true;
      if (checkedRecipients.length != 0) checkedRecipients = [];
    }}
  />
{/if}

<!-- <BackgroundPageHeader {scrollY} /> -->

<div class="page-header" style="z-index: {zindex + 1}">
  <RequestorHeaderNew
    title="Contacts"
    contactCount={recipientLength}
    icon="address-book"
    bind:search_value
    enable_search_bar={!showActiveElements}
    searchPlaceholder="Search Contacts"
    headerBtn={false}
    bulkSendBtn={showBulkSendBtn}
    bulkSendBtnIcon="paper-plane"
    showSendAssignsBtn={!showBulkSendBtn}
    sendAssignsBtnDisabled={checkedRecipients.length <= 1}
    btnText="Add New Contact"
    showCsvUploadBtn={true}
    uploadBtnText="Bulk Import"
    uploadBtnDisabled={!showBulkSendBtn}
    uploadBtnIcon="upload"
    uploadBtnAction={() => {
      showImportContactsFromFileBox = true;
    }}
    useDropdown={true}
    dropdownClickHandler={(ret) => {
      if (ret == "new") {
        $add_contact_modal = true;
      } else if (ret == "google_import") {
        showAddNewGoogleContact = true;
      }
    }}
    btnAction={() => {
      $add_contact_modal = true;
    }}
    bulkSendBtnAction={handleBulkSend}
    sendAssignsBtnAction={handleSendAssign}
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

{#if $add_contact_modal}
  <AddNewContactModal
    on:close={() => {
      $add_contact_modal = false;
    }}
  >
    <span style="font-weight: bold; margin-bottom: 0.5rem; color: #76808B">
      To show previously deleted contacts, go to Contacts tab and switch 'show
      deleted contacts'.
    </span>
    <div style="margin-top: 5px;">
      <AddNewContact
        bind:newR
        on:keyPressed={handleEmailEntered}
        recps={recipientsData}
        on:submit={submitRecipient}
        on:cancel={() => {
          $add_contact_modal = false;
        }}
        bind:tagsSelected
        bind:submitClicked
      />
    </div>
  </AddNewContactModal>
{/if}

{#if loading}
  <span class="loader-container">
    <Loader loading />
  </span>
{:else}
  <div>
    <section class="recipient-main">
      <div class="recipient-table" style="z-index: {zindex};">
        {#if recipientsData.length}
          <div class="recipient-tr recipient-th desktop-only">
            <div class="recipient-td details" style="flex-grow: 2;">
              <div
                class="sortable"
                class:selectedBorder={sort == SORT_FIELDS.NAME}
                style="display: flex;
                  align-items: center;"
                on:click={() => {
                  sortRecipientData();
                }}
              >
                &nbsp; Name &nbsp;
                <TableSorter column={SORT_FIELDS.NAME} {sort} {sortDirection} />
                &nbsp;
              </div>
              <div
                class="sortable"
                class:selectedBorder={sort == SORT_FIELDS.COMPANY}
                style="display: flex;
                  align-items: center;"
                on:click={() => {
                  sortRecipientData(SORT_FIELDS.COMPANY);
                }}
              >
                &nbsp; Org &nbsp;
                <TableSorter
                  column={SORT_FIELDS.COMPANY}
                  {sort}
                  {sortDirection}
                />
                &nbsp;
              </div>
              <div
                class="sortable {sort == SORT_FIELDS.EMAIL
                  ? 'selectedBorder'
                  : ''}"
                style="display: flex;
                  align-items: center;"
                on:click={() => {
                  sortRecipientData(SORT_FIELDS.EMAIL);
                }}
              >
                &nbsp; Email &nbsp;
                <TableSorter
                  column={SORT_FIELDS.EMAIL}
                  {sort}
                  {sortDirection}
                />
                &nbsp;
              </div>
            </div>
            <div class="recipient-td date">
              <div
                class="sortable {sort == SORT_FIELDS.DATE_ADDED
                  ? 'selectedBorder'
                  : ''}"
                style="display: flex;
                  align-items: center;"
                on:click={() => {
                  sortRecipientData(SORT_FIELDS.DATE_ADDED);
                }}
              >
                &nbsp; Date Added &nbsp;
                <TableSorter
                  column={SORT_FIELDS.DATE_ADDED}
                  {sort}
                  {sortDirection}
                />
                &nbsp;
              </div>
            </div>
          </div>
          {#each recipientsData as recp, index}
            {#if recp.name}
              <div
                on:click={() => {
                  if (showActiveElements) {
                    handleCheckRecipient(recp);
                  }
                  showBulkSendBtn
                    ? (window.location.hash = `#recipient/${recp.id}/details/user`)
                    : "";
                }}
                class="recipient-tr desktop-only"
                class:recipient-deleted={recp.deleted}
              >
                <div class="flexContainer">
                  <span style="display: flex; align-items: center; width: 100%">
                    {#if showActiveElements}
                      <label for={index}>
                        <span>
                          {#if checkedRecipients.find((crecp) => crecp.id === recp.id) || false}
                            <FAIcon icon="check-square" iconStyle="solid" />
                          {:else}
                            <FAIcon icon="square" iconStyle="regular" />
                          {/if}
                        </span>
                      </label>
                    {/if}
                    <div
                      class="recipient-td clickable details"
                      style="flex-grow: 2; display: flex; justify-content: flex-start;"
                    >
                      <div class="name-company-email">
                        <div class="name-company">
                          <div class="name">
                            {recp.name}
                            {#if recp.company && recp.company != "" && recp.company != " "}
                              <span style="margin-left: 0.5rem"
                                >({recp.company})</span
                              >
                            {/if}
                          </div>
                        </div>

                        <div class="email">{recp.email}</div>
                        {#if recp.tags}
                          <ul class="reset-style">
                            {#each recp.tags.values as tag}
                              <Tag
                                isSmall={true}
                                {tag}
                                allowDeleteTags={false}
                              />
                            {/each}
                          </ul>
                        {/if}
                      </div>
                    </div>
                  </span>
                </div>
                <div style="margin-left: 14px;" class="recipient-td date">
                  <span>{recp.added}</span>
                </div>
                <div class={recipientRowClass}>
                  <!-- action for desktop -->
                  {#if !showActiveElements}
                    <span
                      on:click|stopPropagation={() => {
                        assigning_for = recp;
                        if (
                          recp.deleted &&
                          !hideRecipientDeleteConfirmationStatus
                        ) {
                          handleRecipientDeletedClick();
                          return;
                        }
                        assignAndSend();
                      }}
                      class="recipient-action-desktop"
                    >
                      <Button text="Assign / Send" />
                    </span>
                  {/if}
                  <span class="recipient-action-dropdown-desktop">
                    <Dropdown
                      elements={getRecipientActions(recp, true)}
                      clickHandler={(ret) => {
                        dropdownClick(recp, ret);
                      }}
                      triggerType="vellipsis"
                    />
                  </span>
                </div>
              </div>

              <span class="mobile-only">
                {#if index == 0}
                  <div class="action-icon add-btn button-container">
                    <div>
                      <Switch
                        bind:checked={showDeletedVal}
                        text="Show Deleted"
                        marginBottom={false}
                      />
                    </div>
                    {#if !showActiveElements}
                      <span on:click={handleBulkSend}>
                        <Button
                          color="white"
                          icon="paper-plane"
                          text="Bulk Send"
                        />
                      </span>
                    {/if}

                    {#if !showBulkSendBtn}
                      <div class="action-icon add-btn">
                        <span on:click={handleSendAssign}>
                          <Button
                            color="secondary"
                            text="Assign / Send"
                            disabled={checkedRecipients.length <= 1}
                          />
                        </span>
                      </div>
                    {/if}
                  </div>

                  <div class="mobile-sort-container">
                    <div
                      class="sortable sortable-item {sort == SORT_FIELDS.NAME
                        ? 'selectedBorder'
                        : ''}"
                      on:click={() => {
                        sortRecipientData();
                      }}
                    >
                      &nbsp; Name &nbsp;
                      <TableSorter
                        column={SORT_FIELDS.NAME}
                        {sort}
                        {sortDirection}
                      />
                      &nbsp;
                    </div>
                    <div
                      class="sortable sortable-item {sort == SORT_FIELDS.COMPANY
                        ? 'selectedBorder'
                        : ''}"
                      on:click={() => {
                        sortRecipientData(SORT_FIELDS.COMPANY);
                      }}
                    >
                      &nbsp; Org &nbsp;
                      <TableSorter
                        column={SORT_FIELDS.COMPANY}
                        {sort}
                        {sortDirection}
                      />
                      &nbsp;
                    </div>
                  </div>
                {/if}
                <RecipientMobileView
                  data={recp}
                  dropdownElement={getRecipientActions(recp)}
                  {dropdownClick}
                  {showActiveElements}
                  {checkedRecipients}
                  on:assignRecipient={() => {
                    assigning_for = recp;
                    if (
                      recp.deleted &&
                      !hideRecipientDeleteConfirmationStatus
                    ) {
                      handleRecipientDeletedClick();
                      return;
                    }
                    assignAndSend();
                  }}
                  on:handleCheckedRecipients={({ detail: { recp } }) => {
                    handleCheckRecipient(recp);
                  }}
                />
              </span>
            {/if}
          {/each}
          <TablePager {page} {totalPages} {handleNextPage} {handlePrevPage} />
        {:else if search_value != "" && !recipientsData.length}
          <EmptyDefault
            cancelButton={true}
            defaultHeader="No Search results!"
            defaultMessage="No results for this search on this screen"
            on:close={() => {
              search_value = "";
              loadRecipientData();
            }}
          />
        {:else}
          <EmptyDefault
            defaultHeader="No Contacts found!"
            defaultMessage="You have not added any contacts, start now by hitting Add New Contacts"
          />
        {/if}
      </div>
    </section>
  </div>
{/if}

{#if showCabinetUploadModal}
  <UploadFileModal
    specializedFor="cabinet"
    multiple={false}
    on:done={(evt) => {
      uploadCabinet(evt.detail, cabinetRecipientId)
        .then(() => {
          showCabinetUploadModal = false;
        })
        .then(() => {
          showToast(
            "Success! Uploaded to the recipient's cabinet.",
            1500,
            "default",
            "BM"
          );
        });
    }}
    on:close={() => {
      showCabinetUploadModal = false;
    }}
  />
{/if}

<!--For Bulk Assignment-->
{#if showSelectChecklistModalForBulk}
  <ChooseChecklistModal
    on:selectionMade={(event) => {
      showConfirmSendChecklistDialog = true;
      setChecklistId(event);
    }}
    on:close={() => {
      showSelectChecklistModalForBulk = false;
    }}
    instructions="Checklists with contact-specific templates cannot be sent using bulk send and appear grayed out. You can see which templates are contact-specific by going to the Templates tab."
    disableRSDsChecklists={true}
  />
{/if}

<!--For Single Assignment-->
{#if showSelectChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={assignPackage}
    on:close={() => {
      showSelectChecklistModal = false;
      assigning_for = undefined;
    }}
  />
{/if}

<!-- For Bulk Assignment after bulk import-->
{#if showSelectChecklistAfterBulkImportModal}
  <ChooseChecklistModal
    on:selectionMade={(event) => {
      setChecklistId(event);
      showConfirmDialogForImportedContacts = true;
    }}
    on:close={() => {
      showSelectChecklistAfterBulkImportModal = false;
    }}
    disableRSDsChecklists={true}
  />
{/if}

<!-- Confirmation after bulk import to bulk assign the imported list-->
{#if showBulkAssignConfirmationBox}
  <ConfirmationDialog
    question={`Do you want to send a checklist to the entire imported list?`}
    yesText="Yes"
    noText="No"
    yesColor="secondary"
    noColor="gray"
    on:yes={() => {
      showBulkAssignConfirmationBox = false;
      showSelectChecklistAfterBulkImportModal = true;
    }}
    on:close={() => {
      showBulkAssignConfirmationBox = false;
    }}
  />
{/if}

{#if showConfirmDialogForImportedContacts}
  <ConfirmationDialog
    title={"Confirmation"}
    details={"Do you want to send the same checklist to the imported contacts?"}
    yesText="Send"
    noText="Cancel Send"
    yesColor="primary"
    noColor="gray"
    on:yes={handleSubmitChecklistBulkImport}
    on:close={() => {
      showConfirmDialogForImportedContacts = false;
    }}
  />
{/if}

{#if showDirectSendUpload}
  <UploadFileModal
    multiple={true}
    specializedFor="directSendRequests"
    allowAllFileTypes={true}
    on:done={processFileUploads}
    on:close={() => {
      showDirectSendUpload = false;
    }}
  />
{/if}

{#if showConfirmSendChecklistDialog}
  <ConfirmationDialog
    title={"Confirmation"}
    details={"Do you want to send the same checklist to the selected contacts?"}
    yesText="Send"
    noText="Cancel Send"
    yesColor="primary"
    noColor="gray"
    on:yes={() => {
      if (!ConfirmSendChecklistButtonFlag) {
        handleSubmitChecklist();
        ConfirmSendChecklistButtonFlag = true;
      }
    }}
    on:close={() => {
      showConfirmSendChecklistDialog = false;
      showSelectChecklistModalForBulk = false;
      checkedRecipients = [];
    }}
  />
{/if}

{#if showUserGuideOption}
  <ConfirmationDialog
    title={"Choose Options"}
    hideText="Close"
    hideColor="white"
    hyperLinks={userGuideOptions}
    hyperLinksColor="black"
    on:close={(event) => {
      showUserGuideOption = false;
    }}
    on:hide={(event) => {
      showUserGuideOption = false;
      const callbackHandler = event.detail.callback;
      callbackHandler();
    }}
  />
{/if}

{#if showChooseTemplateModal}
  <ChooseTemplateModal
    fullScreenDisplay={true}
    selectOne={true}
    on:selectionMade={processExisitingTemplateSelection}
    on:close={() => {
      showChooseTemplateModal = false;
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
    yesText="Next"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    checkBoxEnable={"enable"}
    requiresResponse={true}
    checkBoxText={"Save checklist for future use?"}
    on:close={() => {
      existingTemplateGuide = false;
      showUserGuideOption = true;
    }}
    on:yes={""}
  />
{/if}

{#if showNewUserGuideOption}
  {#if checkStatusNewUserGuideOption !== true}
    <ConfirmationDialog
      title={"Success! New Contact Created"}
      hideText="Close"
      hideColor="white"
      actionsColor="black"
      {actions}
      contactInfo={newContactObj}
      checkBoxEnable={"enable"}
      checkBoxText={"Don't ask me this again"}
      on:close={(event) => {
        showNewUserGuideOption = false;
        if (event?.detail) {
          localStorage.setItem("dontShowNewUserGuideOption", event?.detail);
        } else {
          localStorage.setItem("dontShowNewUserGuideOption", event?.detail);
        }
      }}
      on:hide={(event) => {
        showNewUserGuideOption = false;
        if (event?.detail) {
          localStorage.setItem("dontShowNewUserGuideOption", event?.detail);
        } else {
          localStorage.setItem("dontShowNewUserGuideOption", event?.detail);
        }
      }}
      on:edit={() => {
        window.location.hash = `#recipient/${newContactId}/details/user`;
      }}
      on:add={() => {
        window.location.hash = `#recipient/${newContactId}`;
      }}
      on:send={() => {
        showNewUserGuideOption = false;
        showNewUserSubGuideOption = true;
      }}
    />
  {/if}
{/if}

{#if showNewUserSubGuideOption}
  <ConfirmationDialog
    title={"Send files/ request"}
    yesText="Close"
    noText="Back"
    noColor="white"
    yesColor="white"
    actionsColor="black"
    actions={subActions}
    on:close={() => {
      showNewUserGuideOption = true;
      showNewUserSubGuideOption = false;
    }}
    on:yes={() => {
      showNewUserGuideOption = false;
      showNewUserSubGuideOption = false;
    }}
    on:checklists={() => {
      showChecklistModal = true;
    }}
    on:request={() => {
      showNewUserGuideOption = false;
      showNewUserSubGuideOption = false;
      showChooseTemplateModal = true;
    }}
    on:file={() => {
      showNewUserSubGuideOption = false;
      showDirectSendUpload = true;
    }}
  />
{/if}

{#if showChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={assignPackageForNewContact}
    on:close={() => {
      showChecklistModal = false;
    }}
  />
{/if}

{#if showConfirmationDialog}
  <ConfirmationDialog
    title={`Warning! Deleting contact named ${recipientToBeDeleted.name} - ${recipientToBeDeleted.email}?`}
    question={`Deleting a user cannot be undone and all records will be removed`}
    yesText="Yes, delete"
    noText="No, keep it"
    yesColor="danger"
    noColor="gray"
    responseBoxEnable={true}
    details={`To confirm deletion, type ${DELETECONFIRMATIONTEXT} in the text input field.`}
    responseBoxDemoText={DELETECONFIRMATIONTEXT}
    on:message={(event) => {
      tryDeleteRecipient(event, recipientToBeDeleted, false);
    }}
    on:yes={""}
    on:close={() => {
      showConfirmationDialog = false;
    }}
  />
{/if}

{#if showRecipientDeleteConfirmation && !hideRecipientDeleteConfirmationStatus}
  <ConfirmationDialog
    question={`Are you sure you want to assign to deleted Contact?`}
    yesText="Yes, retrieve the contact"
    noText="No"
    yesColor="secondary"
    noColor="gray"
    on:yes={handleRecipientDeleteConfirmation}
    on:close={() => {
      showRecipientDeleteConfirmation = false;
    }}
    checkBoxEnable={"enable"}
    checkBoxText={"Don't ask me this again"}
    on:hide={(event) => {
      if (event?.detail) {
        localStorage.setItem(
          SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY,
          event?.detail
        );
        hideRecipientDeleteConfirmationStatus = true;
      } else {
        localStorage.setItem(SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY, false);
      }
    }}
  />
{/if}

{#if showDeleteRestoreModal}
  <ConfirmationDialog
    question="This user has been deleted, do you want to restore them?"
    yesText="Yes"
    noText="No"
    yesColor="secondary"
    noColor="gray"
    on:yes={handleRecipientRestoration}
    on:close={() => {
      showDeleteRestoreModal = false;
    }}
  />
{/if}

{#if showInDashboardConfirmationBox}
  <ConfirmationDialog
    question={`Are you sure you want to show the contact in Dashboard?`}
    yesText="Yes, Show"
    noText="No"
    yesColor="secondary"
    noColor="gray"
    on:yes={unHideContact}
    on:close={() => {
      showInDashboardConfirmationBox = false;
    }}
  />
{/if}

{#if showImportContactsFromFileBox}
  <ImportContactsFromFile
    titleText="Bulk Update Contacts"
    on:close={() => {
      showImportContactsFromFileBox = false;
      recipients = getRecipients();
      recipients.then((response) => {
        recipientLength = response.length;
      });
      search_value = "";
      loadRecipientData();
    }}
    on:done={(event) => {
      //check if everything was okey, if not dont show anything
      if (!event.detail.isValid) {
        return;
      }
      recipients = getRecipients();
      search_value = "";
      loadRecipientData();
      showImportContactsFromFileBox = false;
      showBulkAssignConfirmationBox = true;
      oldRecipients = event.detail.oldRecipients;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showAddNewGoogleContact}
  <AddNewGoogleContact
    on:close={() => {
      showAddNewGoogleContact = false;
      loadRecipientData();
    }}
  />
{/if}

<style>
  .reset-style {
    margin: 0;
    padding: 0;
  }
  .selectedBorder {
    border: 1px solid #76808b;
    border-radius: 5px;
  }
  .recipient-deleted {
    text-decoration: line-through;
    background: #f5d8cb !important;
  }

  .flexContainer {
    display: flex;
    align-items: center;
    width: 100%;
  }
  .shadow-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 800;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .page-header {
    position: sticky;
    top: 0px;
    z-index: 12;
    background: #fcfdff;
    margin-top: -4px;
  }
  .recipient-td.date {
    display: flex;
    justify-self: left;
    align-self: center;
  }
  .recipient-action-mobile {
    grid-area: d;
    width: 100%;
  }
  .recipient-action-mobile div span {
    width: 100%;
  }
  .recipient-action-mobile {
    display: none !important;
  }
  .sortable {
    cursor: pointer;
    left: 6px;
    position: relative;
    color: #76808b;
  }
  .recipient-table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 0 auto;
    position: relative;
  }
  .recipient-tr.recipient-th {
    position: sticky;
    top: 90px;
    z-index: 10;
    background: #f8fafd;
    grid-template-columns: 2fr 1fr 145px;
    justify-items: start;
    box-sizing: border-box;
    display: grid;
    padding: 0.5rem;
    height: 45px;
    color: #76808b;
  }
  .recipient-th > .recipient-td {
    white-space: normal;
    justify-content: left;
    background: #f8fafd;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    align-items: center;
    justify-content: center;
  }
  .recipient-tr {
    width: 100%;
    display: grid;
    row-gap: 0.3rem;
    align-items: center;
    grid-template-columns: 2fr 1fr 145px;
    justify-items: start;
    grid-template-areas:
      "a b c"
      "d d d";
  }
  .recipient-th .recipient-td.details {
    justify-self: start;
  }
  .recipient-td.details {
    padding-left: 0.5rem;
    /* width: calc(100% - 10px); */
  }
  .recipient-tr:not(.recipient-th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 0.5rem;
    margin-bottom: 1em;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #2a2f34;
    justify-content: center;
    cursor: pointer;
  }
  .recipient-td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
    align-items: center;
    justify-content: center;
  }
  .clickable {
    cursor: pointer;
    justify-self: start;
    grid-area: a;
  }
  .name-company {
    display: flex;
    justify-items: space-evenly;
  }
  .recipient-tr .recipient-td.action {
    grid-area: c;
    width: 90%;
  }
  .name {
    overflow: hidden;
    word-wrap: break-word;
  }
  .recipient-td.action span {
    width: 100%;
  }
  .recipient-td.active span {
    margin-left: 50px;
  }
  .recipient-action-dropdown-mobile {
    display: none !important;
  }
  .button-container {
    margin-top: 1rem;
    display: grid;
    grid-auto-flow: column;
  }
  .mobile-only {
    display: none;
  }
  @media only screen and (max-width: 767px) {
    .name {
      width: 350px;
    }
    .recipient-td.date {
      display: none;
    }
    .recipient-tr.recipient-th {
      grid-template-columns: 2fr 1fr;
    }
    .recipient-tr.recipient-th {
      top: 67px !important;
      position: sticky;
      z-index: 999;
    }
    .action-header {
      display: none;
    }
    .recipient-action-mobile {
      display: block !important;
    }
    .recipient-action-desktop {
      display: none !important;
    }
    .desktop-only {
      display: none !important;
    }
    .mobile-only {
      display: block;
    }
    .new-contact {
      display: none;
    }

    .loader-container {
      height: 70vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }

    .mobile-sort-container {
      display: flex;
      justify-content: flex-left;
      align-items: center;
      margin-top: 1rem;
      gap: 0.5rem;
    }
    .sortable-item {
      display: flex;
    }
  }
</style>
