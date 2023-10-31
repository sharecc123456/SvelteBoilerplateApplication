<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Dropdown from "../Dropdown.svelte";
  import Panel from "../Panel.svelte";
  import Tag from "./Tag.svelte";
  export let type;
  export let data;
  export let recipient_id;
  export let itemData;
  export let chkListdata;
  export let handleAssignmentDropdownClick;
  export let handleRequestDropdownClick;
  export let handleFormDropDown;
  export let tryRemindNow;
  export let statusText;
  export let statusIcon;
  export let nextEventHandler = () => {};

  const dispatch = createEventDispatcher();
  const statusBgColor = (status) => {
    if (status == 2) {
      return "border: 1px dashed #db5244; ";
    } else if (status == 4) {
      return "background-color: #d1fae5; border:1px solid  #2dbd72";
    } else {
      return "background-color: rgba(251, 251, 251, 0.1); border:1px solid #828282";
    }
  };

  const tagStyle = (status) => {
    if (status == 2) {
      return "background-color: #d1fae5; color: #0a0a0a;";
    } else if (status == 4) {
      return "background-color: #fff; color: #0a0a0a;";
    } else {
      return "background-color: #828282; color: #fff;";
    }
  };

  const style = `
  width: auto;
  border-radius: .375em;
  margin-bottom: 0.5rem;
  padding: 0.5rem 0.5rem;
  ${statusBgColor(itemData?.state?.status)}
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

  $: status = itemData?.state?.status;
  $: missing_reason = itemData?.missing_reason;
  $: allow_handle_panel_click = ["form", "document"].includes(type)
    ? status == 2 || status == 4
    : status == 2;
</script>

<Panel
  {style}
  {...panelProps}
  on:header_click={() => {
    if (status != 2) {
      if (type == "form") {
        itemData.name = itemData.title;
      }
      dispatch("showItemDetails", { itemData });
    }
  }}
  on:panel_click={() => {
    if (type == "form") {
      if (status == 2) {
        window.location.hash = `#review/${chkListdata.id}/form/${itemData.id}`;
      } else if (status == 4) {
        window.location.hash = `#submission/view/8/${chkListdata.id}/${itemData.id}`;
      }
      return;
    }

    if (type == "document") {
      if (status == 2) {
        window.location.hash = `#review/${chkListdata.contents_id}/document/${itemData.id}`;
      } else if (status == 4) {
        window.location.hash = `#submission/view/1/${chkListdata.id}/${itemData.completion_id}`;
      }
      return;
    }

    if (type == "file") {
      window.location.hash = `#review/${chkListdata.contents_id}`;
    } else {
      window.location.hash = `#review/${chkListdata.contents_id}/document/${data.id}`;
    }
  }}
  allowHandlePanelClick={allow_handle_panel_click}
  classes={status == 2 ? "cursor-pointer" : ""}
  headerClasses="cursor-pointer"
