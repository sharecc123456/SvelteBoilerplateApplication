<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Tag from "../../atomic/Tag.svelte";
  import Panel from "../Panel.svelte";
  export let data, type, inserted_at, itemType, chklistID;

  const dispatch = createEventDispatcher();

  const style = `
    width: auto;
    border-radius: .375em;
    padding: 0.5rem 0.5rem;
  `;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    collapsed: true,
    allowHandleHeaderClick: true,
    disableCollapse: true,
    has_z_index: false,
  };
</script>

<Panel
  {style}
  {...panelProps}
  headerClasses="cursor-pointer"
  on:header_click={() => {
    if (itemType == "file") {
      if (type === "task") {
        dispatch("file_item_click", data);
      }
    } else if (itemType == "document") {
      window.location.hash = `#view/template/${data.id}?filePreview=true`;
    } else if (itemType == "form") {
      window.location.hash = `#preview/form/${chklistID}/${data.id}`;
    }
  }}
>
  <div slot="custom-title">
    <div class="panel-title">
      <div class="flex-row">
        <div class="panel-icon">
          {#if itemType == "file"}
            {#if type == "file"}
              <FAIcon icon="paperclip" iconStyle="regular" iconSize="large" />
            {:else if type == "data"}
              <FAIcon icon="font-case" iconStyle="regular" iconSize="large" />
            {:else if type == "task"}
              <FAIcon icon="thumbtack" iconStyle="regular" iconSize="large" />
            {/if}
          {:else if itemType == "form"}
            <FAIcon
              icon="rectangle-list"
              iconStyle="regular"
              iconSize="large"
            />
          {:else if data.is_rspec}
            <FAIcon icon="file-user" iconStyle="solid" iconSize="large" />
          {:else if data.is_info}
            <FAIcon icon="info-square" iconStyle="regular" iconSize="large" />
          {:else}
            <FAIcon icon="file-alt" iconStyle="regular" iconSize="large" />
          {/if}
        </div>
        <div class="panel-text">
          <span class="title-text"
            >{itemType == "form" ? data?.title : data?.name}</span
          >
          <span class="subtitle-text flex-column">
            {#if itemType == "file"}
              {#if type == "file"}
                <span>File Request</span>
              {:else if type == "data"}
                <span>Data Request</span>
              {:else if type == "task"}
                <span>Task</span>
              {/if}
              <span>Created: &nbsp; {data.inserted_at}</span>
            {:else}
              <span> {data?.description} </span>
              {#if itemType == "form"}
                <span>Created: &nbsp; {inserted_at}</span>
              {:else}
                <span>Created: &nbsp; {data?.inserted_at}</span>
              {/if}
            {/if}
          </span>
          {#if data.tags}
            <ul class="reset-style">
              {#each data.tags.values as tag}
                <Tag tag={{ ...tag, selected: true }} />
              {/each}
            </ul>
          {/if}
        </div>
      </div>
    </div>
  </div>
</Panel>

<style>
  .reset-style {
    margin: 0;
    padding: 0;
  }

  .panel-title {
    display: flex;
    align-items: center;
    color: var(--text-secondary);
  }

  .panel-icon {
    width: 25px;
  }
  .flex-row {
    display: flex;
    align-items: center;
    gap: 0.5rem;
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
</style>
