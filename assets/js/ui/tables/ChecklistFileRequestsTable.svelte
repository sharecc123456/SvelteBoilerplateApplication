<script>
  import SendChecklistRequestView from "../components/ChecklistHelpers/SendChecklistRequestView.svelte";
  import Panel from "../components/Panel.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { createEventDispatcher } from "svelte";
  import Switch from "../components/Switch.svelte";

  let dispatch = createEventDispatcher();

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    collapsed: true,
    disableCollapse: true,
    has_z_index: false,
    innerContentClasses: "m-0",
  };

  let hovering = false;
  const drop = (event, target) => {
    event.dataTransfer.dropEffect = "move";
    const start = parseInt(event.dataTransfer.getData("text/plain"));
    const newRequests = file_requests;
    if (start < target) {
      newRequests.splice(target + 1, 0, newRequests[start]);
      newRequests.splice(start, 1);
    } else {
      newRequests.splice(target, 0, newRequests[start]);
      newRequests.splice(start + 1, 1);
    }
    hovering = null;
    file_requests = newRequests;
    dispatch("dragDrop", {
      file_requests,
    });
  };

  const dragstart = (event, i) => {
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.dropEffect = "move";
    const start = i;
    event.dataTransfer.setData("text/plain", start);
  };

  export let file_requests,
    switchActionExpirationRequest,
    chcklistView = false,
    draggable = false,
    showEmptyText = true;
  $: dragging = false;

  console.log("FR", file_requests);
</script>

<div class="documents">
  {#if file_requests.length == 0 && showEmptyText}
    <div class="tr-full desktop-only">
      <p>
        This Checklist contains no requests. Want to add one just for this
        Contact? Use the button to the bottom right.
      </p>
    </div>

    <div class="mobile-only">
      <Panel
        style={`
          width: auto;
          border-radius: .375em;
          padding: 0.5rem 0.5rem;
        `}
        {...panelProps}
      >
        This Checklist contains no requests. Want to add one just for this
        Contact? Use the button to the bottom right.
      </Panel>
    </div>
  {:else}
    <div class="tr th desktop-only">
      <div class="td icon" />
      {#if draggable}
        <div class="td icon" />
      {/if}
      <div class="td name">Details</div>
      <div class="td type">Type</div>
      {#if switchActionExpirationRequest}
        <div class="td type desktop">
          <FAIcon icon="calendar-exclamation" />
          <span style="padding-left: 4px;"> Track expiration? </span>
        </div>
      {/if}
      <div class="td action" />
    </div>
    {#each file_requests as fr, index}
      <span class="desktop-only">
        <div
          on:drop|preventDefault={(event) => drop(event, index)}
          on:dragenter={() => (hovering = index)}
          on:dragstart={(event) => dragstart(event, index)}
          on:dragend={() => {
            dragging = false;
          }}
          ondragover="return false"
          draggable={dragging}
          class="tr"
        >
          {#if draggable}
            <div
              {draggable}
              class="td icon cursor-move"
              on:mousedown={() => {
                dragging = true;
              }}
            >
              <FAIcon icon="grip-dots-vertical" iconStyle="solid" />
            </div>
          {/if}
          <div class="td icon">
            <div>
              {#if fr?.type == "file"}
                <FAIcon icon="paperclip" iconStyle="regular" />
              {:else if fr?.type == "data"}
                <FAIcon icon="font-case" iconStyle="regular" />
              {:else if fr?.type == "task"}
                <FAIcon icon="thumbtack" iconStyle="regular" />
              {/if}
            </div>
          </div>
          <div class="td name">
            <div class="name-container">
              <div class="truncate">{fr?.name}</div>
              {#if fr?.description != undefined}
                <div class="truncate">{@html fr?.description}</div>
              {/if}
              {#if fr?.type == "task" && fr?.link && Object.keys(fr?.link).length !== 0 && fr?.link.url != ""}
                <div>
                  <a target="_blank" href={fr?.link.url}>
                    {fr?.link.url}
                  </a>
                </div>
              {/if}
            </div>
          </div>
          <div class="td type">
            <div class="name-container">
              {#if fr?.type == "file"}
                <div>File Request</div>
              {:else if fr?.type == "data"}
                <div>Data Request</div>
              {:else if fr?.type == "task"}
                <div>
                  Task{fr.is_confirmation_required
                    ? " + confirmation file"
                    : ""}
                </div>
              {/if}
            </div>
          </div>
          {#if fr?.type !== "data" && switchActionExpirationRequest}
            <div class="td type file-requests">
              <span>
                <Switch
                  bind:checked={fr.allow_expiration_tracking}
                  action={(checked) =>
                    switchActionExpirationRequest(fr, checked)}
                  text=""
                />
              </span>
            </div>
          {:else if switchActionExpirationRequest}
            <div class="td type file-requests" />
          {/if}
          <div class="td action">
            {#if chcklistView}
              <span
                on:click={() => {
                  dispatch("handleEditRequest", {
                    id: fr.id,
                  });
                }}
                class="deleter"
                style="margin-right: .5rem;"
              >
                <FAIcon iconStyle="regular" icon="edit" />
              </span>
            {/if}
            <span
              on:click={() => {
                dispatch("deleteRequest", {
                  requestId: fr?.id,
                  item: fr,
                });
              }}
              class="deleter"
            >
              <FAIcon iconStyle="regular" icon="times-circle" />
            </span>
          </div>
        </div>
      </span>

      <span class="mobile-only">
        <SendChecklistRequestView
          bind:data={fr}
          {chcklistView}
          on:handleEditRequest
          on:deleteRequest
        />
      </span>
    {/each}
  {/if}
</div>

<style>
  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  a {
    width: 250px;
    display: block;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    text-decoration: none;
  }
  .documents {
    display: flex;
    flex-flow: column nowrap;
    gap: 8px;
    flex: 1 1 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    justify-content: left;
    align-items: center;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #606972;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr-full {
    justify-content: center;
    align-items: center;
    text-align: center;
    width: 100%;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #606972;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .td.name {
    flex: 0.67 1 0;
    flex-grow: 2;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
  }

  .td.icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    max-width: 250px;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: center;
  }

  .action {
    display: flex;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: flex-end;
  }

  .deleter {
    cursor: pointer;
  }

  .deleter:hover {
    color: hsl(0, 95%, 77%);
  }

  .td.type > * {
    font-size: 14px;
    line-height: 16px;
    color: #606972;
    border-radius: 4px;
    /* padding: 0.5rem; */
  }

  .name-container {
    width: 90%;
    display: flex;
    flex-flow: column nowrap;
    justify-content: space-around;
  }

  .name-container > *:nth-child(1) {
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #2a2f34;
  }

  .name-container > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #7e858e;
  }
  .name-container > *:nth-child(3) {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #7e858e;
  }
  .mobile-only {
    display: none;
  }

  @media only screen and (max-width: 767px) {
    .mobile-only {
      display: block;
    }
    .desktop-only {
      display: none;
    }
  }
</style>
