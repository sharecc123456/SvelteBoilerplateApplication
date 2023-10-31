<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  export let data, checklistId, contentsId, allowEdit, i;
  const dispatch = createEventDispatcher();

  const style = `
    width: auto;
    border-radius: .375em;
    padding: 0.5rem 0.5rem 0.1rem;
    background: #ffffff;;
  `;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    collapsed: true,
    disableCollapse: true,
    has_z_index: false,
  };
</script>

<Panel {style} {...panelProps} headerClasses="cursor-pointer">
  <div slot="custom-title">
    <div class="panel-title">
      <div class="status">
        <FAIcon icon="rectangle-list" iconStyle="regular" iconSize="2x" />
      </div>
      <div class="panel-text">
        <span class="title-text">{data?.title}</span>
        <span class="subtitle-text flex-column">{data?.description}</span>
      </div>
    </div>
  </div>

  <div slot="sub-header">
    <div class="sub-header-wrapper">
      <div class="w-full">
        <span
          class="content"
          on:click={() => {
            if (contentsId) {
              allowEdit && !data.has_repeat_entries
                ? (window.location.href = `#prefill/form/${checklistId}/index/${i}?cid=${contentsId}`)
                : (window.location.href = `#preview/form/${checklistId}/index/${i}?cid=${contentsId}`);
            } else {
              window.open(`#preview/form/${checklistId}/${data.id}`, "_blank");
            }
          }}
        >
          {#if contentsId && allowEdit && !data.has_repeat_entries}
            <Button color="white" text="Prefill / View" />
          {:else}
            <Button color="white" text="View" />
          {/if}
        </span>
      </div>
      <div
        on:click={() => {
          dispatch("deleteItem");
        }}
        class="icon"
      >
        <div>
          <FAIcon iconStyle="regular" icon="times-circle" />
        </div>
      </div>
    </div>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
  }
  .sub-header-wrapper {
    display: flex;
  }
  .w-full {
    width: 100%;
  }
  .panel-text {
    flex-direction: column;
  }
  .title-text {
    color: black;
    font-size: 1rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
  }
  .subtitle-text {
    font-size: 0.8rem;
    font-weight: 400;
    font-family: "Nunito", sans-serif;
  }
  .flex-column {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .content {
    display: flex;
    margin: 0.5rem 0 0.25rem 0;
    text-decoration: none;
    width: 100%;
  }

  .status {
    width: 50px;
    color: #76808b;
  }
  .icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    width: 48px;
    color: #76808b;
    font-size: 24px;
    align-items: flex-end;
    text-align: center;
    justify-content: center;
  }
</style>
