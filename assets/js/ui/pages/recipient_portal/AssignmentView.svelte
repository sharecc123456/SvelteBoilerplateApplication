<script>
  import NavBar from "../../components/NavBar.svelte";
  import Dropdown from "../../components/Dropdown.svelte";
  import TextField from "../../components/TextField.svelte";
  import BottomBar from "../../components/BottomBar.svelte";
  import Modal from "../../components/Modal.svelte";
  import DashboardStatus from "../../components/DashboardStatus.svelte";
  import Button from "../../atomic/Button.svelte";
  import File from "../../atomic/File.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import { onMount } from "svelte";
  import {
    uploadFileRequest,
    uploadDocument,
    uploadFilledRequest,
  } from "BoilerplateAPI/RecipientPortal";
  import { reportCrash } from "BoilerplateAPI/CrashReporter";
  import { getAssignments } from "BoilerplateAPI/Assignment";
  import { featureEnabled } from "Helpers/Features";

  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";

  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import printJS from "print-js";
  import { isBrowserTypeSafari } from "Helpers/util";
  import { isMobile } from "../../../helpers/util";

  export let assignment;
  export let assignmentId;
  var requestProg;

  function findGetParameter(parameterName) {
    var result = null,
      tmp = [];
    location.hash.split("&").forEach(function (item) {
      tmp = item.split("=");
      if (tmp[0] === parameterName) result = decodeURIComponent(tmp[1]);
    });
    return result;
  }

  let defaultTab = findGetParameter("tab");

  const isSafari = isBrowserTypeSafari();

  // feature_flag:recipient_use_fill_popup
  const ff_useFillPopup = featureEnabled("recipient_use_fill_popup");

  function completed(x) {
    return x.state.status == 1 || x.state.status == 2 || x.state.status == 4;
  }

  let submitPopupReady = false;
  let showSubmitPopup = true;
  function calculateProgressPercentage(assign) {
    let totalItems =
      assign.file_requests.length + assign.document_requests.length;
    let completedItems =
      assign.file_requests.filter(completed).length +
      assign.document_requests.filter(completed).length;
    let finalValue = Math.max(0.05, completedItems / totalItems);
    `${Math.ceil(finalValue * 100)}` == 100
      ? (submitPopupReady = true)
      : (submitPopupReady = false); // Allow Popup
    return `${Math.ceil(finalValue * 100)}`;
  }

  onMount(() => {
    assignment.then((e) => {
      document
        .querySelector(".progress-set")
        .style.setProperty("--prog", `${calculateProgressPercentage(e)}%`);
      requestProg = calculateProgressPercentage(e);
      currentTab(e.file_requests.length, e.document_requests.length);

      if (defaultTab == "requests") {
        current_tab = 2;
      }
      submitPopupReady ? (showSubmitPopup = false) : (showSubmitPopup = true); // If viewing a submission we dont need to show the popup
    });
  });

  function state_to_buttontext(s, x) {
    switch (s) {
      case 0:
        if (!x) return "Fill / Sign";
        return "Start";
      case 1:
        if (!x) return "Review & Submit";
        return "Review";
      case 2:
        if (!x) return "View Submission";
        return "View";
      case 4:
        if (!x) return "View Submission";
        return "View";
      case 3:
        return "Revise";
    }
  }

  let currentlyStarted = undefined;
  function clickDocumentButton(docreq) {
    currentlyStarted = docreq;

    if (
      (docreq.state.status == 0 || docreq.state.status == 3) &&
      docreq.is_iac == false
    ) {
      showUploadModal = true;
    }
  }

  async function processDocUpload(evt) {
    let detail = evt.detail;
    let assign = await assignment;
    let reply = await uploadDocument(
      currentlyStarted,
      assign.recipient_id,
      assign.id,
      detail.file
    );

    if (reply.ok) {
      window.location.reload();
    } else {
      reportCrash("processDocUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
      alert("Failed to upload this document");
    }
  }

  async function processFRUpload(evt) {
    let detail = evt.detail;
    let assign = await assignment;
    let reply = await uploadFileRequest(
      currentFR,
      assign.recipient_id,
      assign.id,
      detail.file
    );
    console.log(reply);

    if (reply.ok) {
      assignment = getAssignments().then((assignments) => {
        let x = Array.from(assignments).filter((a) => a.id == assignmentId)[0];
        requestProg = calculateProgressPercentage(x);
        showUploadFRModal = false;
        currentFR = undefined;
        return x;
      });
    } else {
      showUploadFRModal = false;
      currentFR = undefined;
      reportCrash("processFRUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
      alert("Failed to upload this file request");
    }
  }

  async function submitDR(filereq) {
    let assign = await assignment;
    let reply = await uploadFilledRequest(
      filereq,
      assign.recipient_id,
      assign.id,
      currentDRText
    );

    if (reply.ok) {
      assignment = getAssignments().then((assignments) => {
        let x = Array.from(assignments).filter((a) => a.id == assignmentId)[0];
        requestProg = calculateProgressPercentage(x);
        showUploadFRModal = false;
        currentFR = undefined;
        return x;
      });
    } else {
      alert("failed to upload this fillin");
    }
  }

  // 0 -> general info
  // 1 -> document
  // 2 -> file requests
  // 3 -> additional info
  var current_tab = 1;
  var botButtonEnable = true;
  var onSingleReq = false;

  const min_tab = 1;
  const max_tab = 2;
  const num_buttons = max_tab - min_tab;

  let returnReasons = [
    { text: "Does not exist", ret: 0 },
    { text: "Decline to submit", ret: 1 },
    { text: "Expired", ret: 2 },
    { text: "Waiting on others", ret: 3 },
    { text: "Will provide hard copy", ret: 4 },
  ];

  // feature_Flag:due_dates
  const due_dates_enabled = false;
  let showUploadModal = false;

  let showUploadFRModal = false;
  let currentFR = undefined;

  let showFillModal = false;
  let currentDRText = "";

  function currentTab(FRLength, DRLength) {
    if (DRLength != 0) {
      current_tab = 1;
    } else if (FRLength != 0) {
      current_tab = 2;
    } else {
      current_tab = 1;
    }

    if (DRLength == 0 || FRLength == 0) {
      onSingleReq = true;
    }
    botButtonEnable = true;
  }

  function handleDropdownClick(aid, did, ret) {
    // assignment ID = aid     DocReq Compleation ID = DID
    if (ret == 1) {
      // Print
      printJS(`/completeddocument/${aid}/${did}/download`);
    } else if (ret == 2) {
      /* Download */
      window.location = `/completeddocument/${aid}/${did}/download`;
      //This takes the custom Doc info and downloads it
    }
  }
</script>

<NavBar
  backLink="Go to Dashboard"
  backLinkHref="#dashboard"
  imageSrc="images/phoenix.png"
  windowType="recipient"
  avatarInitials="LK"
/>

<section class="main">
  {#await assignment}
    <p>Loading....</p>
  {:then f_assignment}
    <section>
      <p class="name-line"><span>{f_assignment.name}</span></p>
      <span class="subject-line">Subject: {f_assignment.subject}</span>
    </section>
    <section class="dates">
      {#if due_dates_enabled}
        <p>Due on {f_assignment.due_date.date}</p>
      {:else}
        <p />
      {/if}
      <p>
        Received on {f_assignment.received_date.date} | {f_assignment
          .received_date.time}
      </p>
    </section>
    <section class="sender">
      <p>
        Sent by {f_assignment.sender.name}, {f_assignment.sender.organization}
      </p>
    </section>
    <section class="progressbar">
      <div class="progress-container">
        <div
          class="progress-set"
          style="--prog: {calculateProgressPercentage(f_assignment)}%"
        />
      </div>
      <p>Progress</p>
    </section>
    <section class="content">
      <div class="tabbar">
        <!-- <span class="tab" class:is-active={current_tab == 0} on:click={() => current_tab = 0}>General Info</span> -->
        <!-- <p hidden>{currentTab(f_assignment.file_requests.length, f_assignment.document_requests.length)}</p> -->
        {#if f_assignment.document_requests.length != 0}
          <span
            class="tab"
            class:is-active={current_tab == 1}
            on:click={() => (current_tab = 1)}>Documents</span
          >
        {/if}
        {#if f_assignment.file_requests.length != 0}
          <span
            class="tab"
            class:is-active={current_tab == 2}
            on:click={() => (current_tab = 2)}>Requests</span
          >
        {/if}
        <!-- <span class="tab">Additional Info</span> -->
      </div>
      <div class="main-content">
        {#if current_tab == 1}
          <div class="table">
            <div class="tr th">
              <div class="td td-document-name">
                <span class="first-cell">Document name</span>
              </div>
              <div class="td td-status-text mobile-only">Status / Action</div>
              <div class="td td-status-text desktop-only">Status</div>
              <div class="td td-action desktop-only">Action</div>
            </div>
            {#each f_assignment.document_requests as docreq}
              <div class="tr actual-line">
                <div class="td td-document-name">
                  <div class="document-name-container">
                    <span
                      class="document-name"
                      class:is-required={docreq.required}>{docreq.name}</span
                    >
                    <span class="document-description"
                      >{docreq.description}</span
                    >
                    <span class="document-instruction"
                      >{docreq.instruction}</span
                    >
                  </div>
                </div>
                <div class="td td-status-text mobile-only">
                  <div class="mobile-container">
                    <DashboardStatus recipient={true} state={docreq.state} />
                    {#if docreq.is_info}
                      <a href={`#view/${docreq.id}`}>
                        <Button text="View" />
                      </a>
                    {:else}
                      <div
                        on:click={clickDocumentButton(docreq)}
                        class="td-action-inner"
                      >
                        {#if docreq.state.status == 2 || docreq.state.status == 4}
                          <a
                            href={`#submission/view/1/${f_assignment.id}/${docreq.completion_id}`}
                          >
                            <Button
                              color="light"
                              text={state_to_buttontext(
                                docreq.state.status,
                                true
                              )}
                            />
                          </a>
                        {:else if docreq.is_iac && (docreq.state.status == 0 || docreq.state.status == 3)}
                          <a
                            href={`#iac/fill/${docreq.iac_document_id}/${f_assignment.id}`}
                          >
                            <Button
                              text={state_to_buttontext(
                                docreq.state.status,
                                true
                              )}
                            />
                          </a>
                        {:else}
                          <div>
                            <Button
                              text={state_to_buttontext(
                                docreq.state.status,
                                true
                              )}
                            />
                          </div>
                        {/if}
                      </div>
                    {/if}
                  </div>
                </div>
                <div class="td td-status-text desktop-only">
                  {#if docreq.is_info == false}
                    <DashboardStatus recipient={true} state={docreq.state} />
                  {/if}
                </div>
                <div class="td td-action desktop-only">
                  {#if docreq.is_info}
                    <a href={`#view/${f_assignment.id}/${docreq.id}`}>
                      <Button text="View" />
                    </a>
                  {:else}
                    <div
                      on:click={clickDocumentButton(docreq)}
                      class="td-action-inner"
                    >
                      {#if docreq.state.status == 2 || docreq.state.status == 4}
                        <a
                          href={`#submission/view/1/${f_assignment.id}/${docreq.completion_id}`}
                        >
                          <Button
                            color="light"
                            text={state_to_buttontext(
                              docreq.state.status,
                              false
                            )}
                          />
                        </a>
                        <div class="td-action-ext">
                          <Dropdown
                            triggerType="ellipsis"
                            clickHandler={(ret) => {
                              handleDropdownClick(
                                f_assignment.id,
                                docreq.completion_id,
                                ret
                              );
                            }}
                            elements={[
                              {
                                ret: 1,
                                icon: "print",
                                text: "Print",
                                disabled: isSafari || isMobile(),
                              },
                              { ret: 2, icon: "download", text: "Download" },
                            ]}
                          />
                        </div>
                      {:else if docreq.is_iac && (docreq.state.status == 0 || docreq.state.status == 3)}
                        <a
                          href={`#iac/fill/${docreq.iac_document_id}/${f_assignment.id}`}
                        >
                          <Button
                            text={state_to_buttontext(
                              docreq.state.status,
                              false
                            )}
                          />
                        </a>
                      {:else}
                        <div>
                          <Button
                            text={state_to_buttontext(
                              docreq.state.status,
                              false
                            )}
                          />
                        </div>
                      {/if}
                    </div>
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        {:else if current_tab == 2}
          <div class="table" style="margin-bottom: 40px;">
            <div class="tr th">
              <div class="td td-r-name">
                <span class="first-cell">Request</span>
              </div>
              <div class="td td-r-sicon" />
              <div class="td td-r-stxt">Status</div>
              <div class="td td-r-action">Action</div>
              <div class="td td-r-list" />
            </div>
            {#each f_assignment.file_requests as filereq}
              <div
                class="tr actual-line"
                class:uploaded={filereq.state.status == 2 ||
                  filereq.state.status == 4}
              >
                <div class="td td-r-name">
                  <div class="request-name-container">
                    <span
                      class="request-name"
                      class:is-required={filereq.required}>{filereq.name}</span
                    >
                    <span class="request-instruction">
                      {#if filereq.type == "file"}
                        Please locate & upload.
                      {:else if filereq.type == "data"}
                        {#if filereq.state.status == 2 || filereq.state.status == 4}
                          {filereq.value}
                        {:else}
                          Please fill in this information.
                        {/if}
                      {/if}
                    </span>
                  </div>
                </div>
                <div class="td td-r-sicon">
                  <!-- <div class="td-status-inner">
							<span class={status_to_class(filereq.state.status)}>
								<FAIcon iconStyle={fastyle_for_status(filereq.state.status)} icon={faicon_for_status(filereq.state.status)} />
							</span>
						</div> -->
                </div>
                <div class="td td-r-stxt">
                  <!-- <div class="td-status-text-inner">
							<span class={status_to_class(filereq.state.status)}>
							{status_to_text(filereq.state.status)}
							</span>
							{#if filereq.state.status == 2 || filereq.state.status == 3}
							<span class="td-status-text-inner-status-date">
								{filereq.state.date} | {filereq.state.time}
							</span>
							{/if}
						</div> -->
                  <DashboardStatus
                    recipient={true}
                    colorful={true}
                    state={filereq.state}
                  />
                </div>
                <div class="td td-r-action">
                  <span
                    on:click={() => {
                      showUploadFRModal = true;
                      currentFR = filereq;
                    }}
                  >
                    {#if filereq.type == "file"}
                      {#if filereq.state.status == 0}
                        <Button text="Upload" />
                      {:else if filereq.state.status == 2}
                        <!-- nothing  -->
                      {:else}
                        <Button color="gray" text="Upload" />
                      {/if}
                    {/if}
                  </span>
                  {#if filereq.type == "data"}
                    {#if ff_useFillPopup}
                      <span
                        on:click={() => {
                          showFillModal = true;
                          currentDRText = filereq.value;
                          currentFR = filereq;
                        }}
                      >
                        {#if filereq.state.status == 0}
                          <Button text="Fill" />
                        {:else if filereq.state.status == 2}
                          <Button color="gray" text="Update" />
                        {:else}
                          <Button color="gray" text="Update" />
                        {/if}
                      </span>
                    {:else}
                      <TextField width="100%" text={filereq.name} />
                    {/if}
                  {/if}
                  {#if filereq.type == "file"}
                    <!-- <Dropdown text="Not available" elements={returnReasons} /> -->
                  {/if}
                </div>
                <div class="td td-r-list">
                  <div class="file-list-container">
                    {#each filereq.file_names as fn}
                      <span class="file">
                        <File name={fn} />
                      </span>
                    {/each}
                  </div>
                </div>
              </div>
            {/each}
          </div>
        {/if}
      </div>
    </section>
    {#if num_buttons != 1}
      <section class="navigation-buttons">
        <div
          class="back-button"
          on:click={() =>
            current_tab == min_tab ? current_tab : current_tab--}
        >
          <Button color="light" disabled={current_tab == min_tab} text="Back" />
        </div>
        <div
          class="next-button"
          on:click={() =>
            current_tab == max_tab ? current_tab : current_tab++}
        >
          <Button text="Next" disabled={current_tab == max_tab} />
        </div>
      </section>
    {/if}
  {:catch error}
    <p>An error occured while fetching the assignment: {error}</p>
  {/await}
</section>

{#if showUploadModal}
  <UploadFileModal
    on:close={() => {
      showUploadModal = false;
    }}
    on:extraClicked={() => {
      window.location = `/rawdocument/${currentlyStarted.id}/download`;
    }}
    on:done={processDocUpload}
    requireIACwarning={false}
    multiple={false}
    extraButton="Download"
    specialNONIAC={true}
  />
{/if}

{#if showUploadFRModal}
  <UploadFileModal
    requireIACwarning={false}
    multiple={false}
    on:close={() => {
      showUploadFRModal = false;
      currentFR = undefined;
    }}
    on:done={processFRUpload}
    uploadHeaderText={currentFR.name}
    specialText={`Locate, scan, or take a picture of the requested file and upload it below.`}
  />
{/if}

{#if showFillModal}
  <Modal
    on:close={() => {
      showFillModal = false;
      currentFR = undefined;
    }}
  >
    <p slot="header">Data Request Fulfillment</p>

    <div class="modal-subheader">
      The checklist requires you to provide the information below. Your input is
      held to the highest available security standards.
    </div>

    <div class="modal-field">
      <div class="name">{currentFR.name}:</div>
      <TextField
        icon="lock"
        bind:value={currentDRText}
        iconStyle="regular"
        width="100%"
        text={currentFR.name}
      />
    </div>

    <div class="modal-buttons">
      <span
        on:click={() => {
          showFillModal = false;
          currentFR = undefined;
        }}
      >
        <Button color="white" text="Cancel" />
      </span>
      <span
        on:click={() => {
          showFillModal = false;
          submitDR(currentFR);
          currentFR = undefined;
        }}
      >
        <Button color="secondary" text="Done" />
      </span>
    </div>
  </Modal>
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if botButtonEnable}
  <BottomBar
    leftButtons={[
      {
        button: "Back",
        color: "white",
        disabled: current_tab == 2 && onSingleReq == false ? false : true,
        ignore: onSingleReq ? true : false,
        evt: "prev",
      },
    ]}
    rightButtons={[
      {
        button: "Save & Finish Later",
        color: "white",
        disabled: requestProg == 100 ? true : false,
        evt: "return",
      },
      {
        button:
          current_tab == 1 && onSingleReq == false
            ? "Next"
            : onSingleReq
            ? "Finish & Submit"
            : "Finish & Submit",
        color:
          current_tab == 1 && onSingleReq == false
            ? "primary"
            : onSingleReq
            ? "secondary"
            : "secondary",
        disabled:
          (current_tab == 1 || requestProg == 100) && onSingleReq == false
            ? false
            : requestProg == 100 && onSingleReq
            ? false
            : true,
        evt:
          current_tab == 1 && onSingleReq == false
            ? "next"
            : requestProg == 100
            ? "fin"
            : onSingleReq
            ? "fin"
            : "error",
      },
    ]}
    on:error={() => {
      alert("Uh oh something went wrong!");
    }}
    on:fin={() => {
      showToast(`Success! Checklist submitted.`, 2000, "default", "MM");
      setTimeout(() => {
        window.location.hash = "#dashboard";
      }, 2000);
    }}
    on:return={() => {
      showToast(`Saved but not finished!`, 2000, "white", "MM");
      setTimeout(() => {
        window.location.hash = "#dashboard";
      }, 2000);
    }}
    on:next={() => {
      if (current_tab == 2) {
        alert(current_tab);
      } else {
        current_tab = 2;
      }
    }}
    on:prev={() => {
      if (current_tab == 1) {
        alert("Already on DR");
      } else {
        current_tab = 1;
      }
    }}
  />
{/if}

{#if submitPopupReady && showSubmitPopup}
  <ConfirmationDialog
    title="All done?"
    question="You've completed all requests in this checklist. Ready to submit?"
    yesText="Yes, Submit"
    noText="Not Yet"
    yesColor="secondary"
    noColor="white"
    noLeftAlign={true}
    on:close={() => {
      showSubmitPopup = false;
    }}
    on:yes={() => {
      showToast(`Success! Checklist submitted.`, 2000, "default", "MM");
      setTimeout(() => {
        window.location.hash = "#dashboard";
      }, 2000);
    }}
  />
{/if}

<style>
  section.main {
    background-color: #fcfdff;
    padding-top: 1.5rem;
    padding-left: 2rem;
    padding-right: 2rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    margin-bottom: 6rem;
  }

  .name-line {
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    /* identical to box height, or 142% */

    /* Black */
    color: #2a2f34;

    margin-block-end: 0;
  }

  .subject-line {
    /* Heading 6 - 18px */
    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    /* identical to box height, or 122% */

    /* Black */
    color: #2a2f34;
  }

  section.dates {
    padding-top: 1rem;
  }

  .dates p {
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;
    /* or 150% */
    letter-spacing: 0.5px;

    /* Gray 700 */
    color: #606972;
    margin-block-start: 0;
    margin-block-end: 0;
  }

  .sender p {
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;
    /* identical to box height, or 150% */
    letter-spacing: 0.5px;

    /* Gray 500 */
    color: #76808b;
  }

  .progress-container {
    /*background: linear-gradient(to right, #2A2F34, #E9F1FA var(--prog), #E9F1FA);*/
    background-color: #e9f1fa;
    box-shadow: inset 0px 2px 4px rgba(23, 31, 70, 0.12);
    /*background-repeat: no-repeat;*/
    /*position: fixed;*/
    width: 100%;
    height: 10px;
    z-index: 1;
    border-radius: 10px;
  }

  .progress-set {
    width: var(--prog);
    background-color: #2a2f34;
    box-shadow: 2px 0px 4px rgba(23, 31, 70, 0.12),
      1px 2px 5px rgba(23, 31, 70, 0.24);
    height: 10px;
    z-index: 2;
    border-radius: 10px;
  }

  .progressbar p {
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.1px;

    /* D2 */
    color: #808191;
  }

  section.navigation-buttons {
    padding-top: 1rem;
    display: flex;
    width: 100%;
    flex-flow: row nowrap;
    justify-content: space-between;
  }

  section.content {
    padding-top: 2rem;
  }

  .tabbar {
    display: flex;
    width: 100%;
    flex-flow: row nowrap;
  }

  .tab {
    flex-grow: 1;
    justify-content: center;
    text-align: center;

    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    /* identical to box height, or 122% */

    /* Gray 300 */
    color: #b3c1d0;
    padding-bottom: 1rem;

    cursor: pointer;
  }

  .tab:hover {
    border-bottom: 1px solid #2a2f3462;
  }

  .tab.is-active {
    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    /* identical to box height, or 122% */

    /* Black */
    color: #2a2f34;

    border-bottom: 2px solid #2a2f34;

    cursor: default;
  }

  .main-content {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding-top: 2rem;
  }

  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 0 0 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    white-space: normal;
    justify-content: left;

    padding-bottom: 0.5rem;
    border-bottom: 0.5px solid #b3c1d0;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    /* identical to box height, or 114% */

    /* Gray 700 */
    color: #606972;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
    justify-content: right;
    /*word-break: break-word;
		overflow: hidden;
		text-overflow: ellipsis;*/
    min-width: 0px;
  }

  .actual-line {
    padding-top: 1rem;
  }

  .actual-line.uploaded {
    background-color: #eaf7f0;
  }

  .td.td-document-name {
    display: flex;
    flex: 4 4 10%;
    justify-content: left;
  }

  .td.td-status-text {
    display: flex;
    flex: 1 1 5%;
  }

  .td.td-action {
    display: flex;
    flex: 1 1 5%;
    justify-content: left;
  }

  .td-action-inner {
    max-height: 36px;
  }

  .td-action-ext {
    position: relative;
    left: 158px;
    top: -36px;
    display: inline-flex;
    justify-content: flex-end;
    align-items: center;
    padding-top: 5px;
  }

  .tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
  }

  .first-cell {
    padding-left: 2rem;
  }

  .document-name-container {
    display: flex;
    flex-flow: column nowrap;
    padding-left: 2rem;
  }

  .document-name {
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;
    /* identical to box height, or 150% */
    letter-spacing: 0.5px;

    /* Black */
    color: #2a2f34;
  }

  .document-name.is-required::after {
    content: " *";
    color: red;
  }

  .document-instruction,
  .document-description {
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.25px;

    /* Grey/100 */
    color: #7e858e;
  }

  /* File Requests */
  .td-r-name {
    display: flex;
    width: 25%;
    flex: 0 0 auto;
  }

  .td-r-sicon {
    display: flex;
    width: 24px;
    flex: 0 0 auto;

    text-align: right;
    justify-content: right;
  }

  .td-r-stxt {
    display: flex;
    width: calc(25% - 24px);
    flex: 0 0 auto;
  }

  .td-r-action {
    display: flex;
    flex-flow: row wrap;
    width: 25%;
    flex: 1 0 auto;
  }

  .td-r-list {
    display: flex;
    width: 25%;
    justify-content: left;
    flex: 0 0 auto;
  }

  .request-name-container {
    display: flex;
    flex-flow: column nowrap;
    padding-left: 2rem;
  }

  .request-name {
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;
    /* identical to box height, or 150% */
    letter-spacing: 0.5px;

    /* Black */
    color: #2a2f34;
  }

  .request-name.is-required::after {
    content: " *";
    color: red;
  }

  .request-instruction {
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.25px;

    /* Grey/100 */
    color: #7e858e;
  }

  .file-list-container {
    display: flex;
    flex-flow: row wrap;
  }

  .td-status-text.mobile-only {
    display: none;
  }

  .mobile-container {
    display: flex;
    flex-flow: column wrap;
  }

  @media screen and (max-width: 1100px) {
    .td-status-text.mobile-only {
      display: flex;
      text-align: center;
      justify-content: center;
    }

    .td-status-text.desktop-only,
    .td-action.desktop-only {
      display: none;
    }
  }

  .modal-subheader {
    padding-bottom: 2rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
  }

  .modal-field > .name {
    font-family: "Nunito", sans-serif;
    padding-bottom: 1rem;
  }

  .modal-field {
    padding-bottom: 2rem;
  }

  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
  }
</style>
