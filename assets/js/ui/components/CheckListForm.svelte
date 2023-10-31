<script>
  import { createEventDispatcher } from "svelte";
  import ClickButton from "../atomic/ClickButton.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import SelectField from "./SelectField.svelte";
  import Switch from "./Switch.svelte";
  import TextField from "./TextField.svelte";
  import {
    EXPIRATIONTRACKINGTEXT,
    ALLOWEXTRAFILESTOUPLOADTEXT,
  } from "../../../js/helpers/constants";
  export let new_request_type = "file";
  export let new_file_request;
  export let new_file_request_description;
  export let link_button_name;
  export let link_button_url;
  export let track_document_expiration;
  export let is_confirmation_required;
  export let allow_file_requestis_checked = false;
  export let modalView = false;
  export let isEditMode = false;
  export let currentEditRequest = undefined;

  const requestType = {
    File: "file",
    Task: "task",
    Data: "data",
  };
  let save_and_add = false;
  const dispatch = createEventDispatcher();
  const requireFileText = "Require confirmation file upload?";

  const switchActionExpiration = (checked) => {
    if (!isEditMode) {
      track_document_expiration = checked;
      return;
    }

    currentEditRequest.track_document_expiration = checked;
  };
  const switchFileReq = (checked) => {
    if (!isEditMode) {
      is_confirmation_required = checked;
      return;
    }

    currentEditRequest.is_confirmation_required = checked;
  };

  const handleSaveAndAddRequest = () => {
    save_and_add = true;
    if (new_file_request.trim() !== "") {
      handleAddRequest();
    }
  };

  const handleAddRequest = () => {
    let obj = {
      new_request_type,
      new_file_request,
      new_file_request_description,
      link_button_name,
      link_button_url,
      track_document_expiration,
      allow_file_requestis_checked,
      is_confirmation_required,
      save_and_add,
    };
    if (new_file_request.trim() !== "") {
      dispatch("add", { ...obj });
    }
  };

  const switchAdditionalFiles = (checked) => {
    allow_file_requestis_checked = checked;
  };

  const handleCancel = () => {
    dispatch("cancel");
  };
</script>

