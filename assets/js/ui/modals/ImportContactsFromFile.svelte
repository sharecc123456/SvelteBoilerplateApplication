<script>
  /*
    Owner: MJ
    This feature allow to the user to upload an xls file with contacts.
  */
  import { createEventDispatcher, onMount } from "svelte";
  import Dropzone from "svelte-file-dropzone";
  import { isMobile } from "../../helpers/util";
  import Button from "../atomic/Button.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";
  import File from "../atomic/File.svelte";
  import csvFileReader from "../../helpers/csvFileReader";
  import Loader from "../components/Loader.svelte";
  import { newRecipient, getRecipients } from "BoilerplateAPI/Recipient";

  const dispatch = createEventDispatcher();

  //props
  export let titleText = "Bulk update users";
  const close = () => dispatch("close");
  const done = () =>
    dispatch("done", { oldRecipients: GetOldRecipientsIds, isValid: isValid });

  let oldRecipients = [];
  onMount(() => {
    oldRecipients = getRecipients();
  });

  const GetOldRecipientsIds = async () => {
    const data = await oldRecipients;
    const ids = data.map((item) => item.id);

    return ids;
  };

  //inner variables
  let modal;
  let isDone = false;
  let currentStep = 0; // 0 is the default step
  let steps = [
    { stepTitle: "Download CSV file" },
    { stepTitle: "Add or Edit" },
    { stepTitle: "Upload CSV file" },
  ];
  //later it can be multiple if we want
  let multiple = false;
  let files = {
    accepted: [],
    rejected: [],
  };
  //for set the stepper color if something is wrong
  let isValid = true;
  let headerValidation = false;
  let validationErrors = [];
  let isLoading = false;

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

  // back: -1, forward: 1
  const takeStep = (step) => {
    try {
      switch (step) {
        case 1: {
          currentStep += 1;
          return;
        }
        case -1: {
          currentStep -= 1;
          return;
        }
        default:
          throw new Error("takeStep: Parameter must be 1 or -1!");
      }
    } catch (error) {
      console.error(error.message);
    }
  };

  const handleFilesSelect = (e) => {
    const { acceptedFiles, fileRejections } = e.detail;

    //if the file was unvalid and user tries to upload it again
    //turn everything valid again
    isValid = true;
    isDone = false;
    validationErrors = [];

    if (multiple == true) {
      files.accepted = [...files.accepted, ...acceptedFiles];
      files.rejected = [...files.rejected, ...fileRejections];
    } else {
      files.accepted = acceptedFiles;
      files.rejected = fileRejections;
    }
    console.log(acceptedFiles);
  };

  const removeFile = (index) => {
    files.accepted.splice(index, 1);
    files.accepted = [...files.accepted];
  };

  const validFileCheck = () => {
    //it is in for loop because in the future we can allow multiple files too
    for (let i = 0; i < files.accepted.length; i++)
      if (files.accepted[i].size / 1048576 < 18) {
        //Size of file in bytes/ size of mb in bytes < 18mb
        if (files.accepted[i].name.includes(".csv")) {
          isValid = true;
        } else {
          isValid = false;
          //take back the user to the upload screen
          takeStep(-1);
          showToast("Unsupported File Format", 3000, "error", "BM");
        }
      } else {
        //Size too big
        isValid = false;
        //take back the user to the upload screen
        takeStep(-1);
        showToast(
          `The file you've attempted to upload exceeds our file size limit (18MB)`,
          6000,
          "error",
          "BM"
        );
      }
  };

  const capitalizeFirstLetter = (string) => {
    return string.charAt(0).toUpperCase() + string.slice(1);
  };

  const submitRecipient = async (recipient) => {
    try {
      isLoading = true;
      let reply = await newRecipient(recipient);

      if (reply.ok) {
        return true;
      }
    } catch (error) {
      console.error(error.message);
    } finally {
      isLoading = false;
    }
  };

  const ProcessRowRecord = (
    { Firstname, Lastname, Email, Company, PhoneNumber },
    headers,
    rowCount
  ) => {
    //header validation (once)

    console.log(rowCount);
    if (!headerValidation) {
      if (headers.length !== 5) {
        console.error(
          "Invalid header size! Make sure that the headers are: Firstname, Lastname, Email, Company, PhoneNumber. Please correct and repeat the process."
        );
        validationErrors = [
          ...validationErrors,
          "Invalid header size! Make sure that the headers are: Firstname, Lastname, Email, Company, PhoneNumber. Please correct and repeat the process.",
        ];
        isValid = false;

        return false;
      }

      if (
        headers[0].trim() !== "Firstname" ||
        headers[1].trim() !== "Lastname" ||
        headers[2].trim() !== "Email" ||
        headers[3].trim() !== "Company" ||
        headers[4].trim() !== "PhoneNumber"
      ) {
        console.error(
          "Invalid header name! Make sure that the headers are: Firstname, Lastname, Email, Company, PhoneNumber. Please correct and repeat the process."
        );
        validationErrors = [
          ...validationErrors,
          "Invalid header name! Make sure that the headers are: Firstname, Lastname, Email, Company, PhoneNumber. Please correct and repeat the process.",
        ];
        isValid = false;

        return false;
      }

      //if everything is okey don't check next time
      headerValidation = true;
    }

    //field validation
    //if a field is incorrect just continue drop the record(true and do nothing with data) and tell it to the user
    if (!/^[A-Za-z\s]+$/.test(Firstname)) {
      isValid = false;
      console.error("Invalid Firstname set: ", Firstname, rowCount);
      validationErrors = [
        ...validationErrors,
        `Invalid Firstname set at row: ${rowCount} with ${Firstname}!`,
      ];
      return true;
    } else if (!/^[A-Za-z\s]+$/.test(Lastname)) {
      isValid = false;
      console.error("Invalid Lastname set: ", Lastname, rowCount);
      validationErrors = [
        ...validationErrors,
        `Invalid Lastname set at row: ${rowCount} with ${Lastname}!`,
      ];

      return true;
    } else if (!/^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/.test(Email)) {
      isValid = false;
      console.error("Invalid email set: ", Email, rowCount);
      validationErrors = [
        ...validationErrors,
        `Invalid Email set at row: ${rowCount} with ${Email}!`,
      ];
      return true;
    } else if (
      !/^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$/im.test(
        PhoneNumber
      ) &&
      PhoneNumber.length != 0
    ) {
      isValid = false;
      console.error("Invalid phone number set ", PhoneNumber, rowCount);
      validationErrors = [
        ...validationErrors,
        `Invalid Phone Number set at row: ${rowCount} with ${PhoneNumber}!`,
      ];
      return true;
    } else {
      let newRecipient = {
        name: `${capitalizeFirstLetter(
          Firstname.trim()
        )} ${capitalizeFirstLetter(Lastname.trim())}`,
        organization: capitalizeFirstLetter(Company.trim()),
        email: Email.trim(),
        newRecipientFirstName: capitalizeFirstLetter(Firstname.trim()),
        newRecipientLastName: capitalizeFirstLetter(Lastname.trim()),
        phone_number: PhoneNumber.trim(),
      };

      //submit recipient
      submitRecipient(newRecipient);

      return true;
    }
  };

  const processCsvFile = () => {
    try {
      if (files.accepted.length === 0) {
        isValid = false;

        //take back the user to the upload screen
        takeStep(-1);
        showToast("Please attach a csv file!", 3000, "error", "BM");
        throw new Error("Please attach a file for the conversion!");
      }

      //validate the file before the process
      validFileCheck();

      if (isValid) {
        //reading and processing csvFile

        csvFileReader.loadFile(files, ProcessRowRecord);
        isDone = true;

        setTimeout(done, 5000);
      }
    } catch (error) {
      console.error(error.message);
    }
  };

  const download = () => {
    let csvFile = new Blob(
      [
        "sep=,\n",
        "Firstname,",
        "Lastname,",
        "Email,",
        "Company,",
        "PhoneNumber",
      ],
      {
        type: "text/csv",
      }
    );
    const url = window.URL.createObjectURL(csvFile);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", "Blank_CSV_Template.csv");
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          {titleText}
          <span on:click={close}>
            <slot name="closer" />
          </span>
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>
      </div>
    </div>
    <div class="content">
      <ul class="progressbar">
        {#each steps as step, i}
          {#if currentStep == i}
            <li
              class={isValid
                ? "valid validHalf validFilled"
                : "unValid unValidHalf unValidFilled"}
            >
              {step.stepTitle}
            </li>
          {:else if currentStep >= i}
            <li class={isValid ? "valid validFilled" : "unValid unValidFilled"}>
              {step.stepTitle}
            </li>
          {:else}
            <li>{step.stepTitle}</li>
          {/if}
        {/each}
      </ul>
      <!--Content of the stepper-->
      <div class="stepContentContainer">
        {#if currentStep === 0}
          <div class="stepContent">
            <h3>Download CSV file</h3>
            <div>
              <p>
                Download the template, or create you own (instructions on the
                next tab).
              </p>
            </div>
            <span class="button" on:click={() => download()}>
              <Button
                color="primary"
                icon="file-download"
                text="Download user info in CSV file"
              />
            </span>
          </div>
        {:else if currentStep === 1}
          <div class="stepContent">
            <h3>Add or edit user info in CSV template</h3>
            <div>
              <p>Required fields are at the top.</p>

              <p>
                Don't rename or rearrange the column headers. Firstname,
                Lastname, Email, Company PhoneNumber.
              </p>
              <div>
                <img src="/images/csv_template.png" alt="csv_template" />
              </div>
              <p>
                Fill each row. Don't leave any blank rows between entries you
                want included.
              </p>
              <p>
                Save to your device as as a .CSV file type when you're done.
              </p>
            </div>
          </div>
        {:else if currentStep === 2}
          <div>
            <div class="stepContent">
              <h3>Upload your saved CSV file below.</h3>
              <p>
                If you edited the template and the csv filled out correctly.
                Upload your file.
              </p>
            </div>
            <div class:drop-zone={!isMobile()} class:upload-mobile={isMobile()}>
              <Dropzone disableDefaultStyles={true} on:drop={handleFilesSelect}>
                <Button
                  color={files.accepted.length > 0 ? "light" : "primary"}
                  text="Choose file to Upload"
                />
                {#if !isMobile()}
                  <p class="fontfix">or</p>
                  <span class="fontfix">Drag and drop file here</span>
                {/if}
                <span class="supportedFilesText">
                  <i>{"Supported file types: .CSV"}</i>
                </span>
              </Dropzone>
            </div>
            <span class="limiter text"
              ><i>The file size can up be up to 18MB</i></span
            >
            {#if files.accepted.length > 0}
              <div class="file-header">Selected File</div>
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
          </div>
        {:else if currentStep === 3}
          {#if isLoading}
            <Loader loading />
          {:else if validationErrors.length === 0 && !isDone}
            <div class="stepContent">
              <h3>Hit submit to process the CSV file!</h3>
              <p>
                If any errors show up after import, your file may be formatted
                wrong or have invalid values.
              </p>
            </div>
          {:else if validationErrors.length === 0 && isDone}
            <div class="stepContent">
              <h3>Success!</h3>
              <p>The contacts from the CSV file successfully processed.</p>
            </div>
          {:else}
            <div class="errorContainer">
              <p>
                There are errors found in the CSV. Please correct them and try
                again!
              </p>
              {#each validationErrors as error}
                <p>{error}</p>
              {/each}
            </div>
          {/if}
        {/if}
      </div>
      <!--|||||||||||||||||||||||-->
      <div class="buttons-container">
        {#if currentStep === 0}
          <span>
            <Button color="light" disabled={true} text="Back" />
          </span>
        {:else}
          <span on:click={() => takeStep(-1)}>
            <Button color="light" text="Back" />
          </span>
        {/if}
        {#if currentStep === 3}
          <span on:click={() => processCsvFile()}>
            <Button color="primary" disabled={isDone} text="Submit" />
          </span>
        {:else}
          <span on:click={() => takeStep(1)}>
            <Button color="primary" text="Next" />
          </span>
        {/if}
      </div>
    </div>
  </div>
</div>
{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 98;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 60%;
    min-width: fit-content;
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 999;
    padding-top: 0;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-direction: column;
  }

  .inner-content {
    position: sticky;
    top: 0;
    z-index: 10;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    padding-right: 0.6875em;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
  }

  .content {
    display: flex;
    flex-direction: column;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .stepContentContainer {
    display: flex;
    justify-content: center;
    min-height: 350px;
  }

  .buttons-container {
    display: flex;
    justify-content: space-between;
    margin: 15px 25px 15px 25px;
  }

  .modal-x {
    font-size: 24px;
    left: calc(100% - 4em);
    top: 0.85em;
    cursor: pointer;
  }

  .button {
    flex: 1;
    text-decoration: none;
  }

  @media (max-width: 400px) {
    .button {
      width: 100%;
      text-decoration: none;
    }

    img {
      width: 200px;
    }
    p {
      font-size: 14px;
    }
  }

  @media (max-height: 750px) {
    .inner-content {
      padding: unset;
    }
    .buttons-container {
      margin-top: 10px;
      margin-bottom: 10px;
    }
    .stepContent h3 {
      margin: unset;
    }
    .stepContent p {
      margin: 0.5rem;
    }

    .stepContentContainer {
      display: flex;
      justify-content: center;
      min-height: 300px;
    }
  }

  .stepContent {
    display: flex;
    flex-flow: column nowrap;
    text-align: center;
    max-width: 100%;
  }

  .errorContainer {
    color: #db5244;
    overflow-y: scroll;
    overflow-x: hidden;
    height: 300px;
    text-align: center;
  }

  .fontfix {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
  }

  .file-header {
    display: block;
    font-weight: 600;
    font-family: "Nunito", sans-serif;
  }

  .files {
    max-height: 300px;
    /*overflow-y: scroll;*/
    padding-left: 8px;
  }

  /*STEPPER*/
  .progressbar {
    counter-reset: step;
    padding: 0;
  }

  .progressbar li {
    list-style-type: none;
    float: left;
    width: 33.33%;
    position: relative;
    text-align: center;
  }

  .progressbar li:before {
    content: "";
    width: 30px;
    height: 30px;
    line-height: 30px;
    border: 1px solid #ddd;
    display: block;
    text-align: center;
    margin: 0 auto 10px auto;
    border-radius: 50%;
    background-color: white;
  }

  .progressbar li::after {
    content: "";
    position: absolute;
    width: 100%;
    height: 1px;
    background-color: #ddd;
    top: 15px;
    left: -50%;
    z-index: -1;
  }

  .progressbar li:first-child::after {
    content: none;
  }

  .progressbar li.valid {
    color: black;
  }

  .progressbar li.valid::before {
    border-color: #2a2f34;
    background-color: #2a2f34;
  }

  .progressbar li.validHalf::before {
    background: linear-gradient(to right, #2a2f34 50%, white 50%) !important;
  }

  .progressbar li.validFilled::after {
    background-color: #2a2f34;
  }

  .progressbar li.unValid {
    color: black;
  }

  .progressbar li.unValid::before {
    border-color: #db5244;
    background-color: #db5244;
  }

  .progressbar li.unValid + li::after {
    background-color: #db5244;
  }

  .progressbar li.unValidHalf::before {
    background: linear-gradient(to right, #db5244 50%, white 50%) !important;
  }

  .progressbar li.unValidFilled::after {
    background-color: #db5244;
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
</style>
