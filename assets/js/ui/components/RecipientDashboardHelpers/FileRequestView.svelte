<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Dropdown from "../Dropdown.svelte";
  import RecipientTaskDescription from "../Recipient/RecipientTaskDescription.svelte";
  import FileActionButton from "../Recipient/FileActionButton.svelte";
  import DashboardStatus from "../DashboardStatus.svelte";
  import TextField from "../TextField.svelte";
  import Button from "../../atomic/Button.svelte";
  import { isMobile } from "../../../helpers/util";
  import DocStatusSm from "../../atomic/molecules/DocStatusSm.svelte";

  const dispatch = createEventDispatcher();

  export let filereq,
    assignment,
    checklistActions,
    dropdownClick,
    ff_useFillPopup,
    focused,
    handleCompletedFileRequestDropDown,
    EXTRAFILEUPLOADSDEFAULTNAME,
    EXTRAFILEUPLOADSDEFAULTDESCRIPTION,
    reRenderTextField = true;

  function getTotalRowLenght() {
    return (
      assignment.document_requests.length +
      assignment.file_requests.length +
      assignment.forms.length
    );
  }

  export let fileActionButtons = (_x) => {};
  let savingDataRequest = false;

  function getIcons() {
    if (filereq.type == "file" && filereq.flags === 4) {
      return { icon: "cloud-upload", style: "regular" };
    } else if (filereq.type == "file") {
      return { icon: "paperclip", style: "regular" };
    } else if (filereq.type == "data") {
      return { icon: "font-case", style: "regular" };
    } else if (filereq.type == "task") {
      return { icon: "thumbtack", style: "regular" };
    }
  }

  function reRender() {
    reRenderTextField = false;
    setTimeout(() => {
      reRenderTextField = true;
    }, 0);
  }

  $: focused, reRender();
</script>

<div
  class="checklist-tr child outer-border"
  class:greenShade={filereq.state.status == 1 ||
    filereq.state.status == 2 ||
    filereq.state.status === 4 ||
    filereq.state.status === 5 ||
    filereq.state.status === 6}
  class:red-shade={filereq.state.status == 3}
  class:child-row={filereq.flags === 6}
  style={`${filereq.flags === 4 ? "order: " + getTotalRowLenght() + ";" : ""}`}
  on:click={() => {
    dispatch("file_req_click");
  }}
