<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Dropdown from "../Dropdown.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import ItemView from "./ItemView.svelte";
  import Tag from "../../atomic/Tag.svelte";

  export let data, convertTime, checklistActions, dropdownClick, beginAssign;

  let panel_collapsed = false;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    allowHandleHeaderClick: true,
    has_z_index: false,
    classes: "max-height-10",
  };

  const style = `
    padding: 0.5rem 1rem;
    margin-top: 0.5rem;
    width: auto;
    border-radius: 0.2;
    position: relative;
  `;
</script>

<Panel
  {style}
  {...panelProps}
  bind:collapsed={panel_collapsed}
  headerClasses="cursor-pointer"
  on:header_click={() => {
    panel_collapsed = !panel_collapsed;
  }}
>
  <div slot="custom-title">
    <div class="panel-title">
      <div class="status">
        {#if panel_collapsed}
          <span><FAIcon color={true} icon="minus" /></span>
        {:else}
          <span><FAIcon color={true} icon="plus" /></span>
        {/if}
      </div>
      <div class="panel-text">
        <span class="title-text">
          {#if data.is_draft}
            <i class="cl-draft">DRAFT: </i>
          {/if}
          {data?.name}
        </span>
        <span class="subtitle-text flex-column">
          <span>{data?.description}</span>
          <span
            >Created: &nbsp; {data?.inserted_at}
            {convertTime(data.inserted_at, data.inserted_time)}</span
          >
          <span
            >Modified: &nbsp; {data?.inserted_at}
            {convertTime(data.updated_at, data.updated_time)}</span
          >
          {#if data.tags}
            <ul class="reset-style">
              {#each data.tags as tag}
                <Tag
                  isSmall={true}
                  tag={{ ...tag, selected: true }}
                  listTags={true}
                />
              {/each}
            </ul>
          {/if}
        </span>
      </div>
    </div>
  </div>

  <div slot="sub-header">
    {#if data.is_draft}
      <div
        class="content"
        on:click={() => {
          dropdownClick(data, 2);
        }}
      >
        <Button text="Continue" />
      </div>
    {:else}
      <div
        class="content"
        on:click={() => {
          beginAssign(data);
        }}
      >
        <Button text="Send" />
      </div>
    {/if}
  </div>

  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="right">
        <Dropdown
          elements={checklistActions(data)}
          clickHandler={(ret) => {
            dropdownClick(data, ret);
          }}
          triggerType="vellipsis"
        />
      </div>
    </div>
  </div>

  <div>
    {#each data.file_requests as item}
      <ItemView
        data={item}
        type={item.type}
        itemType="file"
        {convertTime}
        {checklistActions}
        {dropdownClick}
        {beginAssign}
        on:file_item_click
      />
    {/each}
    {#each data.documents as item}
      <ItemView
        data={item}
        type={item.type}
        itemType="document"
        {convertTime}
        {checklistActions}
        {dropdownClick}
        {beginAssign}
      />
    {/each}

    {#each data.forms as form}
      <ItemView
        data={form}
        type={form.type}
        itemType="form"
        inserted_at={data.inserted_at}
        chklistID={data.id}
        {convertTime}
        {checklistActions}
        {dropdownClick}
        {beginAssign}
      />
    {/each}

    {#if !data.file_requests.length && !data.documents.length}
      <p class="no-request-text">
        <FAIcon icon="alert" />
        No documents or file requests attached to this checklist
      </p>
    {/if}
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    word-break: break-word;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
  }
  .status {
    width: 1.5rem;
  }

  .reset-style {
    margin: 0;
    padding: 0;
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
  .custom-toolbar {
    display: flex;
    justify-content: flex-end;
    gap: 0.1rem;
    margin-right: 0.5rem;
  }
  .cl-draft {
    padding-right: 0.2rem;
    font-weight: 500;
  }

  .no-request-text {
    margin-left: 27px;
    color: #444;
  }

  .content {
    display: flex;
    margin: 0.5rem 0 0.25rem 0;
  }
</style>
