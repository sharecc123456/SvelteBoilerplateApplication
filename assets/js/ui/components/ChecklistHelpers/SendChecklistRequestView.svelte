<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";

  export let data, chcklistView;

  const dispatch = createEventDispatcher();

  const style = `
    width: auto;
    border-radius: .375em;
    padding: 0.5rem 0.5rem 0.1rem;
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
        {#if data.type == "file"}
          <FAIcon icon="paperclip" iconStyle="regular" iconSize="2x" />
        {:else if data.type == "data"}
          <FAIcon icon="font-case" iconStyle="regular" iconSize="2x" />
        {:else if data.type == "task"}
          <span style="padding-right: 0.5rem;">
            <FAIcon icon="thumbtack" iconStyle="regular" iconSize="2x" />
          </span>
        {/if}
      </div>
      <div class="panel-text">
        <span class="title-text">{data?.name}</span>
        {#if data.description?.trim() != ""}
          <span class="subtitle-text flex-column">
            {data.description}
          </span>
        {/if}
        <span class="subtitle-text flex-column">
          {#if data.type == "file"}
            <span>Type: &nbsp; File Request</span>
          {:else if data.type == "data"}
            <span>Type: &nbsp; Data Request</span>
          {:else if data.type == "task"}
            <span>Type: &nbsp; Task</span>
          {/if}
        </span>

        <span class="subtitle-text flex-column">
          {#if data.type == "task" && data.link && Object.keys(data.link).length !== 0 && data.link.url != ""}
            <span>
              Button links to: &nbsp;
              <a target="_blank" href={data.link.url} style="display: block;">
                {data.link.url.substring(0, 60)}
              </a>
            </span>
          {/if}
        </span>
      </div>
    </div>
  </div>

  <div slot="custom-toolbar">
    <div
      on:click={() => {
        dispatch("deleteRequest", {
          requestId: data.id,
          item: data,
        });
      }}
      class="icon"
    >
      <div>
        <FAIcon iconStyle="regular" icon="times-circle" />
      </div>
    </div>
  </div>

  <div slot="sub-header">
    {#if chcklistView}
      <div class="sub-header-wrapper">
        <span
          class="w-full"
          on:click={() => {
            dispatch("handleEditRequest", {
              id: data.id,
            });
          }}
        >
          <Button color="white" text="Edit" icon="edit" />
        </span>
      </div>
    {/if}
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
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
    word-break: break-all;
  }
  .status {
    flex: 0 0 50px;
    width: 50px;
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

  .sub-header-wrapper {
    display: flex;
    margin-top: 0.5rem;
  }
  .w-full {
    width: 100%;
  }
</style>