>
  <div class="td chevron" />
  <div class="td checklist">
    <div
      class="filerequest checklist-icon {filereq.type == 'data'
        ? 'requestwithinput'
        : ''}"
      style="cursor: pointer;"
      on:click={() => {
        if (filereq.state.status != 4) {
          dispatch("fileRequestLineClick");
        }
      }}
    >
      <span>
        {#if getIcons()}
          <span>
            <FAIcon icon={getIcons().icon} iconStyle={getIcons().style} />
          </span>
        {/if}
      </span>
      <div
        class="filerequest-name"
        on:click={() => {
          dispatch("show_modal");
        }}
      >
        <span class="truncate">
          {filereq.flags !== 4 ? filereq.name : EXTRAFILEUPLOADSDEFAULTNAME}
        </span>
        {#if filereq.type == "task"}
          <RecipientTaskDescription description={filereq.description} />
          {#if filereq.link && Object.keys(filereq.link).length !== 0 && filereq.link.url != ""}
            <div style="margin-top: 0px">
              <a target="_blank" href={filereq.link.url}>
                {filereq.link.url}
              </a>
            </div>
          {/if}
        {:else if filereq.type == "file"}
          <div class="truncate">
            {filereq.flags === 6
              ? "Task Confirmation Request"
              : filereq.flags !== 4
              ? filereq?.description
              : EXTRAFILEUPLOADSDEFAULTDESCRIPTION}
          </div>
        {:else if filereq.type == "data"}
          {#if filereq.description != ""}
            <div class="truncate">
              {filereq.description ? filereq.description : ""}
            </div>
          {/if}
          {#if filereq.state.status != 4 && filereq.state.status != 2 && filereq.state.status != 5}
            <div
              id="filereq-edit-{filereq.id}"
              class="input-box"
              on:click|stopPropagation={() => {
                dispatch("handleFocusIndex", filereq);
              }}
            >
              <TextField
                maxlength={"60"}
                text={"Data Input"}
                height={"auto"}
                bind:value={filereq.value}
                focused={!isMobile() && focused && focused.id == filereq.id}
                reFocused={false}
                enterCallback={() => {
                  if (filereq?.value != "") {
                    setTimeout(() => {
                      if (!savingDataRequest) {
                        savingDataRequest = true;
                        dispatch("handleEnterKeyDown");
                      }
                    }, 500);
                  }
                }}
                on:blur={() => {
                  if (filereq?.value != "") {
                    setTimeout(() => {
                      console.log("blur");
                      if (!savingDataRequest) {
                        savingDataRequest = true;
                        dispatch("saveDataRequest");
                      }
                    }, 500);
                  }
                }}
              />
            </div>
          {:else if filereq.state.status != 5}
            <div>
              Submitted value: <strong>{filereq.value}</strong>
            </div>
          {/if}
        {/if}
        <DocStatusSm status={filereq.state.status} date={filereq.state.date} />
        <div class="mobile">
          {#if filereq.return_comments}
            <div style="font-size: 12px;">
              Reason for return: {filereq.return_comments}
            </div>
          {:else if filereq.missing_reason}
            <div style="font-size: 12px;">
              Missing Reason: {filereq.missing_reason}
            </div>
          {/if}
        </div>
      </div>
      <div class="mobile ellipsis-btn">
        {#if filereq.type == "file" && (filereq.state.status == 0 || filereq.state.status == 5)}
          <Dropdown
            elements={checklistActions(
              assignment,
              filereq.type,
              filereq,
              "upload"
            )}
            clickHandler={(ret) => {
              dropdownClick(assignment, ret, filereq, filereq.type);
            }}
            triggerType="ellipsis"
          />
        {:else if filereq.type == "file" && (filereq.state.status == 2 || filereq.state.status == 4)}
          <Dropdown
            elements={checklistActions(
              assignment,
              filereq.type,
              filereq,
              "completed"
            )}
            clickHandler={(ret) => {
              handleCompletedFileRequestDropDown(
                assignment,
                ret,
                filereq,
                filereq.type
              );
            }}
            triggerType="ellipsis"
          />
        {/if}
      </div>
    </div>
  </div>
  <div class="td requestor" />
  <div class="td status">
    <DashboardStatus
      time={filereq.state.time}
      recipient={true}
      state={filereq.state}
      reason={filereq.return_comments}
      isMissing={filereq.missing_reason}
      row={filereq}
      isExpirationEnabled={filereq.allow_edit_expiration}
      expiration_info={filereq.expiration_info}
    />
  </div>
  <div class="td actions actions-btn">
    <div class="btnGroup">
      <div style="display: grid; ">
        {#if (filereq.name === "Proof of Event Insurance") & (filereq.type == "file")}
          <div style="flex:1;margin-right: 1rem;">
            <a
              href="https://uat.obi.jauntin.com/?v=DEMO-000"
              target="_blank"
              style="text-decoration: none;"
            >
              <Button text="Get a policy" color="secondary" />
            </a>
          </div>
        {/if}
        <div
          class="actionbtnGroup {filereq.state.status === 2 ||
          filereq.state.status === 4
            ? 'sm-hide'
            : ''}"
        >
          <FileActionButton
            {ff_useFillPopup}
            {filereq}
            on:onProgressEvent
            handleFileClick={() => {
              if (filereq.type == "data") {
                savingDataRequest = true;
                dispatch("handleFileClick");
              } else {
                dispatch("handleFileClick");
              }
            }}
          />
          {#if (filereq.state.status === 2 || filereq.state.status === 4) && filereq.type == "file"}
            <span
              style="margin-left: 10px"
              on:click={() => {
                window.location = `/completedrequest/${assignment.id}/${filereq.completion_id}/download/completed`;
              }}
            >
              <Button color="light" icon="download" text={"Download"} />
            </span>
          {/if}
          {#if filereq.state.status == 0 && filereq.type == "data"}
            <span
              on:click|stopPropagation={() => {
                dropdownClick(assignment, "", filereq, filereq.type);
              }}
            >
              <Button color="light" text={"Not Applicable"} />
            </span>
          {/if}
          {#if filereq.state.status == 0 && filereq.type == "file"}
            {#if filereq.flags === 4}
              <!-- Missing Reasons not Required for extra file uploads -->
            {:else}
              <span on:click={() => {}}>
                <Dropdown
                  text="Unavailable"
                  elements={fileActionButtons(filereq)}
                  clickHandler={(ret) => {
                    dropdownClick(assignment, ret, filereq, filereq.type);
                  }}
                />
              </span>
            {/if}
          {/if}
        </div>
      </div>
    </div>
    <div class="desktop">
      {#if filereq.type == "file" && (filereq.state.status == 0 || filereq.state.status == 5)}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "upload"
          )}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, filereq, filereq.type);
          }}
          triggerType="vellipsis"
        />
      {:else if filereq.type == "file" && (filereq.state.status == 2 || filereq.state.status == 4)}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "completed"
          )}
          clickHandler={(ret) => {
            handleCompletedFileRequestDropDown(
              assignment,
              ret,
              filereq,
              filereq.type
            );
          }}
          triggerType="vellipsis"
        />
      {:else if filereq.state.status == 0 && filereq.type == "task"}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "markAsDone"
          )}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, filereq, filereq.type);
          }}
          triggerType="vellipsis"
        />
      {:else if filereq.state.status == 2 && filereq.type == "task"}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "details"
          )}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, filereq, filereq.type);
          }}
          triggerType="vellipsis"
        />
      {:else if filereq.state.status == 3 && filereq.type == "task"}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "Returndetails"
          )}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, filereq, filereq.type);
          }}
          triggerType="vellipsis"
        />
      {:else if filereq.state.status == 3 && filereq.type == "data"}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "Update"
          )}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, filereq, filereq.type);
          }}
          triggerType="vellipsis"
        />
      {:else}
        <Dropdown
          elements={checklistActions(
            assignment,
            filereq.type,
            filereq,
            "other"
          )}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, filereq, filereq.type);
          }}
          triggerType="vellipsis"
        />
      {/if}
    </div>
  </div>
