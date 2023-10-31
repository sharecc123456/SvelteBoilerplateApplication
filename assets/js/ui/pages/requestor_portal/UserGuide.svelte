<script>
  import QrCode from "svelte-qrcode";
  import { user_guide_modal } from "./../../../store";
  import Button from "../../atomic/Button.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import { onMount } from "svelte";
  import {
    directSendTemplates,
    directSendChecklist,
    directSendUploadedTemplates,
  } from "../../../api/Template";
  import ChooseRecipientModal from "../../modals/ChooseRecipientModal.svelte";
  import ChooseChecklistModal from "../../modals/ChooseChecklistModal.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import ChooseTemplateModal from "../../modals/ChooseTemplateModal.svelte";
  import {
    createAndSendChecklist,
    requires_iac_fill,
  } from "../../../api/TemplateGuide.js";
  import { createTemplate } from "../../../api/Template";
  import {
    setupRSDDocument,
    createSecureIntakeLink,
  } from "../../../api/Checklist";
  import assignedChecklistInfo from "../../../localStorageStore";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import Modal from "../../components/Modal.svelte";
  import FaIcon from "../../atomic/FAIcon.svelte";
  import { checkIfReviewsPending } from "BoilerplateAPI/Review";
  import {
    isIACCompatibleType,
    requestorTemplateNonIACExtensions,
  } from "../../../helpers/fileHelper";
  import { DIRECTSENDURLPARAMKEY, DOARCHIVE } from "../../../helpers/constants";
  import { createNewChecklist, archiveChecklist } from "../../../api/Checklist";
  import ClickButton from "../../atomic/ClickButton.svelte";
  import Dropdown from "../../components/Dropdown.svelte";

  export let useAsComponent = false;
  let current_tab = 0;

  // Intake
  let showIntakeModal = false;
  let newIntakeLink = "dummy";

  let bulkUploadFiles = false;
  let showSelectRecipientModal = false;
  let showSelectChecklistModal = false;
  let showChooseTemplateModal = false;
  let showItemChooseOptionBox = false;
  let packageId;
  let recipientId;
  let existingTemplateGuide = false;
  let selectedTemplates = [];
  let defaultChecklistName = "";
  let showTemplateUploadFile = false;
  let showTemplateTypeSelectionBox = false;
  let uploadedTemplate = undefined;
  let reviewItemsPromise;
  const ACTIONBUTTONTYPE = 1;
  const ROUTEBUTTONTYPE = 2;
  const MODALBUTTONTYPE = 3;
  const NORECIPIENTBUTTONTYPE = 4;
  const CHECKLISTTYPE = 5;
  let isIACCompatible = false;

  onMount(async () => {
    reviewItemsPromise = await checkIfReviewsPending();
  });

  const templateSendTypeOptions = () => [
    {
      title: "Add online form filling and signatures",
      callback: () => SetupForRSD(uploadedTemplate.id),
      icon: "file-contract",
      disabled: !isIACCompatible,
    },
    {
      title: "Send as is",
      callback: () => (showSelectRecipientModal = true),
      icon: "plane",
      disabled: false,
    },
  ];

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

  let templateActions = [
    {
      evt: "existing",
      description: "Use a existing / new template",
      icon: "clipboard-list-check",
    },
    { evt: "new", description: "Create new checklist", icon: "plus-circle" },
  ];
  let checklistActionModal = [
    {
      evt: "existing",
      description: "Use a saved / existing checklist",
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

  let showTemplateActions = false;
  let showNewChecklistActions = false;
  const elements = [
    {
      ret: 2,
      text: "Send single item to be filled/ signed",
      icon: "file-contract",
      disabled: false,
    },
    {
      ret: 1,
      text: "Send files to client, no action required",
      icon: "file-upload",
      disabled: false,
    },
    {
      ret: 3,
      text: "Get secure file intake link",
      icon: "link",
      disabled: false,
    },
    {
      ret: 4,
      text: "User Guide",
      icon: "question-circle",
      disabled: false,
    },
    {
      ret: 5,
      text: "Track and manage requests",
      icon: "tasks",
      disabled: false,
    },
    {
      ret: 6,
      text: "Manage contacts",
      icon: "address-book",
      disabled: false,
    },
    {
      ret: 7,
      text: "Review submissions",
      icon: "glasses",
      disabled: false,
    },
  ];
  const options = [
    {
      id: 0,
      title: "Send checklist",
      callbackfunc: () =>
        (window.location.hash = `#recipient/${recipientId}/assign/${packageId}`),
      icon: "clipboard-list",
      clicked: false,
      type: CHECKLISTTYPE,
      order: 1,
      category: "send",
    },
    {
      id: 2,
      title: "Send single item to be filled/ signed",
      callbackfunc: () => SendUploadedTemplates(),
      icon: "file-contract",
      clicked: false,
      type: MODALBUTTONTYPE,
      order: 3,
      category: "send",
    },
    {
      id: 1,
      title: "Send files to client, no action required",
      callbackfunc: () => (bulkUploadFiles = true),
      icon: "file-upload",
      clicked: false,
      type: ACTIONBUTTONTYPE,
      order: 2,
      category: "send",
    },
    {
      id: 3,
      title: "Get secure file intake link",
      icon: "link",
      clicked: false,
      type: NORECIPIENTBUTTONTYPE,
      callbackfunc: () => getSecureIntakeLink(),
      order: 0,
      category: "send",
    },
    {
      id: 4,
      title: "User Guide",
      icon: "question-circle",
      clicked: false,
      hash: "faq",
      type: ROUTEBUTTONTYPE,
      order: 4,
      category: "manage",
    },
    {
      id: 5,
      title: "Track and manage requests",
      icon: "tasks",
      clicked: false,
      hash: "dashboard",
      type: ROUTEBUTTONTYPE,
      order: 5,
      category: "manage",
    },
    {
      id: 6,
      title: "Manage contacts",
      icon: "address-book",
      clicked: false,
      hash: "recipients",
      type: ROUTEBUTTONTYPE,
      order: 6,
      category: "manage",
    },
    {
      id: 7,
      title: "Review submissions",
      icon: "glasses",
      clicked: false,
      hash: "reviews",
      type: ROUTEBUTTONTYPE,
      order: 7,
      category: "manage",
    },
  ];

  // Determines the order of the buttons to list in userguide screen
  const onSelectOption = (selectedobj) => {
    selectedobj.clicked = true;
    if (selectedobj.type === NORECIPIENTBUTTONTYPE) {
      selectedobj.callbackfunc();
    } else if (
      selectedobj.type === ACTIONBUTTONTYPE ||
      selectedobj.type === CHECKLISTTYPE
    ) {
      showSelectRecipientModal = true;
    } else if (selectedobj.type === MODALBUTTONTYPE) {
      showTemplateActions = true;
    } else {
      window.location.hash = selectedobj.hash;
      window.location.reload();
    }
  };

  const resetOptionsClickState = () => {
    options.forEach((option) => (option.clicked = false));
    showSelectRecipientModal = false;
  };

  const checklistPersonalization = async (name, templates, recipientId) => {
    let checklistContents = {
      name: name,
      description: "-",
      documents: templates,
      file_requests: [],
      commit: true,
      allow_duplicate_submission: false,
      allow_multiple_requests: false,
    };

    let reply = await createNewChecklist(checklistContents);
    if (reply.ok) {
      let response = await reply.json();
      const newChecklistId = response.id;
      await archiveChecklist(newChecklistId);
      window.location.hash = `#recipient/${recipientId}/assign/${newChecklistId}`;
    } else {
      showToast(
        `Could create new submission. Please try again later!.`,
        1500,
        "error",
        "MM"
      );
    }
  };

  const onSelectRecipient = (evt) => {
    recipientId = evt.detail.recipientId;
    showSelectRecipientModal = false;
    const selectedobj = options.find((op) => op.clicked === true);
    if (selectedobj.type === MODALBUTTONTYPE) {
      onSelectValidRecipient();
    } else if (selectedobj.type === CHECKLISTTYPE) {
      showSelectChecklistModal = true;
    } else if (selectedobj.type === ACTIONBUTTONTYPE) {
      onSelectValidRecipient();
    }
  };

  const onSelectValidRecipient = () => {
    // recipientId = evt.detail.recipientId;
    if (routeToPersonalizationScreen) {
      const selectedTemplateIds = selectedTemplates.map((x) => x.id);
      return checklistPersonalization(
        defaultChecklistName,
        selectedTemplateIds,
        recipientId
      );
    }
    const selectedOption = options.filter(
      (option) => option.clicked === true
    )[0];
    showSelectRecipientModal = false;
    selectedOption.callbackfunc();
  };

  let optionsColor = "white";

  const assignPackage = (evt) => {
    packageId = evt.detail.checklistId;
    showSelectChecklistModal = false;
    onSelectValidRecipient();
  };

  const processFileUploads = async (evt) => {
    let { name, file } = evt.detail;

    let reply = await directSendTemplates(name, file, recipientId);
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

  const SendUploadedTemplates = async () => {
    let reply = await directSendUploadedTemplates(
      uploadedTemplate.id,
      recipientId
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

  /* Callback from ChooseTemplateModel */
  let routeToPersonalizationScreen = false;
  async function processExisitingTemplateSelection(evt) {
    selectedTemplates = evt.detail.templates;
    defaultChecklistName = selectedTemplates[0].name;
    showChooseTemplateModal = false;
    routeToPersonalizationScreen = true;
    showSelectRecipientModal = true;
    // existingTemplateGuide = true;
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
      window.location.hash = `#recipient/${recipientId}/assign/${checklistId}`;
    } else {
      let reply = await directSendChecklist(checklistId, recipientId);
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
    recipientId = null;
  }

  async function SetupForRSD(rawDocId) {
    const reply = await setupRSDDocument(rawDocId, recipientId);
    if (reply.ok) {
      let { checklist_id, contents_id } = await reply.json();
      assignedChecklistInfo.set({
        contentsId: contents_id,
        assigneeId: checklist_id,
        recipientId,
      });
      const newHash = `#iac/setup/template/${rawDocId}?directSend=true`;
      window.location.hash = newHash;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }
  let showTemplateRecipientModal = false;
  /* A new file was selected */
  async function processNewTemplate(evt) {
    const { name, file, checkBoxStatus } = evt.detail;
    const archiveFlag = !checkBoxStatus;

    const templateReply = await createTemplate(name, file, archiveFlag);

    if (templateReply.ok) {
      let template = await templateReply.json();
      uploadedTemplate = template;
      showTemplateUploadFile = false;
      isIACCompatible = isIACCompatibleType(file);
      showToast(
        "Template created! choose recipient to move forward",
        1500,
        "default",
        "MM"
      );
      window.setTimeout(() => {
        showTemplateTypeSelectionBox = true;
      }, 1000);
    } else {
      alert("Something went wrong while uploading this file");
    }
  }

  /**
   * @description creates a checklist with file request and returns a intake link
   *
   * @returns {string} returns created intaje link
   */
  async function getSecureIntakeLink() {
    let reply = await createSecureIntakeLink({ secureLink: true });
    if (reply.ok) {
      let response = await reply.json();
      newIntakeLink = response.link;
      showIntakeModal = true;
    } else {
      let error = await reply.json();
      showErrorMessage("checklist", error.error);
    }
  }

  $: is_background_modal =
    showSelectRecipientModal ||
    showSelectChecklistModal ||
    bulkUploadFiles ||
    showItemChooseOptionBox ||
    existingTemplateGuide ||
    showTemplateUploadFile ||
    showTemplateTypeSelectionBox ||
    showTemplateActions ||
    showNewChecklistActions ||
    showIntakeModal ||
    showChooseTemplateModal;
</script>

<svelte:window />

{#if useAsComponent}
  {#if !is_background_modal}
    <ChooseRecipientModal
      on:selectionMade={(evt) => {
        options[0].clicked = true;
        onSelectRecipient(evt);
      }}
      on:close={resetOptionsClickState}
    />
  {/if}
{:else}
  <div class="page-header">
    <RequestorHeaderNew
      icon="plane"
      title="Start/ Send: Choose Your Action"
      enable_search_bar={false}
    />
  </div>

  <div class="contents">
    <div class="contents__body">
      <div class="button-container">
        <ClickButton
          largeText="Get Started"
          text="Form, file, e-sign and task requests"
          color="secondary"
          on:click={() => onSelectOption(options[0])}
        />
        <Dropdown
          optionsCenter={true}
          text="Other Actions"
          {elements}
          triggerType="button"
          buttonColor={"white"}
          childClasses={"w-full"}
          clickHandler={(e) => {
            let opt = options.find((o) => o.id === e);
            onSelectOption(opt);
          }}
        />
      </div>
      <!-- <div class="contents__header">
      <span>{title}</span>
      </div> -->
      <!-- <br/> -->
    </div>
  </div>
{/if}

{#if showSelectRecipientModal}
  <ChooseRecipientModal
    on:selectionMade={onSelectRecipient}
    on:close={resetOptionsClickState}
  />
{/if}

<!-- {#if showTemplateRecipientModal}
  <ChooseRecipientModal
    on:selectionMade={(evt) => {
      recipientId = evt.detail.recipientId;
      showTemplateRecipientModal = false;
      showTemplateTypeSelectionBox = true;
    }}
    on:close={resetOptionsClickState}
  />
{/if} -->

{#if showSelectChecklistModal}
  <ChooseChecklistModal
    on:selectionMade={assignPackage}
    on:close={() => {
      showSelectChecklistModal = false;
      resetOptionsClickState();
    }}
  >
    <span
      slot="buttons"
      on:click={() => {
        showNewChecklistActions = true;
        is_background_modal = true;
        showSelectChecklistModal = false;
      }}
    >
      <Button color="white" icon="plus" text="Create New" />
    </span>
  </ChooseChecklistModal>
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
    on:close={() => {
      showItemChooseOptionBox = false;
      resetOptionsClickState();
    }}
    on:hide={(event) => {
      showItemChooseOptionBox = false;

      if (event.detail) {
        const callbackHandler = event.detail.callback;
        callbackHandler();
      }
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

{#if showTemplateUploadFile}
  <UploadFileModal
    multiple={false}
    requireIACwarning={true}
    specializedFor="newTemplate"
    showCheckbox={true}
    checkBoxText="Save template for future use?"
    checkBoxStatus={false}
    allowNonIACFileTypes={requestorTemplateNonIACExtensions}
    on:done={processNewTemplate}
    on:close={() => {
      showTemplateUploadFile = false;
      showItemChooseOptionBox = true;
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
    on:close={() => {
      showTemplateTypeSelectionBox = false;
      resetOptionsClickState();
    }}
    on:hide={(event) => {
      showTemplateTypeSelectionBox = false;
      if (event.detail) {
        const callbackHandler = event.detail.callback;
        callbackHandler();
      }
      // resetOptionsClickState();
    }}
  />
{/if}

{#if showTemplateActions}
  <ConfirmationDialog
    title={"New or existing template"}
    hideText="Close"
    hideColor="white"
    actionsColor="black"
    actions={templateActions}
    on:close={() => {
      showTemplateActions = false;
    }}
    on:hide={() => {
      showTemplateActions = false;
    }}
    on:new={() => {
      showTemplateActions = false;
      showNewChecklistActions = true;
    }}
    on:existing={() => {
      showTemplateActions = false;
      showItemChooseOptionBox = true;
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
    }}
    on:hide={() => {
      showNewChecklistActions = false;
    }}
    on:futureUse={() => {
      showNewChecklistActions = false;
      window.location.hash = `#checklists/new?${DIRECTSENDURLPARAMKEY}=true&userGuide=true`;
    }}
    on:oneTime={() => {
      showNewChecklistActions = false;
      window.location.hash = `#checklists/new?${encodeURIComponent(
        `${DIRECTSENDURLPARAMKEY}=true&${DOARCHIVE}=true`
      )}`;
    }}
  />
{/if}

{#if showIntakeModal}
  <Modal
    on:close={() => {
      resetOptionsClickState();
      showIntakeModal = false;
    }}
  >
    <div slot="header">QR code/ shareable link created</div>

    <div style="display: flex; flex-direction: column;" class="intake-text">
      <span style="font-weight: 900;">To share:</span>
      <span>
        <span style="font-weight: 900;">QR code : </span>Download by
        right-clicking the QR code on desktop, or long-pressing on mobile.
        Display the QR in a scannable location.
      </span>
      <br />
      <span>
        <span style="font-weight: 900;">Link : </span> Copy to your clipboard and
        then post on your website, social media, in an email (no tracking), etc.
      </span>
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
        await navigator.clipboard.writeText(newIntakeLink);
        showToast(`Link copied to clipboard.`, 1000, "white", "MM");
      }}
      data-text-copy="Click to Copy"
    >
      <FaIcon icon="copy" />&nbsp;&nbsp;Copy link
    </div>
  </Modal>
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .intake-qr-code {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .page-header {
    position: sticky;
    top: 10px;
    z-index: 0;
    background: #fcfdff;
  }

  .contents__body {
    width: 100%;
  }

  .contents {
    width: 80%;
    padding: 1rem;
    margin: auto;
    padding-top: 100px;
  }
  .button-container {
    width: 22rem;
    margin-left: auto;
    margin-right: auto;
    display: grid;
    gap: 8px;
  }
  /* Intake CSS */

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
    width: 30%;
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

  @media only screen and (max-width: 786px) {
    .contents {
      padding-left: 0rem;
      padding-right: 0rem;
      padding-bottom: 1rem;
      padding-top: calc(45vh - 135px);
    }

    .button-container {
      width: 18rem;
    }
  }
  @media only screen and (max-width: 425px) {
    .contents {
      width: 100%;
    }
  }
</style>
