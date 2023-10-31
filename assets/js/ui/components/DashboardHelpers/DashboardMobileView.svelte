<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import ChkListView from "./ChkListView.svelte";
  import CabinetView from "./CabinetView.svelte";
  import Dropdown from "../Dropdown.svelte";
  import Panel from "../Panel.svelte";
  import Loader from "../Loader.svelte";
  import { loadDashboardForRecipient } from "BoilerplateAPI/Recipient";
  import qs from "qs";

  export let data;
  export let handleRequestDropdownClick;
  export let handleContactLevelDropDown;
  export let handleAssignmentDropdownClick;
  export let tryRemindNow;
  export let status;
  export let handleFormDropDown;

  let loading = true;

  const getFiltersApplied = () => {
    const search = window.location.hash.split("?")[1];
    const urlData = qs.parse(search);
    return urlData && Object.keys(urlData).length === 0
      ? {}
      : { filterStr: [urlData] };
  };

  const getDashboardForRecipient = async (recipient_id) => {
    const filterStr = getFiltersApplied();
    let reply = await loadDashboardForRecipient(recipient_id, filterStr);
    return reply;
  };

  const statusText = {
    "0": "Open",
    "1": "In Progress",
    "2": "Ready for review",
    "3": "Returned for updates",
    "4": "Completed",
    "5": "Unavailable",
    "6": "Unavailable",
    "7": "Partially Completed",
    undefined: "UNKNOWN",
  };

  const statusIcon = {
    "0": "circle",
    "1": "adjust",
    "2": "check-circle",
    "3": "undo",
    "4": "check-circle",
    "5": "",
    "6": "xmark",
    "7": "adjust",
    undefined: "circle",
  };

  const style = `
  padding: 0.5rem 1rem;
  width: auto;
  border-radius: 0.2;
  position: relative;
`;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    allowHandleHeaderClick: true,
    has_z_index: false,
    classes: "max-height-10",
  };
  let panel_collapsed = false;

  $: status = data?.recipient_state?.status;
</script>

<div
  class={`dash-row-mobile ${status === 2 ? "red-shade-mobile rounded-b" : ""} `}
>
  <Panel
    {style}
    {...panelProps}
    bind:collapsed={panel_collapsed}
    headerClasses="cursor-pointer"
    on:header_click={() => {
      panel_collapsed = !panel_collapsed;
    }}
  >
    <div
      slot="top_title"
      class="top-title is-open"
      class:is-review={status == 2}
      class:is-completed={status == 4}
    >
      <span>
        <FAIcon
          icon={statusIcon[status]}
          iconStyle="regular"
          iconSize="small"
        />
      </span>
      <span>
        {statusText[status]}
      </span>
    </div>
    <div slot="custom-title" style="margin-top: 1.5rem;">
      <div class="panel-title">
        <div class="status">
          {#if panel_collapsed}
            <span><FAIcon color={true} icon="minus" /></span>
          {:else}
            <span><FAIcon color={true} icon="plus" /></span>
          {/if}
        </div>
        <div class="panel-text">
          <span class="title-text"
            >{data.recipient.name} ({data.recipient.company})</span
          >
          <span class="subtitle-text">{data.recipient.email}</span>
        </div>
      </div>
    </div>

    <div slot="custom-toolbar" style="margin-top: 1.5rem;">
      <div class="custom-toolbar">
        <div class="left">
          <span class="tag">{data.checklist_count}</span>
        </div>
        <div class="right">
          <Dropdown
            triggerType="vellipsis"
            clickHandler={(ret) => {
              handleContactLevelDropDown(ret, data);
            }}
            elements={[
              { ret: 1, icon: "info-square", text: "Details" },
              {
                ret: 9,
                icon: "glasses",
                text: "Review",
                disabled: data.recipient_state.status !== 2,
              },
              {
                ret: 3,
                icon: "bell",
                text: "Remind",
                blocked: !(status != 2 && status != 4),
              },
              {
                ret: 4,
                icon: "paper-plane",
                text: "Send New Request",
              },
              {
                ret: 5,
                icon: "cabinet-filing",
                text: "Add to Filing Cabinet",
              },
              {
                ret: 7,
                icon: "eye-slash",
                text: "Hide contact",
                iconStyle: "solid",
              },
              {
                text: "Delete",
                icon: "trash",
                iconStyle: "solid",
                ret: 6,
              },
            ]}
          />
        </div>
      </div>
    </div>

    {#if panel_collapsed}
      {#await getDashboardForRecipient(data.recipient.id)}
        <Loader loading />
      {:then checklist_level}
        {#each checklist_level.checklists as chkListdata}
          <ChkListView
            {data}
            recipient_id={data.recipient.id}
            {chkListdata}
            {tryRemindNow}
            {handleRequestDropdownClick}
            {handleContactLevelDropDown}
            {handleAssignmentDropdownClick}
            {statusText}
            {statusIcon}
            {handleFormDropDown}
            on:showItemDetails
          />
        {/each}
        {#if data.cabinet && data.cabinet.length != 0}
          <CabinetView {data} on:showItemDetails />
        {/if}
      {/await}
    {/if}
  </Panel>
</div>

<style>
  .dash-row-mobile {
    margin: 0.5rem 0;
  }
  .red-shade-mobile {
    border-color: #db5244;
    border-width: 1px;
    border-style: dashed;
  }

  .rounded-b {
    border-bottom-right-radius: 0.625rem; /* 4px */
    border-bottom-left-radius: 0.625rem; /* 4px */
  }
  .panel-title {
    display: flex;
    align-items: center;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
  }
  .status {
    flex: 0 0 25px;
    width: 1.5rem;
  }
  .title-text {
    color: black;
    font-size: 1rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
  }
  .subtitle-text {
    color: #828282;
    font-size: 0.8rem;
    font-weight: 400;
    font-family: "Nunito", sans-serif;
  }
  .custom-toolbar {
    display: flex;
    justify-content: flex-end;
    gap: 0.1rem;
    margin-right: 0.5rem;
  }
  .custom-toolbar .left {
    align-self: center;
  }
  .tag {
    align-items: center;
    border-radius: 0.375em;
    display: inline-flex;
    font-size: 0.75rem;
    height: 1.5rem;
    justify-content: center;
    line-height: 1.5;
    padding: 0 0.75em;
    white-space: nowrap;
    background-color: #828282;
    color: #fff;
  }

  .top-title {
    background-color: #828282;
    position: absolute;
    top: 0;
    width: 100%;
    left: 0;
    display: flex;
    justify-content: center;
    z-index: 1;
    padding: 0.2rem 0;
    gap: 0.5rem;
  }

  .is-open {
    background-color: #828282;
    color: #fff;
    font-weight: 700;
  }
  .is-review {
    background-color: #f5d8cb;
    color: #000;
    font-weight: 700;
  }
  .is-completed {
    background-color: #d1fae5;
    color: #000;
    font-weight: 700;
  }
</style>
