<script>
  import SendChecklistFormView from "../components/ChecklistHelpers/SendChecklistFormView.svelte";
  import Panel from "../components/Panel.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { createEventDispatcher } from "svelte";
  import Button from "../atomic/Button.svelte";

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

  function handleDelete(formId) {
    dispatch("deleteForm", {
      formId,
    });
  }

  export let forms;
  export let checklistId;
  export let showEmptyText = true;
  export let allowEdit = false;
  export let contentsId;
</script>

<div class="documents">
  {#if forms.length == 0 && showEmptyText}
    <div class="tr-full desktop-only">
      <p>
        This Checklist contains no forms. Want to add one just for this Contact?
        Use the button to the bottom right.
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
        This Checklist contains no forms. Want to add one just for this Contact?
        Use the button to the bottom right.
      </Panel>
    </div>
  {:else}
    <div class="tr th desktop-only">
      <div class="td icon" />
      <div class="td name">Form Details</div>
      <div class="td" />
      <div class="td" />
      <div class="td" />
      <div class="td actions desktop-only">Actions</div>
      <div class="td icon" />
    </div>
    {#each forms as form, i}
      <span class="desktop-only">
        <div class="tr">
          <div class="td icon">
            <div>
              <FAIcon icon="rectangle-list" iconStyle="regular" />
            </div>
          </div>
          <div class="td name">
            <div class="name-container">
              <div>{form.title}</div>
              {#if form.description != undefined}
                <div>{form.description}</div>
              {/if}
            </div>
          </div>
          <div class="td" />
          <div class="td" />
          <div class="td" />
          <div class="td actions desktop-only">
            <div
              on:click={() => {
                allowEdit && !form.has_repeat_entries
                  ? (window.location.href = `#prefill/form/${checklistId}/index/${i}?cid=${contentsId}`)
                  : (window.location.href = `#preview/form/${checklistId}/index/${i}?cid=${contentsId}`);
              }}
            >
              <Button
                color="white"
                text={allowEdit && !form.has_repeat_entries
                  ? "Prefill / View"
                  : "View"}
              />
            </div>
          </div>
          <div class="td icon deleter">
            <span
              on:click={() => {
                handleDelete(form.id);
              }}
            >
              <FAIcon iconStyle="regular" icon="times-circle" />
            </span>
          </div>
        </div>
      </span>

      <span class="mobile-only">
        <SendChecklistFormView
          data={form}
          {checklistId}
          on:deleteItem={() => {
            handleDelete(form.id);
          }}
          {allowEdit}
          {contentsId}
          {i}
        />
      </span>
    {/each}
  {/if}
</div>

<style>
  .documents {
    display: flex;
    flex-flow: column nowrap;
    /* flex: 1 1 auto; */
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
    width: 48px;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: center;
  }

  .td.icon.deleter {
    cursor: pointer;
  }

  .td.icon.deleter:hover {
    color: hsl(0, 95%, 77%);
  }

  .name-container {
    width: 100%;
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
