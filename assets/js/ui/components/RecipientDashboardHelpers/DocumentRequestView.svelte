<script>
  import { createEventDispatcher } from "svelte";
  import { stateToText } from "../../../helpers/Requester/Dashboard";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Dropdown from "../Dropdown.svelte";
  import DashboardStatus from "../DashboardStatus.svelte";
  import DocActionButton from "../Recipient/DocActionButton.svelte";
  import DocStatusSm from "../../atomic/molecules/DocStatusSm.svelte";

  const dispatch = createEventDispatcher();

  export let docreq,
    assignment,
    checklistActions,
    dropdownClick,
    clickDocumentButton;

  function getIcons() {
    if (docreq.is_rspec) {
      return { icon: "file-user", style: "solid" };
    } else if (docreq.is_info) {
      return { icon: "info-square", style: "regular" };
    } else {
      return { icon: "file-alt", style: "regular" };
    }
  }
</script>

<div
  on:click={() => {
    dispatch("doc_req_click");
  }}
  class="checklist-tr child outer-border"
  class:greenShade={docreq.state.status == 2 || docreq.state.status == 4}
  class:red-shade={docreq.state.status == 3}
>
  <div class="td chevron" />
  <div class="td checklist">
    <div class="filerequest checklist-icon" style="cursor: pointer;">
      <span class="document-icon">
        <span>
          <FAIcon icon={getIcons().icon} iconStyle={getIcons().style} />
        </span>
      </span>
      <div class="filerequest-name">
        <span>{docreq.name}</span>
        <span>
          {docreq.is_info
            ? "For Information Only"
            : "Document to be filled/ signed"}
        </span>

        <div class="mobile">
          {#if docreq.return_comments}
            <div style="font-size: 12px;">
              Reason for return: {docreq.return_comments}
            </div>
          {/if}
        </div>
        <DocStatusSm status={docreq.state.status} date={docreq.state.date} />
      </div>
      {#if docreq.state.status == 2 || docreq.state.status == 4}
        <div class="mobile">
          <Dropdown
            elements={checklistActions(docreq)}
            clickHandler={(ret) => {
              dropdownClick(assignment, ret, docreq, "template");
            }}
            triggerType="ellipsis"
          />
        </div>
      {:else}
        <div class="mobile">
          <Dropdown
            elements={checklistActions(docreq)}
            clickHandler={(ret) => {
              dropdownClick(assignment, ret, docreq, "template");
            }}
            triggerType="ellipsis"
          />
        </div>
      {/if}
    </div>
  </div>
  <div class="td requestor" />

  <div class="td status">
    <DashboardStatus
      recipient={true}
      state={docreq.state}
      info={docreq.is_info}
      reason={docreq.return_comments}
      time={docreq.state.time}
    />
  </div>

  <div class="td actions actions-btn">
    <div class="btnGroup sm-hide">
      <DocActionButton
        {stateToText}
        {docreq}
        {assignment}
        clickDocumentButton={() => {
          clickDocumentButton(assignment, docreq);
        }}
      />
    </div>
    {#if docreq.is_info || docreq.state.status == 2 || docreq.state.status == 4}
      <div class="desktop">
        <Dropdown
          elements={checklistActions(docreq)}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, docreq, "template");
          }}
          triggerType="vellipsis"
        />
      </div>
    {:else}
      <div class="desktop">
        <Dropdown
          elements={checklistActions(docreq)}
          clickHandler={(ret) => {
            dropdownClick(assignment, ret, docreq, "template");
          }}
          triggerType="vellipsis"
        />
      </div>
    {/if}
  </div>
</div>

<style>
  .greenShade {
    background: #d1fae5 !important;
  }

  .red-shade {
    border-color: #db5244 !important;
    border-width: 2px !important;
    border-style: dashed !important;
  }

  .td {
    font-family: "Nunito", sans-serif;
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    min-width: 0px;
    color: #7e858e;
    /*white-space: nowrap;*/
  }
  .checklist-tr {
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

  .filerequest {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
  }
  .filerequest > span {
    margin-bottom: 0;
    width: 30px;
  }
  .filerequest:nth-child(1) {
    font-size: 24px;
    /* align-items: end; */
    color: #606972;
    /* background: tomato; */
  }
  .filerequest-name {
    font-family: "Nunito", sans-serif;
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
    width: 100%;
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

  @media only screen and (max-width: 786px) {
    .desktop {
      display: none;
    }

    .td.actions {
      width: 80%;
    }

    .checklist-tr.child {
      grid-template-areas: "b b b" "e e e";
      width: 92%;
    }

    .btnGroup {
      margin-left: 0;
    }
    .sm-hide {
      display: none;
    }
    .checklist-tr:not(.checklist-th) {
      row-gap: 0;
    }
    .filerequest {
      align-items: flex-start;
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
</style>
