<script>
  import ChooseTemplateModal from "../../../modals/ChooseTemplateModal.svelte";
  import NavBar from "Components/NavBar.svelte";
  import TabBar from "Components/TabBar.svelte";
  import DetailsTab from "./components/DetailsTab.svelte";
  import DocumentationTab from "./components/DocumentationTab.svelte";
  import DataTab from "./components/DataTab.svelte";
  import BottomBar from "../../../components/BottomBar.svelte";
  import Modal from "../../../components/Modal.svelte";
  import { postIACSESFill } from "BoilerplateAPI/IAC";
  import {
    updateRecipient,
    getRecipient,
    getCabinet,
  } from "BoilerplateAPI/Recipient";
  import { getArchivedAssignments } from "BoilerplateAPI/Assignment";
  import Loader from "Components/Loader.svelte";
  import Button from "../../../atomic/Button.svelte";
  import { showErrorMessage } from "../../../../helpers/Error";
  import ConfirmationDialog from "../../../components/ConfirmationDialog.svelte";

  export let recipientId;

  let recipient_name = "",
    recipient_email = "",
    recipient_email_can_edit = false,
    recipient_company = "",
    phone_number = "",
    start_date = "";

  let showChooseTemplateModal = false;
  let showExportTips = false;
  let sesData = {};
  let showAddOptions = false;
  let showAddForm = false;
  let showVerificationOptions = false;

  // Data Tab details
  export let inHistoryView = false;
  export let filterType = "";
  export let filterParamFs = "";
  export let filterParamCs = "";

  // Call Back to save Changes
  let showEdit = false;
  let SaveContact;
  function onSaveContact(recipient) {
    SaveContact(recipient);
  }
  // Call Back to delete Contact
  let deleteContact;
  function onDeleteContact(flag) {
    deleteContact(flag);
  }

  //==============================================================================//
  let isContactUpdated = false;
  let showEmailError = false;
  let showEmailChangeDone = false;
  async function commitChanges(recipient) {
    const { name, company, email, phone_number, start_date, tags } = recipient;

    let reply = await updateRecipient(
      recipient,
      name,
      company || "-",
      email,
      phone_number,
      new Date(start_date),
      tags
    );
    if (!reply.ok) {
      const responseText = await reply.text();
      showEmailError = true;
      showErrorMessage("recipient", responseText);
    } else {
      const responseText = await reply.text();
      if (responseText == "EMAIL") {
        recipient_email = email;
        showEmailChangeDone = true;
      }
      recipientPromise = getRecipient(recipient.id);
      isContactUpdated = true;
    }
  }

  async function deleteCabinet(_cabinet) {
    alert("Failed to delete this cabinet item");
  }

  function dropdownClick(cabinet, actionId) {
    if (actionId == 1) {
      deleteCabinet(cabinet);
    } else {
      alert(`${actionId} clicked for ${cabinet.id} but not action registered`);
    }
  }

  let recipientPromise = getRecipient(recipientId).then(async (r) => {
    recipient_name = r.name;
    recipient_company = r.company;
    recipient_email = r.email;
    recipient_email_can_edit = r.email_editable;
    phone_number = r.phone_number;
    start_date = r.start_date;
    return r;
  });
  let cabinetPromise = getCabinet(recipientId);
  let cabinetActions = [{ text: "Delete", ret: 1 }];

  let tabs = [
    { name: "Documentation", icon: "copy" },
    { name: "Details", icon: "info-circle" },
    { name: "Profile Data", icon: "database" },
  ];

  let archivePromise = getArchivedAssignments(recipientId);
  var current_tab;
  if (window.location.hash.includes("details/user")) {
    current_tab = 1;
  } else if (window.location.hash.includes("details/data")) {
    current_tab = 2;
  } else {
    current_tab = 0;
  }
  // var current_tab = window.location.hash.includes("details/user") ? 1 : 0;
  // Hot fix
  $: if (current_tab == 0)
    window.location.hash = window.location.hash.replace(
      "details/user",
      "details/doc"
    );
  $: if (current_tab == 1)
    window.location.hash = window.location.hash.replace(
      "details/doc",
      "details/user"
    );
</script>

<div class="desktop-only">
  <NavBar
    navbar_spacer_classes="navbar_spacer_pb1"
    backLinkHref="#recipients"
    backLink=" "
    middleText={`${recipient_name} ${
      recipient_company ? `&nbsp; (${recipient_company})` : ""
    }`}
    middleSubText={recipient_email}
  />
</div>

<div class="mobile-only">
  <NavBar
    navbar_spacer_classes="navbar_spacer_pb1"
    backLinkHref="#recipients"
    backLink=" "
    showCompanyLogo={false}
    middleText={`${recipient_name} ${
      recipient_company ? `(${recipient_company})` : ""
    }`}
    middleSubText={recipient_email}
  />
</div>

