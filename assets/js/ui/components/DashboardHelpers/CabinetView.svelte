<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import CabinetItemView from "./CabinetItemView.svelte";
  import Tag from "./Tag.svelte";
  import Panel from "../Panel.svelte";

  export let data;

  const style = `
    width: auto;
    border-radius: .375em;
    border-style: solid;
    border-width: 0 0 0 4px;
    padding: 0.5rem 0.5rem;
    background-color: rgba(130, 130, 130, 0.1);
    box-shadow: rgba(130, 130, 130, 0.1) 0px 7px 29px 0px;
    border-color: #828282;
  `;

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
        <span class="title-text">Internal Filing Cabinet</span>
        <span class="subtitle-text"
          >Manually added documents for {data.recipient.name}</span
        >
      </div>
    </div>
  </div>

  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="left">
        <Tag content={data.cabinet?.length || 0} classes="tag-text" />
      </div>
      <div class="right" />
    </div>
  </div>

  {#each data.cabinet as cabinet}
    <CabinetItemView itemData={cabinet} {data} on:showItemDetails />
  {/each}
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
  }
  .status {
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
</style>