<section class="grid max-w-4xl mx-auto ">
  <h3 class="text-lg text-center text-primary">
    {isEditMode ? "Edit Request" : "Add a Request"}
  </h3>
  <p class="text-base text-secondary text-center">
    The checklist requires you to provide the information below. Your input is
    held to the highest available security standards.
  </p>
  <div class="flex justify-between pb-4">
    <div class="">Type <span class="">*</span></div>
    {#if !isEditMode}
      <SelectField
        style="width: 70%;"
        bind:value={new_request_type}
        options={[
          {
            text: "File",
            icon: "file-alt",
            iconStyle: "solid",
            value: requestType.File,
          },
          {
            text: "Data",
            icon: "keyboard",
            iconStyle: "solid",
            value: requestType.Data,
          },
          {
            text: "Task",
            icon: "tasks",
            iconStyle: "solid",
            value: requestType.Task,
          },
        ]}
      />
    {:else}
      <SelectField
        style="width: 70%;"
        bind:value={currentEditRequest.type}
        options={[
          {
            text: "File",
            icon: "file-alt",
            iconStyle: "solid",
            value: requestType.File,
          },
          {
            text: "Data",
            icon: "keyboard",
            iconStyle: "solid",
            value: requestType.Data,
          },
          {
            text: "Task",
            icon: "tasks",
            iconStyle: "solid",
            value: requestType.Task,
          },
        ]}
      />
    {/if}
  </div>
  <div class="flex justify-between pb-4">
    <div class="">Title <span class="">*</span></div>
    {#if !isEditMode}
      <TextField
        bind:value={new_file_request}
        iconStyle="regular"
        width="70%"
        text={""}
        maxlength={"40"}
      />
    {:else}
      <TextField
        bind:value={currentEditRequest.name}
        iconStyle="regular"
        width="70%"
        text={""}
        maxlength={"40"}
      />
    {/if}
  </div>
  <div class="flex justify-between pb-4">
    <div class="">Instructions</div>
    {#if !isEditMode}
      <TextField
        bind:value={new_file_request_description}
        iconStyle="regular"
        width="70%"
        text={""}
        maxlength={"80"}
      />
    {:else}
      <TextField
        bind:value={currentEditRequest.description}
        iconStyle="regular"
        width="70%"
        text={""}
        maxlength={"80"}
      />
    {/if}
  </div>
  {#if new_request_type === requestType.Task || (isEditMode && currentEditRequest.type === requestType.Task)}
    <div class="flex justify-between pb-4">
      <div class="">Button Name:</div>
      <span
        style="width: 70%;
              display: flex;
              flex-direction: column;"
      >
        {#if !isEditMode}
          <TextField
            bind:value={link_button_name}
            iconStyle="regular"
            width="100%"
            text={"Start"}
            maxlength={"12"}
          />
        {:else}
          <TextField
            bind:value={currentEditRequest.link.name}
            iconStyle="regular"
            width="100%"
            text={"Start"}
            maxlength={"12"}
          />
        {/if}
        {#if (link_button_name && link_button_name.length >= 12) || (currentEditRequest && currentEditRequest.link.name.length >= 12)}
          <div class="errormessage" id="name">
            {"Character limit (12) reached."}
          </div>
        {/if}
      </span>
    </div>
    <div class="flex justify-between pb-4">
      <div class="name button-link">
        Button Link
        <FAIcon color="#5C6367" icon="link" />
        :
      </div>
      {#if !isEditMode}
        <TextField
          bind:value={link_button_url}
          iconStyle="regular"
          width="70%"
          text={""}
        />
      {:else}
        <TextField
          bind:value={currentEditRequest.link.url}
          iconStyle="regular"
          width="70%"
          text={""}
        />
      {/if}
    </div>
    <div class="flex justify-between pb-4">
      <div style="display: flex; justify-content: start; margin-bottom: 10px;">
        {#if !isEditMode}
          <Switch
            checked={is_confirmation_required}
            action={switchFileReq}
            text={requireFileText}
          />
        {:else}
          <Switch
            checked={currentEditRequest.is_confirmation_required}
            action={switchFileReq}
            text={requireFileText}
          />
        {/if}
      </div>
    </div>
  {/if}

  {#if new_request_type === requestType.Task || new_request_type === requestType.File || (currentEditRequest && currentEditRequest.type === requestType.Task) || currentEditRequest.type === requestType.File}
    <div class="flex justify-between pb-4">
      <div style="display: flex; justify-content: start; margin-bottom: 10px;">
        {#if !isEditMode}
          <Switch
            checked={track_document_expiration}
            action={switchActionExpiration}
            text={`${EXPIRATIONTRACKINGTEXT}`}
          />
        {:else}
          <Switch
            checked={currentEditRequest.track_document_expiration}
            action={switchActionExpiration}
            text={`${EXPIRATIONTRACKINGTEXT}`}
          />
        {/if}
      </div>
    </div>
  {/if}

  {#if new_request_type === requestType.File && !isEditMode}
    <div class="flex justify-start pb-4">
      <Switch
        bind:checked={allow_file_requestis_checked}
        text={`${ALLOWEXTRAFILESTOUPLOADTEXT}`}
        action={switchAdditionalFiles}
      />
    </div>
  {/if}

  <div class="flex justify-between">
    {#if modalView}
      <ClickButton
        on:click={() => handleCancel()}
        color="white w-min"
        text="Cancel"
      />
    {/if}
    {#if modalView}
      {#if !isEditMode}
        <ClickButton
          on:click={() => handleSaveAndAddRequest()}
          disabled={new_file_request.trim() === ""}
          color="secondary w-min"
          text="Save & Add Another"
        />
      {:else}
        <ClickButton
          on:click={() => {
            if (
              currentEditRequest.type === requestType.File ||
              currentEditRequest.type === requestType.Data
            ) {
              currentEditRequest.link.name = "";
              currentEditRequest.link.url = "";
              currentEditRequest.is_confirmation_required = false;
            }

            dispatch("handleEditRequest", {
              item: currentEditRequest,
            });
          }}
          color="secondary w-min"
          text="Save Request"
        />
      {/if}
    {/if}
    {#if !isEditMode}
      <ClickButton
        on:click={() => handleAddRequest()}
        disabled={new_file_request.trim() === ""}
        color={`white ${modalView ? "w-min" : ""}`}
        text={`${modalView ? "Save & Close" : "Add Request"}`}
      />
    {/if}
  </div>
</section>

<style>
  .errormessage {
    display: inline-block;
    color: #cc0033;
    font-size: 12px;
    font-weight: bold;
    line-height: 15px;
    margin: 5px 0 0;
  }
</style>