<div class="container">
  {#await recipientPromise}
    <Loader loading />
  {:then recipient}
    <TabBar
      {tabs}
      {current_tab}
      container_classes="tab-container-center-mobile"
      on:changeTab={({ detail: { tab_index } }) => (current_tab = tab_index)}
    />

    <div class="main-content">
      {#if current_tab === 0}
        <DocumentationTab
          {...{
            recipientId,
            archivePromise,
            cabinetPromise,
            dropdownClick,
            cabinetActions,
            recipient,
          }}
        />
      {:else if current_tab == 1}
        <DetailsTab
          bind:showEdit
          bind:onSaveContact={SaveContact}
          bind:onDeleteContact={deleteContact}
          {...{
            recipient,
            recipient_company,
            recipient_email,
            recipient_name,
            phone_number,
            start_date,
            commitChanges,
            showEdit: isContactUpdated ? false : showEmailError,
            showEmailError,
          }}
          canChangeEmail={recipient_email_can_edit}
        />
      {:else if current_tab == 2}
        <DataTab
          bind:inHistoryView
          bind:filterType
          bind:filterParamCs
          bind:filterParamFs
          bind:showAddForm
          bind:showVerificationOptions
          bind:showAddOptions
          {recipient}
          {recipient_name}
        />
      {/if}
    </div>

    <div>
      <BottomBar
        leftButtons={[]}
        rightButtons={[
          {
            button: "Add Data",
            color: "primary",
            evt: "sesadd",
            ignore: current_tab != 2,
          },
          {
            button: "Send for client updates/verification",
            color: "secondary",
            evt: "sessend",
            ignore: current_tab != 2,
          },
          {
            button: "Export to Document",
            color: "secondary",
            evt: "ses",
            ignore: current_tab != 2,
          },
          {
            button: "Close",
            color: "primary",
            evt: "close",
          },
        ]}
        centerButtons={[
          {
            button: showEdit ? "Save Changes" : "Edit Contact",
            color: showEdit ? "secondary" : "white",
            evt: "saveChanges",
            ignore: current_tab != 1,
          },
          {
            button: "Delete Contact",
            color: "white",
            evt: "deleteContact",
            ignore: current_tab != 1 || recipient?.is_deleted,
          },
        ]}
        on:ses={() => {
          sesData = {
            mapsource: "recipient",
            recipient: recipient.id,
            filterDetails: {
              type: filterType,
              params: {
                contents_id: filterParamCs,
                form_submission_id: filterParamFs,
              },
            },
            checklist: 0,
          };
          showExportTips = true;
        }}
        on:sesadd={() => {
          showAddOptions = true;
        }}
        on:sessend={() => {
          showVerificationOptions = true;
        }}
        on:close={() => {
          if (current_tab == 1) {
            showEdit = !showEdit;
            if (!showEdit) {
              onSaveContact(recipient);
            }
          }
          window.location.href = "#recipients";
        }}
        on:saveChanges={() => {
          showEdit = !showEdit;
          if (!showEdit) {
            onSaveContact(recipient);
          }
        }}
        on:deleteContact={() => {
          onDeleteContact(true);
        }}
      />
    </div>
  {:catch error}
    <h1>An error occured while fetching this Contact: {error}</h1>
  {/await}
</div>

{#if showExportTips}
  <Modal
    on:close={() => {
      showExportTips = false;
    }}
  >
    <p class="tipsPopHeader">Information</p>

    <div class="modal-subheader">
      Please make data changes on the data tab before exporting to document. You
      will be able to edit data on the PDF template, however those changes will
      <strong>NOT</strong> save for future use.<br />
      <br />
      Any repeat entry tables will be attached to the exported document, but not
      viewable the next screen. These should be edited on the Data tab prior to export.
      <br />
      <br />
      A PDF of the exported document will be saved in the Contact's documentation
      tab.
    </div>

    <div class="modal-buttons">
      <span
        on:click={() => {
          showExportTips = false;
        }}
      >
        <Button color="white" text="Cancel / Back to Edit Data" />
      </span>
      <span
        on:click={() => {
          showExportTips = false;
          showChooseTemplateModal = true;
        }}
      >
        <Button color="primary" text="Proceed to Choose Template" />
      </span>
    </div>
  </Modal>
{/if}

{#if showChooseTemplateModal}
  <ChooseTemplateModal
    fullScreenDisplay={false}
    showSelectionCount={false}
    customButtonText={true}
    templateFilter={"labelled"}
    buttonText={"Export to Document"}
    on:selectionMade={async (x) => {
      let selected = x.detail.templateIds[0];
      sesData.raw_document_id = selected;
      console.log(sesData);
      let res = await postIACSESFill(sesData);
      let res2 = await res.json();
      let iacDocId = res2.iac_doc_id;
      let contentsId = res2.contents_id;
      let emptyTables = res2.empty_tables.join(",");
      let recipientId = sesData.recipient;
      let tc = 0;
      window.location.hash = `#iac/fill/${iacDocId}/${contentsId}/${recipientId}?sesMode=true&tc=${tc}&empty=${emptyTables}`;
    }}
    selectOne={true}
    title={"Select Destination Template"}
    on:close={() => {
      showChooseTemplateModal = false;
    }}
  />
{/if}

{#if showEmailChangeDone}
  <ConfirmationDialog
    title={"Email Change"}
    popUp={true}
    popUpExtraClose={true}
    question={"Email changed successfully - assignment (if any) emails were resent."}
    yesText={"Close"}
    noText={undefined}
    on:close={() => {
      showEmailChangeDone = false;
    }}
  />
{/if}

<style>
  .container {
    padding-left: 2rem;
    padding-right: 2rem;
    margin-top: 1.5rem;
  }
  .main-content {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 2rem;
  }

  .mobile-only {
    display: none;
  }

  .modal-subheader {
    color: #2a2f34;
    height: 90px;
  }

  .modal-buttons {
    margin-top: 10rem;
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
  }

  .tipsPopHeader {
    display: flex;
    justify-content: flex-start;
    font-size: large;
    font-weight: bolder;
    color: #2a2f34;
  }

  @media only screen and (max-width: 767px) {
    .container {
      padding-left: 0.5rem;
      padding-right: 1rem;
    }
    .main-content {
      padding: 1rem;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
  }
</style>
