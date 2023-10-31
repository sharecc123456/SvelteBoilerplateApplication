<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { isMobile } from "../../helpers/util";
  import TextField from "../components/TextField.svelte";
  import Button from "../atomic/Button.svelte";
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import File from "../atomic/File.svelte";
  import { onMount } from "svelte";
  import Dropzone from "svelte-file-dropzone";
  import { allowedNonIACDocExtensions } from "../../helpers/fileHelper";

  export let multiple = true;
  export let specializedFor = "none";
  export let specialText = undefined;
  export let extraButton = undefined;
  export let requiredFileFormats =
    ".pdf, .xls, .png, .gif, .jpg, .jpeg, .hvec, .heic, .heif";
  export let fileSizeLimit = "18MB";
  export let uploadHeaderText = "Upload a document";

  export let allowAllFileTypes = false;
  export let requireIACwarning = false;
  export let specialNONIAC = false;
  let clicked = false;
  export let checkBoxStatus = false;
  export let checkBoxText = "";
  export let showCheckbox = false;

  export let allowNonIACFileTypes = [];
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";

  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";

  let showConfirmationOfInvalidIAC_Type = false;
  export let cabinet_file_name = "";
  let files = {
    accepted: [],
    rejected: [],
  };
  let pressedButton = false;
  console.log(cabinet_file_name)

  function handleFilesSelect(e) {
    const { acceptedFiles, fileRejections } = e.detail;

    if (multiple == true) {
      files.accepted = [...files.accepted, ...acceptedFiles];
      files.rejected = [...files.rejected, ...fileRejections];
    } else {
      files.accepted = acceptedFiles;
      files.rejected = fileRejections;
    }
    console.log(acceptedFiles);
  }

  function removeFile(index) {
    files.accepted.splice(index, 1);
    files.accepted = [...files.accepted];
  }

  export let unsupportedErrorText = "Unsupported File Format";
  function upload() {
    if (upload_ok) {
      uploadButtonClicked = true;
      pressedButton = true;
      var i = 0;
      var allowedIACWarningExtensions =
        /(\.jpg|\.jpeg|\.png|\.heif|\.heic|\.heifs|\.avif|\.avifs)$/i;
      for (i = 0; i < files.accepted.length; i++)
        if (files.accepted[i].size / 1048576 < 18) {
          //Size of file in bytes/ size of mb in bytes < 18mb
          if (
            files.accepted[i].name.toLowerCase().includes(".pdf") ||
            files.accepted[i].name.toLowerCase().includes(".pdfa")
          ) {
            // All is good in size and format
          } else if (
            allowedIACWarningExtensions.exec(
              files.accepted[i].name.toLowerCase()
            )
          ) {
            // File is good size but NOT IAC compatible
            if (requireIACwarning) {
              // Other Use Case Avoidence
              pressedButton = false;
              showConfirmationOfInvalidIAC_Type = true;
              upload_ok = false;
              uploadButtonClicked = false;
            }
          } else if (
            allowAllFileTypes &&
            allowedNonIACDocExtensions.exec(
              files.accepted[i].name.toLowerCase()
            )
          ) {
            // File is good but NOT IAC compatible Format
          } else if (
            allowNonIACFileTypes.includes(
              files.accepted[i].name.toLowerCase().split(".").pop()
            )
          ) {
            // allow specificed non iac files
          } else {
            showToast(unsupportedErrorText, 3000, "error", "MM");
            upload_ok = false;
            pressedButton = false;
            uploadButtonClicked = false;
          }
        } else {
          //Size too big
          upload_ok = false;
          pressedButton = false;
          showToast(
            `The file you've attempted to upload exceeds our file size limit (18MB). Try breaking it into smaller files, or contact your admin.`,
            6000,
            "error",
            "MM"
          );
          return;
        }

      if (!upload_ok) return;

      dispatch("done", {
        name: cabinet_file_name,
        file: multiple == true ? files.accepted : files.accepted[0],
        checkBoxStatus: checkBoxStatus,
      });
    }
  }

  let upload_ok = true;
  $: if (
    files.accepted.length === 0 ||
    (specializedFor == "directSendRequests" &&
      cabinet_file_name.trim() == "") ||
    (specializedFor == "cabinet" && cabinet_file_name.trim() == "") ||
    (specializedFor == "newTemplate" && cabinet_file_name == "")
  ) {
    upload_ok = false;
  } else {
    upload_ok = true;
  }

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;
  let uploadButtonClicked = false;
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

  const isFilenameRequired =
    specializedFor == "cabinet" ||
    specializedFor == "newTemplate" ||
    specializedFor == "directSendRequests" ||
    specializedFor == "additionalFileUploads";

  $: isUploadDisabled = (upload_ok, file_name) => {
    return isFilenameRequired
      ? !upload_ok ||
          file_name.length > 60 ||
          (file_name.replace(/\s/g, "").length < 1 && file_name.length >= 1)
      : !upload_ok;
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <span class="modal-headers">
        <span class="modal-header">{uploadHeaderText}</span>

        {#if specialText != "" && specialText != undefined && specialText != null}
          <span
            style="display: flex; justify-content: center;"
            class="modal-subheader">{specialText}</span
          >
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

      {#if specializedFor == "cabinet" || specializedFor == "newTemplate" || specializedFor == "directSendRequests" || specializedFor == "additionalFileUploads"}
        <div class="name">
          <p>
            {specializedFor == "cabinet"
              ? "Document"
              : specializedFor == "directSendRequests" ||
                specializedFor == "additionalFileUploads"
              ? "Request"
              : "Template"} Name
            <span class="required">*</span>
          </p>
          <TextField
            bind:value={cabinet_file_name}
            text={specializedFor == "directSendRequests"
              ? "Request Name"
              : "Document Name"}
            maxlength={"61"}
          />
          {#if cabinet_file_name.length > 60}
            <div class="errormessage" id="name">
              {"Character limit (60) reached."}
            </div>
          {/if}
          {#if cabinet_file_name.replace(/\s/g, "").length < 1 && cabinet_file_name.length >= 1}
            <div class="errormessage" id="name">
              {"All whitespaces not allowed."}
            </div>
          {/if}
        </div>
      {/if}

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
            text="Choose files to Upload"
          />
          {#if !isMobile()}
            <p class="fontfix">or</p>
            <span class="fontfix">Drag and drop files here</span>
          {/if}
          {#if requiredFileFormats.length !== 0}
            <span class="supportedFilesText">
              <i
                >{`Supported file types: ${requiredFileFormats.toUpperCase()}`}</i
              >
            </span>
          {/if}
        </Dropzone>
      </div>
      <span class="limiter text"
        ><i>The file size can up be up to {fileSizeLimit}</i></span
      >
      {#if files.accepted.length > 0}
        <div class="file-header">Selected Files</div>
      {/if}
      <div class="files">
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

      <div class="submit-buttons">
        <span on:click={close}>
          <Button color="light" text="Cancel" />
        </span>
        <span
          class="tooltip"
          on:click={(evt) =>
            isUploadDisabled(upload_ok, cabinet_file_name)
              ? () => {
                  console.log("disabled ...");
                }
              : upload()}
        >
          <LoadingButton
            color="primary"
            text={`Confirm ${
              specializedFor == "directSendRequests" ? "Send" : "Upload"
            }`}
            disabled={isUploadDisabled(upload_ok, cabinet_file_name) ||
              uploadButtonClicked}
            pressed={pressedButton}
          />
          {#if specializedFor == "newTemplate"}
            {#if !upload_ok || (cabinet_file_name.replace(/\s/g, "").length < 1 && cabinet_file_name.length >= 1)}
              <span class="tooltiptext"
                >Template name and file selection are required to proceed</span
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

  {#if showConfirmationOfInvalidIAC_Type}
    <ConfirmationDialog
      title="Not Compatible with Online Form Filling"
      question={`The file you are trying to upload is NOT compatible with Online Form Filling, if you would like your clients to use our built in completion system please export/convert the file to a PDF, this will allow you to edit and customize a form for your clients.`}
      yesText="Acknowledge"
      noText="Cancel"
      yesColor="gray"
      noColor="primary"
      on:message={() => {
        upload_ok = false;
      }}
      on:yes={() => {
        dispatch("done", { name: cabinet_file_name, file: files.accepted[0] });
      }}
      on:close={() => {
        showConfirmationOfInvalidIAC_Type = false;
        pressedButton = false;
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
  .files {
    margin: 1rem 0;
    max-height: 130px;
    overflow-y: scroll;
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
    font-family: "Lato", sans-serif;
    font-size: 24px;
    font-weight: bold;
    text-align: center;
    color: #2a2f34;
  }

  .modal-subheader {
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
    z-index: 1000;
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

  .tooltip .tooltiptext {
    visibility: hidden;
    width: 160px;
    background-color: black;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 5px 0;
    position: absolute;
    z-index: 1;
    bottom: 110%;
    left: 51%;
    font-size: 9px;
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
  .errormessage {
    display: inline-block;
    color: #cc0033;
    font-size: 12px;
    font-weight: bold;
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

  :global(.drop-zone > div:hover) {
    border-color: #2196f3;
  }

  @media only screen and (max-width: 786px) {
    .modal-header {
      font-size: 18px;
    }
    .modal-subheader {
      font-size: 14px;
      line-height: 20px;
      letter-spacing: 0.15px;
    }
  }
  @media only screen and (max-width: 425px) {
    .submit-buttons {
      display: flex;
      flex-direction: column;
      flex-wrap: wrap;
      align-items: stretch;
      align-content: center;
    }

    .submit-buttons span:first-child {
      padding-bottom: 10px;
    }

    .tooltip .tooltiptext {
      left: 0%;
    }
  }
  .required {
    color: rgb(221, 38, 38);
  }
</style>