>
  <div slot="custom-title">
    <div class="panel-title">
      <div class="status" class:text-grey={!(status == 2 || status == 4)}>
        {#if type == "form"}
          <FAIcon icon="rectangle-list" iconStyle="regular" iconSize="2x" />
        {/if}
        {#if type == "document"}
          {#if itemData.is_rspec}
            <FAIcon icon="file-user" iconStyle="regular" iconSize="2x" />
          {:else}
            <FAIcon icon="file-alt" iconStyle="regular" iconSize="2x" />
          {/if}
        {/if}

        {#if type == "file"}
          {#if itemData.type == "file" && itemData.flags == 2}
            <FAIcon icon="paperclip" iconStyle="regular" iconSize="2x" />
          {:else if itemData.type == "file"}
            <FAIcon icon="paperclip" iconStyle="regular" iconSize="2x" />
          {:else if itemData.type == "data"}
            <FAIcon icon="font-case" iconStyle="regular" iconSize="2x" />
          {:else if itemData.type == "task"}
            <FAIcon icon="thumbtack" iconStyle="regular" iconSize="2x" />
          {/if}
        {/if}
      </div>
      <div class="panel-text" class:text-dark={!(status == 2 || status == 4)}>
        <span class="title-text">
          {type === "form" ? itemData.title : itemData.name}
        </span>
        <span
          class="subtitle-text"
          class:text-grey={!(status == 2 || status == 4)}
          >{@html itemData.description}</span
        >
      </div>
    </div>
  </div>

  <div slot="custom-toolbar">
    <div class="custom-toolbar">
      <div class="left" />
      <div class="right">
        {#if type == "document"}
          <Dropdown
            barStyle={status == 2 || status == 4
              ? "color: #ffffff"
              : "color: #0a0a0a"}
            triggerType="vellipsis"
            clickHandler={(ret) => {
              ret == 2 || ret == 8
                ? handleAssignmentDropdownClick(chkListdata, ret, itemData)
                : ret == 3
                ? handleAssignmentDropdownClick(chkListdata, ret, itemData)
                : ret == 4
                ? handleAssignmentDropdownClick(chkListdata, ret, itemData)
                : ret == 5
                ? handleAssignmentDropdownClick(chkListdata, ret, itemData)
                : ret == 6 // Change back to bring back details
                ? tryRemindNow(
                    chkListdata.id,
                    recipient_id,
                    chkListdata.last_reminder_info
                  )
                : ret == 7
                ? (window.location.hash = `#review/${chkListdata.contents_id}/document/${data.id}`)
                : ret === 10
                ? handleAssignmentDropdownClick(chkListdata, ret, itemData)
                : alert("Dropdown Fault");
            }}
            elements={[
              // { ret: , icon: "info-square", text: "Details" }, Needs more work Seperate Ticket
              {
                ret: 7,
                icon: "glasses",
                text: "Review",
                disabled: status !== 2,
              },
              {
                ret: 6,
                icon: "bell",
                text: "Remind",
                blocked:
                  chkListdata.state.status === 2 ||
                  chkListdata.state.status === 4,
              },
              {
                ret: 8,
                icon: "eye",
                text: "View",
                disabled: status !== 0,
              },
              {
                ret: 10,
                icon: "undo",
                text: "Update and resend",
                disabled: status !== 0 || !itemData.is_rspec,
              },
              { ret: 3, icon: "print", text: "Print" },
              {
                ret: 4,
                icon: "download",
                text: "Download",
              },
              {
                text: "Upload For Client",
                icon: "file-upload",
                iconStyle: "solid",
                disabled: status != 0,
                ret: 5,
              },
              {
                ret: 2,
                icon: "trash-alt",
                text: "Unsend / Delete",
              },
            ]}
          />
        {/if}

        {#if type == "file"}
          <Dropdown
            barStyle={status == 2 || status == 4
              ? "color: #ffffff"
              : "color: #0a0a0a"}
            triggerType="vellipsis"
            clickHandler={(ret) => {
              ret == 3
                ? handleRequestDropdownClick(chkListdata, itemData, ret)
                : ret == 4
                ? handleRequestDropdownClick(chkListdata, itemData, ret)
                : ret == 7
                ? (window.location.hash = `#review/${chkListdata.contents_id}`)
                : ret != 6
                ? handleRequestDropdownClick(chkListdata, itemData, ret)
                : tryRemindNow(
                    chkListdata.id,
                    recipient_id,
                    chkListdata.last_reminder_info
                  );
            }}
            elements={[
              {
                ret: 7,
                icon: "glasses",
                text: "Review",
                disabled: status !== 2,
              },
              {
                ret: 6,
                icon: "bell",
                text: "Remind",
                blocked:
                  status === 2 || status === 5 || status === 4 || status === 6,
              },
              {
                ret: 2,
                text: "Upload For Client",
                icon: "file-upload",
                iconStyle: "solid",
                disabled: status != 0 || itemData.type == "data",
              },
              {
                ret: 1,
                text: "Mark Unavailable",
                icon: "xmark",
                iconStyle: "solid",
                disabled: status == 4 || status == 2,
              },
              {
                ret: 3,
                text: "Print",
                icon: "print",
                iconStyle: "solid",
                disabled: status == 0 || itemData.type == "task",
              },
              {
                ret: 4,
                text: "Download",
                icon: "download",
                iconStyle: "solid",
                disabled: status == 0 || itemData.type == "task",
              },
              {
                ret: 0,
                text: "Delete / Unsend",
                icon: "trash-alt",
                iconStyle: "solid",
              },
            ]}
          />
        {/if}

        {#if type == "form"}
          <Dropdown
            triggerType="vellipsis"
            clickHandler={(ret) =>
              handleFormDropDown(ret, itemData, chkListdata)}
            elements={[
              {
                ret: 1,
                icon: "glasses",
                text: "Review",
                disabled: chkListdata.state.status !== 2,
              },
              {
                ret: 2,
                icon: "bell",
                text: "Remind",
                blocked:
                  chkListdata.state.status === 2 ||
                  chkListdata.state.status === 9 ||
                  chkListdata.state.status === 10 ||
                  chkListdata.state.status === 4,
              },
              {
                ret: 3,
                icon: "trash-alt",
                text: "Unsend / Delete",
              },
            ]}
          />
        {/if}
      </div>
    </div>
  </div>

  <div class="content" class:text-dark={!(status == 2 || status == 4)}>
    <div class="left_content">
      <Tag
        content={missing_reason || statusText[status]}
        classes="tag-text"
        style={tagStyle(status)}
        has_icon={true}
        icon={statusIcon[status]}
      />
    </div>
    <div class="right_content">
      <div>
        {itemData.state.date}
        {status == 0 ? " (sent)" : ""}
      </div>
      <div>
        {nextEventHandler()}
      </div>
    </div>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    color: var(--text-secondary);
  }
  .panel-text {
    display: flex;
    flex-direction: column;
    word-break: break-word;
  }
  .status {
    flex: 0 0 45px;
  }
  .title-text {
    font-size: 1rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
    color: var(--text-dark);
  }
  .subtitle-text {
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

  .text-dark {
    color: #000 !important;
  }
  .text-grey {
    color: var(--text-secondary) !important;
  }

  .content {
    display: flex;
    justify-content: space-between;
    margin-top: 0.5rem;
    align-items: center;
  }
</style>