</div>

<style>
  a {
    width: 250px;
    display: block;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  }

  .greenShade {
    background: #d1fae5 !important;
  }

  .red-shade {
    border-color: #db5244 !important;
    border-width: 2px !important;
    border-style: dashed !important;
  }

  .child-row {
    border-left: solid 5px black !important;
  }

  .td {
    font-family: "Nunito", sans-serif;
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    min-width: 0px;
    color: var(--text-secondary);
    /*white-space: nowrap;*/
  }
  .checklist-tr {
    /* width: 100%; */
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    position: relative;
  }
  .checklist-tr:not(.checklist-th) {
    display: grid;
    grid-template-columns: 30px 1fr 1fr;
    grid-template-areas:
      "a b b"
      ". e e";
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #2a2f34;
    padding: 0.5rem;
    padding-bottom: 0;
    position: relative;

    row-gap: 0.3rem;
    align-items: center;
  }
  .checklist-tr.child {
    width: 85%;
    margin: 0.5rem auto;
    padding: 0.5rem;
    display: grid;
    grid-template-columns: 30px 1fr 1fr;
    grid-template-areas:
      "b b b"
      ". e e";
    font-style: normal;
  }
  .td.chevron {
    place-items: center;
    height: 100%;
    margin-left: 5px;
    grid-area: a;
  }
  .td.checklist {
    grid-area: b;
  }
  .td.requestor {
    display: none;
    grid-area: c;
  }
  .td.status {
    display: none;
    grid-area: d;
  }
  .td.actions {
    /* width: max-content; */
    grid-area: e;
    display: flex;
    justify-content: flex-end;
    display: flex;
    align-items: center;
    margin-left: 20px;
  }
  .actions-btn :global(button) {
    margin-bottom: 0;
  }
  .checklist-tr.child .td.actions {
    width: 86%;
    display: grid;
    grid-template-columns: 1fr 20px;
    column-gap: 0.3rem;
    justify-items: center;
    justify-self: center;
    margin-left: 0.5rem;
  }
  .btnGroup {
    width: 100%;
    display: flex;
    justify-content: flex-end;
    align-items: center;
    margin-right: 13px;
  }

  .actionbtnGroup {
    width: 100%;
    display: flex;
    gap: 8px;
    justify-content: flex-end;
    align-items: center;
  }
  .filerequest {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
  }
  .requestwithinput {
    align-items: center;
  }
  .filerequest > span {
    margin-bottom: 0;
    width: 30px;
  }
  .requestwithinput > span {
    margin-bottom: 0.5rem;
  }
  .filerequest:nth-child(1) {
    font-size: 24px;
    /* align-items: end; */
    color: #606972;
    /* background: tomato; */
  }
  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .filerequest-name {
    font-family: "Nunito", sans-serif;
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
    width: 100%;
    min-width: 0;
  }
  .filerequest-name > *:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 13px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #2a2f34;
  }
  .filerequest-name > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }
  .filerequest-name > *:nth-child(3) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }

  .outer-border {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    padding-top: 0.5rem;
    padding-bottom: 1rem;
    border-radius: 10px;
    margin-bottom: 1rem;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  @media only screen and (max-width: 786px) {
    .desktop {
      display: none;
    }

    .td.actions {
      width: 80%;
    }

    .btnGroup > * {
      flex: 1;
    }

    .checklist-tr.child {
      grid-template-areas: "b b b" ". e e";
      width: 92%;
    }

    .btnGroup {
      margin-right: 0;
      padding-left: 8px;
      /* margin-left: 0;
      padding-left: 0.5rem; */
    }
    .sm-hide {
      display: none;
    }
    .checklist-tr:not(.checklist-th) {
      row-gap: 0;
    }
    .checklist-tr.child .td.actions {
      grid-template-columns: 1fr;
      width: 100%;
      margin-left: 0;
    }
    .actionbtnGroup {
      display: grid;
      gap: 8px;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      align-items: unset;
      justify-content: space-between;
    }
  }

  @media only screen and (min-width: 481px) and (max-width: 1280px) {
    .actionbtnGroup {
      display: flex;
      flex-direction: column;
    }

    .btnGroup {
      width: 100%;
      display: flex;
      justify-content: flex-end;
      align-items: center;
      margin-right: 0px;
    }
  }

  @media only screen and (min-width: 640px) {
    .checklist-tr.child .td.actions {
      width: 57%;
      margin-left: 1rem;
    }
  }
  @media only screen and (min-width: 768px) {
    .mobile {
      display: none;
    }

    .filerequest-name {
      width: 80%;
    }
    .td.requestor {
      display: flex;
      width: 95%;
    }
    .td.status {
      display: flex;
    }

    .checklist-tr:not(.checklist-th) {
      display: grid;
      grid-template-columns: 30px 1.7fr 1fr 2fr 160px;
      grid-template-areas: "a b c d e";
      cursor: pointer;
    }
    .checklist-tr.child {
      width: 99%;
      grid-template-columns: 30px 1.7fr 1fr 2fr 160px;
      grid-template-areas: "a b c d e";
    }
    .checklist-tr.child .td.actions {
      width: 100%;
      max-width: 100%;
      padding-right: 2.5rem;
      margin-left: 0;
    }
  }
  @media only screen and (max-width: 425px) {
    .td.actions {
      align-items: center;
      margin-left: unset;
    }
  }
  @media only screen and (max-width: 767px) {
    .ellipsis-btn {
      align-self: flex-start;
      padding-left: 8px;
    }
  }
</style>
