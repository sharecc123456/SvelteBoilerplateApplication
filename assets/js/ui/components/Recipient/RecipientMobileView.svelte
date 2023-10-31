<script>
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import { createEventDispatcher } from "svelte";
  import Dropdown from "../Dropdown.svelte";
  import Tag from "../../atomic/Tag.svelte";

  export let data,
    dropdownElement,
    dropdownClick,
    showActiveElements,
    checkedRecipients;
  const dispatch = createEventDispatcher();
  const style = `
  padding: 0.5rem 1rem;
  margin-top: 0.5rem;
  width: auto;
  border-radius: 0.2;
  position: relative;
  ${
    data.deleted
      ? "text-decoration: line-through;background: #f5d8cb !important;"
      : ""
  }`;
  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    has_z_index: false,
    allowHandlePanelClick: true,
    classes: "max-height-20",
  };
</script>

<Panel
  {style}
  {...panelProps}
  on:panel_click={() => {
    if (showActiveElements) {
      dispatch("handleCheckedRecipients", { recp: data });
    }
  }}
>
  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="right">
        <Dropdown
          elements={dropdownElement}
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
      {#if showActiveElements}
        <div class="status">
          <input
            type="checkbox"
            name="checkedRecipients"
            checked={checkedRecipients.find((crecp) => crecp.id == data.id)}
            on:click={(ev) => {
              dispatch("handleCheckedRecipients", { recp: data });
              ev.stopPropagation();
            }}
          />
        </div>
      {/if}

      <div class="panel-text">
        <span class="title-text">{data.name}</span>
        <span class="subtitle-text flex-column">
          {#if data.company?.trim()}
            <span>organization: &nbsp; {data.company}</span>
          {/if}
          {#if data.phone_number}
            <span>phone number: &nbsp; {data.phone_number}</span>
          {/if}
          <span>{data.email}</span>
        </span>
      </div>
    </div>
  </div>

  <div slot="sub-header" style="margin-top: 0.5rem;">
    {#if data.tags}
      <ul class="reset-style">
        {#each data.tags.values as tag}
          <Tag isSmall={true} {tag} allowDeleteTags={false} />
        {/each}
      </ul>
    {/if}
    <div class="buttons">
      {#if !showActiveElements}
        <span
          on:click={() => {
            dispatch("assignRecipient", { data });
          }}
          class="w-full"
        >
          <Button color="secondary" text="Assign" icon="ballot-check" />
        </span>
      {/if}
      <span
        on:click={(ev) => {
          window.location.hash = `#recipient/${data.id}/details/user`;
          ev.stopPropagation();
        }}
        class="w-full"
      >
        <Button text="Details" icon="info-circle" />
      </span>
    </div>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    width: 100%;
  }

  .reset-style {
    margin: 0;
    padding: 0;
  }

  .status {
    margin-right: 1rem;
  }
  .w-full {
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
  .buttons {
    display: flex;
    gap: 0.2rem;
  }
</style>
