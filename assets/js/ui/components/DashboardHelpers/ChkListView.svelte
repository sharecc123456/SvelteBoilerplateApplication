<script>
  import { getOnlyDate, hackValidFor } from "../../../helpers/util";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Dropdown from "../Dropdown.svelte";
  import ItemView from "./ItemView.svelte";
  import Tag from "./Tag.svelte";
  import DocTag from "../../atomic/Tag.svelte";
  import Panel from "../Panel.svelte";
  import {
    getNextEventForStatus,
    getNextStatusForReq,
    getNextStatusForTemplates,
  } from "../../../nextEventData";

  export let data;
  export let recipient_id;
  export let chkListdata;
  export let handleRequestDropdownClick;
  export let handleAssignmentDropdownClick;
  export let handleFormDropDown;
  export let tryRemindNow;
  export let status;
  export let statusText;
  export let statusIcon;

  const statusBgColor = (status) => {
    if (status == 2) {
      return "border: 1px dashed #cb8284; border-left: 4px solid #cb9294;";
    } else if (status == 4) {
      return "background-color: #d1fae5; border-color: #55aa7e";
    } else {
      return "background-color: rgba(130, 130, 130, 0.1); border-color: #828282";
    }
  };

  const style = `
  width: auto;
  border-radius: .375em;
  border-style: solid;
  border-width: 0 0 0 4px;
  padding: 0.5rem 0.5rem;
  margin-bottom: 0.5rem;
  ${statusBgColor(chkListdata?.state?.status)}
`;

  let panel_collapsed = false;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    allowHandleHeaderClick: true,
    has_z_index: false,
    classes: "max-height-20",
  };

  function totalItem({ document_requests, file_requests }) {
    let doc = 0,
      file = 0;
    if (document_requests.length) {
      doc = document_requests.length;
    }
    if (file_requests.length) {
      file = file_requests.length;
    }
    return doc + file;
  }

  $: status = chkListdata?.state?.status;
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
        <span class="title-text">{chkListdata.name}</span>
        <span class="subtitle-text">{chkListdata.subject}</span>
        {#if chkListdata.requestor_reference}
          <span class="subtitle-text">
            <b>Reference:</b>
            {chkListdata.requestor_reference}
          </span>
        {/if}
        {#if chkListdata.recipient_reference}
          <span class="subtitle-text">
            <b>Recipient-Ref:</b>
            {chkListdata.recipient_reference}
          </span>
        {/if}
      </div>
    </div>
  </div>

  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="left">
        <Tag content={totalItem(chkListdata)} classes="tag-text" />
      </div>
      <div class="right">
        <Dropdown
          triggerType="vellipsis"
          barStyle="color: #0a0a0a;"
          clickHandler={(ret) => {
            ret == 1
              ? handleAssignmentDropdownClick(chkListdata, ret)
              : ret == 2
              ? handleAssignmentDropdownClick(chkListdata, ret)
              : ret == 4
              ? tryRemindNow(
                  chkListdata.id,
                  recipient_id,
                  chkListdata.last_reminder_info
                )
              : ret == 5
              ? (window.location.hash = `#review/${chkListdata.contents_id}`)
              : ret == 6
              ? handleAssignmentDropdownClick(chkListdata, ret)
              : alert("Dropdown Fault");
          }}
          elements={[
            {
              ret: 5,
              icon: "glasses",
              text: "Review",
              disabled: status !== 2,
            },
            {
              ret: 4,
              icon: "bell",
              text: "Remind",
              blocked: status === 2 || status === 4,
            },
            { ret: 1, icon: "archive", text: "Archive" },
            {
              ret: 2,
              icon: "trash-alt",
              text: "Unsend / Delete",
            },
            {
              ret: 6,
              icon: "file-import",
              text: "Send to Document",
              disabled: !hackValidFor(8289, chkListdata.package_id),
            },
          ]}
        />
      </div>
    </div>
  </div>

  <div slot="sub-header">
    <div class="content">
      <div class="left_content">
        <Tag
          content={statusText[status]}
          classes="tag-text"
          has_icon={true}
          icon={statusIcon[status]}
        />
      </div>
      <div class="right_content">
        {chkListdata?.received_date?.time ? "Sent " : ""}{getOnlyDate(
          chkListdata.state.date
        )}
        <br />
        {getNextEventForStatus(chkListdata)}
      </div>
    </div>
    {#if chkListdata.tags}
      <ul class="reset-style">
        {#each chkListdata.tags as tag}
          <DocTag
            isSmall={true}
            tag={{ ...tag, selected: true }}
            listTags={true}
          />
        {/each}
      </ul>
    {/if}
  </div>

  {#each chkListdata.document_requests as document_request}
    <ItemView
      itemData={document_request}
      type="document"
      {data}
      {recipient_id}
      {chkListdata}
      {tryRemindNow}
      {handleAssignmentDropdownClick}
      {statusText}
      {statusIcon}
      nextEventHandler={() =>
        getNextStatusForTemplates(document_request, chkListdata)}
      on:showItemDetails
    />
  {/each}

  {#each chkListdata.file_requests as file_request}
    <ItemView
      itemData={file_request}
      type="file"
      {data}
      {recipient_id}
      {chkListdata}
      {tryRemindNow}
      {handleAssignmentDropdownClick}
      {handleRequestDropdownClick}
      {statusText}
      {statusIcon}
      nextEventHandler={() => getNextStatusForReq(file_request, chkListdata)}
      on:showItemDetails
    />
  {/each}

  {#each chkListdata.forms as form}
    <ItemView
      itemData={form}
      type="form"
      {data}
      {recipient_id}
      {chkListdata}
      {tryRemindNow}
      {handleFormDropDown}
      {statusText}
      {statusIcon}
      nextEventHandler={() => getNextStatusForTemplates(form, chkListdata)}
      on:showItemDetails
    />
  {/each}
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    word-break: break-word;
  }

  .reset-style {
    margin: 0;
    padding: 0;
  }

  .panel-text {
    display: flex;
    flex-direction: column;
  }
  .status {
    flex: 0 0 25px;
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
  .content {
    display: flex;
    justify-content: space-between;
    margin: 0.5rem 0 0.25rem 0;
  }
</style>
