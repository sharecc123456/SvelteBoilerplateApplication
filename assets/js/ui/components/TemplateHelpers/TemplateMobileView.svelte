<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import { createEventDispatcher } from "svelte";
  import Dropdown from "../Dropdown.svelte";
  import Tag from "../../atomic/Tag.svelte";

  export let data, convertTime, templateDropdown, dropdownClick;
  const dispatch = createEventDispatcher();
  const style = `
  padding: 0.5rem 1rem;
  margin-top: 0.5rem;
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
    classes: "max-height-20",
  };
</script>

<Panel {style} {...panelProps} headerClasses="cursor-pointer">
  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="right">
        <Dropdown
          elements={templateDropdown}
          clickHandler={(ret) => {
            dropdownClick(data, ret);
          }}
          triggerType="vellipsis"
        />
      </div>
    </div>
  </div>

  <div slot="custom-title">
    <div class="panel-title">
      <div class="status">
        {#if data.is_rspec}
          <FAIcon icon="file-user" iconStyle="solid" iconSize="2x" />
        {:else if data.is_info}
          <FAIcon icon="info-square" iconStyle="solid" iconSize="2x" />
        {:else}
          <FAIcon icon="file-alt" iconStyle="regular" iconSize="2x" />
        {/if}
      </div>
      <div class="panel-text truncate">
        <span class="title-text truncate">{data.name ? data.name : ""}</span>
        <span class="subtitle-text flex-column">
          <span class="truncate"
            >{data.description ? data.description : ""}</span
          >
          <span
            >Type: {data.is_rspec
              ? "Contact-Specific PDF"
              : data.is_info
              ? "Informational-Only"
              : "Generic PDF"}
          </span>
          <span
            >Created: &nbsp; {data.inserted_at}
            {convertTime(data.inserted_at, data.inserted_time)}
          </span>
          <span
            >Modified: &nbsp; {data.updated_at}
            {convertTime(data.updated_at, data.updated_time)}
          </span>
          {#if data.tags}
            <ul class="flex flex-wrap m-0 p-0">
              {#each data.tags.values as tag}
                <Tag tag={{ ...tag, selected: true }} />
              {/each}
            </ul>
          {/if}
        </span>
      </div>
    </div>
  </div>

  <div slot="sub-header" style="margin-top: 0.5rem;">
    <span
      on:click={() => {
        dispatch("handleSend", { data });
      }}
    >
      <Button text="Send" />
    </span>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    width: 100%;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
    width: 100%;
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
  .flex-column {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }
  .status {
    margin-right: 1rem;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
