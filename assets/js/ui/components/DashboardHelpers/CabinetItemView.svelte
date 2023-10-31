<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Button from "../../atomic/Button.svelte";
  import Panel from "../Panel.svelte";
  import { isImage, getFileDownloadUrl } from "../../../helpers/fileHelper";
  export let data;
  export let itemData;

  const style = `
    width: auto;
    border-radius: .375em;
    padding: 0.5rem 0.5rem 0.2rem;
    background-color: rgba(251, 251, 251, 0.1);
    box-shadow: rgba(0, 0, 0, 0.1) 0px 7px 29px 0px;
    border-color: #828282
  `;
  const dispatch = createEventDispatcher();
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
  on:panel_click={() => {
    console.log(itemData);
    dispatch("showItemDetails", { itemData });
  }}
  allowHandlePanelClick={true}
  classes="cursor-pointer"
  headerClasses="cursor-pointer"
>
  <div slot="custom-title">
    <div class="panel-title">
      <div class="status">
        <FAIcon icon="file-alt" iconStyle="regular" iconSize="2x" />
      </div>
      <div class="panel-text">
        <span class="title-text">{itemData.name}</span>
      </div>
    </div>
  </div>

  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="left">
        <span
          on:click|stopPropagation={() => {
            const specialId = 3;
            if (isImage) {
              window.location = `#submission/view/${specialId}/${data.recipient.id}/${itemData.id}`;
            } else {
              window.location = getFileDownloadUrl({
                specialId,
                parentId: data.recipient.id,
                documentId: itemData.id,
              });
            }
          }}
        >
          <Button color="white" text="View" />
        </span>
      </div>
    </div>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    margin-top: 8px;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
  }
  .status {
    margin-right: 1rem;
  }
  .title-text {
    font-size: 1rem;
    font-weight: 500;
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
