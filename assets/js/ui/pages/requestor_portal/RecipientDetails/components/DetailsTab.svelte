<script>
  import TextField from "Components/TextField.svelte";
  import DocumentTag from "../../DocumentTag.svelte";
  import Tag from "Atomic/Tag";
  import { onMount } from "svelte";
  import Button from "Atomic/Button.svelte";
  import FAIcon from "Atomic/FAIcon.svelte";
  import ConfirmationDialog from "../../../../components/ConfirmationDialog.svelte";
  import { deleteRecipient } from "../../../../../api/Recipient";
  import { showErrorMessage } from "Helpers/Error";
  import {
    showToast,
    isToastVisible,
  } from "../../../../../helpers/ToastStorage";
  import ToastBar from "../../../../atomic/ToastBar.svelte";
  import { getRecipients } from "BoilerplateAPI/Recipient";
  import PhoneNumberInput from "Components/PhoneNumberInput.svelte";
  import { todayDate } from "../../../../../helpers/dateUtils";
  import { DELETECONFIRMATIONTEXT } from "../../../../../constants";

  export let recipient = {};
  const currentRecipient = { ...recipient };

  let today;
  onMount(() => {
    today = todayDate();
  });

  export let showEdit = false;
  export let canChangeEmail = false;
  export let showEmailError = false;
  let tagsSelected = [];

  export let commitChanges = (r) => {};
  const toggleShowEdit = () => {
    showEdit = !showEdit;
    if (!showEdit) {
      showEmailError = false;
      recipient = { ...currentRecipient };
    }
  };

  export const onSaveContact = (r) => {
    if (!validate_phone_number(r.phone_number)) {
      const { name, email } = r;
      if (name.trim() == "") {
        showToast("Name cannot be empty", 1500, "error", "TM");
        return;
      }

      if (
        !/(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/.test(
          email
        )
      ) {
        showToast("Invalid email address!", 1500, "error", "TM");
        return;
      }

      r.tags = tagsSelected.map(x => x.id);

      // showEdit = false;
      commitChanges(r);
    } else {
      showToast(`Please Enter Valid Phone Number!`, 1000, "error", "MM");
    }
  };

  export const onDeleteContact = (flag) => {
    if (flag && !showEdit && !recipient?.is_deleted) {
      showDeleteConfirmationDialog = true;
    }
  };
  let showDeleteConfirmationDialog = false;
  async function tryDeleteRecipient(event) {
    const { text: deleteTextMessage } = event.detail;
    if (DELETECONFIRMATIONTEXT != deleteTextMessage.toLowerCase()) {
      showToast(`Please type ${DELETECONFIRMATIONTEXT}!`, 1000, "error", "MM");
      return;
    }

    let reply = await deleteRecipient(recipient.id);
    showDeleteConfirmationDialog = false;
    if (reply.ok) {
      window.location.href = `#recipients`;
    } else {
      let error = await reply.json();
      showErrorMessage("recipient", error.error);
    }
  }
  let dropDownvalues = [];
  let isPromiseResolved;
  getRecipients().then((recp) => {
    dropDownvalues = [...new Set(recp.map((r) => r.company))];
    isPromiseResolved = true;
  });

  $: dropDownvalues = isPromiseResolved ? dropDownvalues : [];

  function validate_phone_number(phone_number) {
    if (
      /^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$/im.test(
        phone_number
      ) ||
      phone_number.length == 0
    ) {
      return false;
    }

    return true;
  }
</script>

<div class="container">
  <div class="card">
    <div class="edit-button" on:click={toggleShowEdit}>
      <div>
        {#if showEdit}
          <FAIcon icon="times" iconSize="small" />
        {:else}
          <FAIcon icon="pencil-alt" iconSize="small" />
        {/if}
      </div>
    </div>
    <div class="row">
      <div class="label">
        Email
        {#if canChangeEmail && showEdit}
          <span class="required">*</span>
        {/if}
      </div>
      {#if showEdit}
        {#if canChangeEmail}
          <TextField bind:value={recipient.email} text="Email" />
        {:else}
          <div class="value long-email">{currentRecipient.email}</div>
          <span class="required"
            >This recipient's email cannot be changed - support can help you
            with this issue. Please contact us at support@boilerplate.co or in
            the blue chat window at the bottom right of your screen.</span
          >
        {/if}
      {:else}
        <div class="value long-email">{currentRecipient.email}</div>
      {/if}
    </div>
    <div class="row">
      <div class="label">
        Name
        {#if showEdit}
          <span class="required">*</span>
        {/if}
      </div>
      {#if showEdit}
        <TextField bind:value={recipient.name} text="Name" />
      {:else}
        <div class="value">{currentRecipient.name}</div>
      {/if}
    </div>
    <div class="row">
      <div class="label">Company / Org.</div>
      {#if showEdit}
        <TextField
          bind:value={recipient.company}
          text={"Company"}
          datalistId="companies"
          dropdownEnabled={true}
          dropDownContents={dropDownvalues}
        />
      {:else}
        <div class="value">{currentRecipient.company}</div>
      {/if}
    </div>
    <div class="row">
      <div class="label">Phone Number</div>
      {#if showEdit}
        <PhoneNumberInput bind:value={recipient.phone_number} />
      {:else if currentRecipient.phone_number.length == 0}
        <div class="value">-</div>
      {:else}
        <div class="value">{currentRecipient.phone_number}</div>
      {/if}
    </div>
    <div class="row">
      <div class="label">Start Date</div>
      {#if showEdit}
        <input
          style="width: 100%;
                  padding: 10px;
                  border: 1px solid #b3c1d0;
                  border-radius: 5px;"
          maxlength="4"
          pattern="[1-9][0-9]{3}"
          max={"9999-12-31"}
          type="date"
          onfocus="this.showPicker()"
          bind:value={recipient.start_date}
        />
      {:else if !currentRecipient.start_date}
        <div class="value">-</div>
      {:else}
        <div class="value">{currentRecipient.start_date}</div>
      {/if}
    </div>
    <div class="row">
      <div class="label">Tags</div>
      {#if showEdit}
        <DocumentTag
          companyID={currentRecipient.company_id}
          tagType={"recipient"}
          templateTagIds={currentRecipient.tags?.id}
          bind:tagsSelected={tagsSelected}
        />
      {:else}
        {#each currentRecipient.tags?.values as tag}
          <Tag isSmall={false} {tag} allowDeleteTags={false} />
        {/each}
      {/if}
    </div>
  </div>
</div>

{#if showDeleteConfirmationDialog}
  <ConfirmationDialog
    title="Confirmation"
    question={`Are you sure you want to delete the recipient named "${recipient.name}" <${recipient.email}>?`}
    yesText="Yes, delete"
    noText="No, keep it"
    yesColor="danger"
    noColor="gray"
    responseBoxEnable={true}
    details={`To confirm deletion, type ${DELETECONFIRMATIONTEXT} in the text input field.`}
    responseBoxDemoText={DELETECONFIRMATIONTEXT}
    on:message={(event) => {
      tryDeleteRecipient(event);
    }}
    on:yes={""}
    on:close={() => {
      showDeleteConfirmationDialog = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  * {
    box-sizing: border-box;
  }

  .required {
    color: rgb(221, 38, 38);
  }

  .container {
    max-width: 500px;
    margin: 2em auto;
    padding: 0 1em;
  }

  .card {
    padding: 2em;
    box-shadow: rgba(0, 0, 0, 0.1) 0px 4px 12px;
    border-radius: 15px;
    position: relative;
  }

  .edit-button {
    position: absolute;
    top: 1em;
    right: 1em;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    cursor: pointer;
  }

  .edit-button:hover {
    box-shadow: rgba(0, 0, 0, 0.1) 0px 4px 12px;
  }

  .row {
    margin-bottom: 1rem;
    border-bottom: 0.5px solid #e0e2e3;
    padding-bottom: 0.5rem;
  }

  .row:last-child {
    margin-bottom: 0;
  }

  .row .label {
    font-weight: bold;
  }

  @media only screen and (max-width: 767px) {
    .container {
      padding: 0rem;
    }
    .long-email {
      width: 450px;
      word-wrap: break-word;
    }
  }

  @media only screen and (max-width: 600px) {
    .long-email {
      width: 320px;
    }
  }

  @media only screen and (max-width: 450px) {
    .long-email {
      width: 250px;
    }
  }

  @media only screen and (max-width: 400px) {
    .long-email {
      width: 230px;
    }
  }

  @media only screen and (max-width: 360px) {
    .long-email {
      width: 200px;
    }
  }
</style>
