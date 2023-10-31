<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import { isMobile } from "../../helpers/util";
  import TextField from "../components/TextField.svelte";
  import Button from "../atomic/Button.svelte";
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import File from "../atomic/File.svelte";
  import Dropzone from "svelte-file-dropzone";

  export let multiple = true;
  export let specializedFor = "none";
  export let specialText = undefined;
  export let extraButton = undefined;
  export let checkForCustomFiletype = false;
  export let requiredFileFormats =
    ".pdf, .doc, .dotx, .xls, .png, .gif, .jpg, .jpeg, .hevc, .heic, .heif .csv";
  export let conditionalFileUploadAllowed =
    ".pdf, .png, .gif, .jpg, .jpeg, .hevc, .heic, .heif .csv";
  export let uploadHeaderText = "Upload a document";
  export let uploadSubHeaderText = "";
  const fileSizeLimit = "18mb";
  export let isAdditionalUploads = false;

  export let specialNONIAC = false;
  let clicked = false;
  export let checkBoxStatus = false;
  export let checkBoxText = "";
  export let showCheckbox = false;

  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";

  import {
    checkFileSizeLimit,
    isFileTypeMergeable,
    isAllowedFileExtensionType,
    isIACCompatibleType,
  } from "../../helpers/fileHelper";
  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";

  let cabinet_file_name = "";
  let files = {
    accepted: [],
    rejected: [],
  };
  let pressedButton = false;
  let isLoadingEnabled = false;

  function handleFilesSelect(e) {
    const { acceptedFiles, fileRejections } = e.detail;

    files.accepted = [...files.accepted, ...acceptedFiles];
    files.rejected = [...files.rejected, ...fileRejections];
    cabinet_file_name = files.accepted[0]?.name?.split(".")[0];
  }

  function removeFile(index) {
    files.accepted.splice(index, 1);
    files.accepted = [...files.accepted];
  }
  let uploadButtonClicked = false;
  let showMultipleFileRequestBox = false;
  let middleButtonPressed = false;

  function upload() {
    uploadButtonClicked = true;
    if (constructUploadButtonState()) return;
    if (files.accepted.length === 0) return;
    const isFileSizeBelowThreshold = files.accepted.every(checkFileSizeLimit);
    const isBoilerplateCompatible = checkForCustomFiletype
      ? files.accepted.every((file) =>
          requiredFileFormats
            .split(", ")
            .some((fileFormat) => file.name.toLowerCase().endsWith(fileFormat))
        )
      : files.accepted.every(isAllowedFileExtensionType);
    let isMergeableUploads = files.accepted.every(isFileTypeMergeable);
    const allowAdditionalUploads = true;

    // Upload Error
    if (!isFileSizeBelowThreshold || !isBoilerplateCompatible) {
      //Size too big
      upload_ok = false;
      middleButtonPressed = false;
      isLoadingEnabled = false;
      uploadButtonClicked = false;
      const toastMessgae = !isFileSizeBelowThreshold
        ? `The file you've attempted to upload exceeds our file size limit (18MB). Try breaking it into smaller files, or contact your admin.`
        : !allowAdditionalUploads
        ? `Different filetypes not supported. Please upload the files as a separate request.`
        : `The file you've attempted to upload is not compatible with the system.`;
      showToast(toastMessgae, 3000, "error", "MM");
      return;
    }

    if (files.accepted.length === 1) {
      upload_ok = true;
      isLoadingEnabled = true;
      dispatch("done", {
        name: cabinet_file_name,
        file: files.accepted,
        checkBoxStatus: checkBoxStatus,
        middleButtonPressed,
      });
      return;
    }
    /********************** Mulitple file uploads **********************************/
    if (isMergeableUploads) {
      isLoadingEnabled = true;
      upload_ok = true;
      dispatch("done", {
        name: cabinet_file_name,
        file: files.accepted,
        checkBoxStatus: checkBoxStatus,
        middleButtonPressed,
      });
      return;
    }

    showMultipleFileRequestBox = true;
  }

  let upload_ok = true;
  $: if (files.accepted.length === 0) {
    upload_ok = false;
    isLoadingEnabled = false;
  } else {
    upload_ok = true;
  }

  $: pressedButton = isLoadingEnabled;

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }

    if (e.key === "Tab") {
      // trap focus
      const nodes = modal.querySelectorAll("*");
      const tabbable = Array.from(nodes).filter((n) => n.tabIndex >= 0);

      let index = tabbable.indexOf(document.activeElement);
      if (index === -1 && e.shiftKey) index = 0;

      index += tabbable.length + (e.shiftKey ? -1 : 1);
      index %= tabbable.length;

      tabbable[index].focus();
      e.preventDefault();
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  const handleCheckBox = () => {
    checkBoxStatus = !checkBoxStatus;
  };

  /**
   * returns the upload button state
   */
  const constructUploadButtonState = () => {
    let isDisabled = true;
    if (upload_ok) {
      isDisabled = false;
    }
    if (isAdditionalUploads) {
      return cabinet_file_name.length === 0 ? true : false;
    }
    return isDisabled;
  };
  //Reactive variable to get confirm upload button status
  $: isConfirmUploadButtonDisabled =
    !upload_ok ||
    uploadButtonClicked ||
    (isAdditionalUploads &&
      (cabinet_file_name.trim() === "" || cabinet_file_name.length > 60))
      ? true
      : false;
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <span class="modal-headers">
        <span class="modal-header">{uploadHeaderText}</span>
        {#if uploadSubHeaderText != undefined && uploadSubHeaderText != null && uploadSubHeaderText != ""}
          <span style="margin-top: -1rem;" class="modal-subheader">
            {uploadSubHeaderText}
          </span>
        {/if}

        {#if specialText != "" && specialText != undefined && specialText != null}
          <span class="modal-subheader">{specialText}</span>
        {/if}

        {#if specialNONIAC}
          <span class="modal-subheader"
            >Online form filling is not available for this request. Instead:
            <ol>
              <li>Download</li>
              <li>Open from wherever you saved the file</li>
              <li>Fill and save to your device</li>
              <li>Upload below</li>
            </ol>
          </span>
        {/if}

        {#if extraButton != undefined}
          <span
            class="modal-extrabutton"
            on:click={() => {
              dispatch("extraClicked");
              clicked = true;
            }}
          >
            <Button
              text={extraButton}
              color={clicked && specialNONIAC ? "white" : "primary"}
            />
          </span>
        {/if}
      </span>

      {#if showCheckbox}
        <br />
        <label class="checkbox">
          <input
            type="checkbox"
            on:click={handleCheckBox}
            bind:checked={checkBoxStatus}
          />
          {checkBoxText}
        </label>
      {/if}

      <div class:drop-zone={!isMobile()} class:upload-mobile={isMobile()}>
        <Dropzone
          disableDefaultStyles={true}
          on:drop={handleFilesSelect}
          {multiple}
        >
          <Button
            color={files.accepted.length > 0 ? "light" : "primary"}
            text={`Choose ${multiple ? "files" : "file"} to Upload`}
          />
          {#if !isMobile()}
            <p class="fontfix">or</p>
            <span class="fontfix"
              >Drag and drop {`${multiple ? "files" : "file"}`} here</span
            >
          {/if}
          {#if requiredFileFormats.length !== 0}
            <span class="supportedFilesText">
              {#if conditionalFileUploadAllowed != ""}
                <i
                  >{`Single file upload. Supported file types: ${requiredFileFormats.toUpperCase()}`}</i
                >
                <br />
                <i
                  >{`Multiple file upload. Supported file types: ${conditionalFileUploadAllowed.toUpperCase()}`}</i
                >
              {:else}
                <i
                  >{`Supported file types: ${requiredFileFormats.toUpperCase()}`}</i
                >
              {/if}
            </span>
          {/if}
        </Dropzone>
      </div>
      <span class="limiter text"
        ><i>The file size can up be up to {fileSizeLimit}</i></span
      >
      {#if specializedFor == "additionalFileUploads"}
        <div class="name">
          <p>
            Request Name
            <span class="required">*</span>
          </p>
          <TextField
            bind:value={cabinet_file_name}
            text={"Document Name"}
            maxlength={"61"}
          />
          {#if cabinet_file_name.length > 0 && cabinet_file_name.trim() === ""}
            <div class="errormessage" id="name">
              {"Please enter a document name. All blank spaces are not allowed."}
            </div>
          {/if}
          {#if cabinet_file_name.length > 60}
            <div class="errormessage" id="name">
              {"Character limit (60) reached."}
            </div>
          {/if}
        </div>
      {/if}

      <div class="files">
        {#if files.accepted.length > 0}
          <div class="file-header">Selected Files</div>
        {/if}
        {#each files.accepted as item, index}
          <div class="file">
            <File
              on:fileDeleted={() => {
                removeFile(index);
              }}
              name={item.name}
            />
          </div>
        {/each}
      </div>

      <div
        class={isAdditionalUploads
          ? "submit-buttons-additional-files"
          : "submit-buttons"}
      >
        <span
          on:click={close}
          class={isAdditionalUploads
            ? "cancel-button-additional-files"
            : "cancel-button"}
        >
          <Button fullHeight={true} color="light" text="Cancel" />
        </span>
        <!-- Additional Upload Middle Button -->
        {#if isAdditionalUploads}
          <span
            on:click={() => {
              middleButtonPressed = true;
              !isConfirmUploadButtonDisabled && upload();
            }}
            class={isAdditionalUploads
              ? "cancel-button-additional-files"
              : "cancel-button"}
          >
            <LoadingButton
              disabled={isConfirmUploadButtonDisabled}
              pressed={!upload_ok || showMultipleFileRequestBox
                ? false
                : middleButtonPressed}
              fullHeight={true}
              color="secondary"
              text="Submit & Add Another File"
            />
          </span>
        {/if}

        <span
          class="tooltip"
          on:click={!isConfirmUploadButtonDisabled && upload}
        >
          <LoadingButton
            color="primary"
            text={isAdditionalUploads ? "Submit & close" : "Next"}
            disabled={isConfirmUploadButtonDisabled}
            pressed={!upload_ok || showMultipleFileRequestBox
              ? false
              : pressedButton && !middleButtonPressed}
            fullWidth={isAdditionalUploads}
          />
          {#if specializedFor == "additionalFileUploads"}
            {#if !upload_ok || (cabinet_file_name.replace(/\s/g, "").length < 1 && cabinet_file_name.length >= 1)}
              <span
                class="tooltiptext"
                style={isAdditionalUploads && "left: 15%;"}
                >Document name and file selection are required to proceed</span
              >
            {/if}
          {/if}
        </span>
      </div>

      <div on:click={close} class="modal-x">
        <i class="fas fa-times" />
      </div>
    </div>
  </div>
  {#if $isToastVisible}
    <ToastBar />
  {/if}

  {#if showMultipleFileRequestBox}
    <ConfirmationDialog
      question={`The files you uploaded will be created as separate file request based with title as the file name , Would you like to proceed`}
      yesText="Yes, Upload"
      noText="No, cancel"
      yesColor="primary"
      noColor="white"
      on:message={""}
      on:yes={() => {
        showMultipleFileRequestBox = false;
        // pressedButton = true;
        isLoadingEnabled = true;
        upload_ok = true;
        dispatch("SeparateUploads", {
          name: cabinet_file_name,
          file: files.accepted,
          checkBoxStatus: checkBoxStatus,
          middleButtonPressed,
        });
      }}
      on:close={() => {
        showMultipleFileRequestBox = false;
        // pressedButton = false;
        isLoadingEnabled = false;
        upload_ok = true;
      }}
    />
  {/if}
</div>

<style>
  .file-header {
    display: block;
    font-weight: 600;
    font-family: "Nunito", sans-serif;
    color: #76808b;
  }

  .modal {
    margin: 0 2px;
  }

  .modal-extrabutton {
    padding-top: 0.5rem;
    text-align: center;
  }

  .name {
    padding-top: 1rem;
  }

  .fontfix {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
  }

  .name > p {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
    margin: 0;
  }

  .upload-mobile {
    margin-block: 1rem;
  }

  .submit-buttons {
    display: grid;
    grid-template-rows: 1fr;
    grid-template-columns: 1fr 2fr;
    text-align: right;
  }
  .submit-buttons-additional-files {
    display: grid;
    grid-template-rows: 1fr;
    grid-template-columns: 1fr 1fr 1fr;
    column-gap: 1rem;
  }
  .files {
    margin: 1rem 0;
    max-height: 130px;
    overflow-y: scroll;
  }
  .file {
    padding-left: 8px;
  }
  .drop-zone {
    padding-top: 2rem;
  }
  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 999;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-size: 24px;
    font-weight: bold;
    text-align: center;
    color: #2a2f34;
  }

  .modal-subheader {
    display: flex;
    justify-content: center;
    text-align: center;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
  }

  .modal {
    margin-top: 60px;
    position: absolute;
    width: calc(100vw - 4em);
    max-width: 32em;
    overflow: auto;
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    min-width: fit-content;
    z-index: 9991;
    min-height: 400px;
  }

  .modal-headers {
    display: flex;
    flex-flow: column nowrap;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .modal-x {
    position: absolute;
    font-size: 18px;
    cursor: pointer;
    top: 4px;
    right: 10px;
  }

  .checkbox {
    font-family: sans-serif;
    font-size: 14px;
  }

  .limiter.text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 12px;
    line-height: 24px;
    letter-spacing: 0.15px;

    color: #76808b;
    padding-bottom: 2rem; /* Stolen from Drop zone */
  }

  .supportedFilesText {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 12px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #76808b;
  }

  .tooltip {
    position: relative;
    display: inline-block;
  }

  .errormessage {
    font-family: "Nunito", sans-serif;
    color: #cc0033;
    font-size: 14px;
    line-height: 15px;
    margin: 5px 0 0;
  }

  :global(.drop-zone > div) {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 20px;
    border-width: 2px;
    border-radius: 2px;
    border-color: black;
    border-style: dashed;
    background-color: #fafafa;
    color: black;
    outline: none;
    transition: border 0.24s ease-in-out;
  }

  .tooltip .tooltiptext {
    visibility: hidden;
    width: 165px;
    background-color: #2a2f34;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 5px 0;
    position: absolute;
    z-index: 1;
    bottom: 110%;
    left: 73%;
    font-size: 10px;
    font-family: "Nunito", sans-serif;
  }

  .tooltip .tooltiptext::after {
    content: "";
    position: absolute;
    top: 100%;
    left: 50%;
    margin-left: -5px;
    border-width: 5px;
    border-style: solid;
    border-color: black transparent transparent transparent;
  }

  .tooltip:hover .tooltiptext {
    visibility: visible;
  }
  :global(.drop-zone > div:hover) {
    border-color: #2196f3;
  }

  @media only screen and (max-width: 767px) {
    .cancel-button {
      display: none;
    }
    .modal-header {
      font-size: 18px;
    }
    .modal-subheader {
      font-size: 14px;
      line-height: 20px;
      letter-spacing: 0.15px;
    }
    .submit-buttons {
      display: flex;
      flex-direction: column;
      flex-wrap: wrap;
      align-items: stretch;
      align-content: center;
    }

    .submit-buttons span:not(:last-child) {
      padding-bottom: 10px;
    }

    .submit-buttons span:last-child {
      text-align: center;
      width: 100%;
    }
    .submit-buttons-additional-files {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      justify-content: center;
    }
  }
  .required {
    color: rgb(221, 38, 38);
  }
</style>
