<script>
  import FAIcon from "Atomic/FAIcon.svelte";
  import DashboardStatus from "Components/DashboardStatus.svelte";
  import Dropdown from "Components/Dropdown.svelte";
  import { isMobile } from "../../../../helpers/util";
  import {
    getNextEventForStatus,
    getNextStatusForReq,
    getNextStatusForTemplates,
  } from "../../../../nextEventData";
  import Button from "../../../atomic/Button.svelte";
  import Tag from "../../../atomic/Tag.svelte";
  import ChecklistButton from "./ChecklistButton.svelte";
  import DocumentRowButton from "./DocumentButton.svelte";
  import RequestButton from "./RequestButton.svelte";
  import EmailFaultDialog from "../../EmailFaultDialog.svelte";
  export let checklist_chevron = [];
  export let checklist = {};
  export let recipient = {};
  export let archived = false;
  export let showViewModal = (a) => {};
  export let tryRemindNow = () => {};
  export let handleItemPopup = (a) => {};
  export let handleAssignmentDropdownClick = (a, b) => {};
  export let handleFormDropDown = (a, b) => {};
  export let toggleChevron = (a) => {};

  let deleted = checklist.state.status == 9 || checklist.state.status == 10;

  let deliveryfaultData;
  let handleDeliveryFault = false;
  function handleDeliveryFaultPopup(recipient) {
    deliveryfaultData = recipient;
    handleDeliveryFault = true;
  }
</script>

<div class="checklist">
  <div
    class="checklist-inner clickable"
    class:green-shade={checklist.state.status === 4}
    class:red-shade={checklist.state.status === 2}
    class:deleted-row={deleted}
    on:click|stopPropagation={() => {
      console.log(checklist);
      checklist_chevron[checklist.id] = !checklist_chevron[checklist.id];
    }}
  >
    <div
      class="checklist-info"
      class:green-shade={checklist.state.status === 4}
      class:red-shade={checklist.state.status === 2}
    >
      <div
        class="name-chevron"
        on:click|stopPropagation={() => {
          checklist_chevron[checklist.id] = !checklist_chevron[checklist.id];
        }}
      >
        {#if checklist_chevron[checklist.id]}
          <FAIcon color={true} icon="minus" />
        {:else}
          <FAIcon color={true} icon="plus" />
        {/if}
      </div>
      <div class="td name pl-2">
        <!-- <span class="checklist-force-pad" />
        <div
          class="name-chevron"
          on:click|stopPropagation={() => {
            checklist_chevron[checklist.id] = !checklist_chevron[checklist.id];
          }}
        >
          <span
            ><FAIcon
              color={true}
              icon={checklist_chevron[checklist.id] ? "minus" : "plus"}
            /></span
          >
        </div> -->
        <div
          class="name-description clickable"
          on:click|stopPropagation={() =>
            (checklist_chevron[checklist.id] =
              !checklist_chevron[checklist.id])}
        >
          <div class="name-name truncate">
            {checklist.name}
            {#if checklist.requestor_reference}
              <div style="margin-left: 5px;" class="name-desc">
                # [{checklist.requestor_reference}]
              </div>
            {/if}
          </div>
          <div class="name-desc truncate" style="flex-direction: column">
            {#if checklist.recipient_reference}
              <div>
                <span style="font-weight: bolder">Recipient Ref:</span>
                {checklist.recipient_reference}
              </div>
            {/if}
            <div>
              {checklist.subject}
            </div>
          </div>
          {#if checklist.tags}
            <div class="cl-description">
              <ul class="reset-style">
                {#each checklist.tags as tag}
                  <Tag tag={{ ...tag, selected: true }} listTags={true} />
                {/each}
              </ul>
            </div>
          {/if}
        </div>
      </div>
      <div class="td status pl-2">
        <DashboardStatus
          state={checklist.state}
          delivery_fault={checklist.state.delivery_fault}
        />
      </div>
      <div class="td next pl-2">
        {getNextEventForStatus(checklist)}
      </div>
      <div class="td actions actions-btn pl-2">
        <ChecklistButton
          {...{
            archived,
            checklist,
            toggleChevron,
            recipient,
            tryRemindNow,
            handleDeliveryFaultPopup,
          }}
        />
        <Dropdown
          triggerType="vellipsis"
          clickHandler={(ret) => {
            handleAssignmentDropdownClick(
              checklist,
              ret,
              "Oops",
              recipient?.id
            );
          }}
          elements={[
            { ret: 1, icon: "archive", text: "Archive", disabled: archived },
            { ret: 6, icon: "archive", text: "Unarchive", disabled: !archived },
            {
              text: "View/ export data",
              icon: "file-import",
              iconStyle: "solid",
              ret: 10,
            },
            {
              ret: 12,
              icon: "download",
              text: "Download",
              disabled: !(
                checklist.state.status === 2 || checklist.state.status === 4
              ),
            },
            {
              ret: 2,
              icon: "trash-alt",
              text: "Unsend / Delete",
            },
          ]}
        />
      </div>
    </div>
    {#if checklist_chevron[checklist.id]}
      {#each checklist.document_requests as document}
        <div class="document">
          <div
            class="document-inner"
            class:green-shade={document.state.status == 4}
            class:red-shade={document.state.status == 2}
            class:deleted-row={document.state.status == 9 ||
              document.state.status == 10}
            on:click|stopPropagation={() => handleItemPopup(document)}
          >
            <div class="td name">
              <div class="filerequest md:gap-2">
                <FAIcon
                  icon={document.is_rspec ? "file-user" : "file-alt"}
                  iconStyle="regular"
                />
                <div class="filerequest-name clickable">
                  <span>{document.name}</span>
                  <div>{document.description}</div>
                  <div>
                    {#if document.tags}
                      <ul class="reset-style">
                        {#each document.tags.values as tag}
                          <Tag
                            tag={{ ...tag, selected: true }}
                            listTags={true}
                          />
                        {/each}
                      </ul>
                    {/if}
                  </div>
                </div>
              </div>
            </div>
            <div class="td status ">
              <DashboardStatus
                state={document.state}
                delivery_fault={checklist.state.delivery_fault}
              />
            </div>
            <div class="td next">
              {getNextStatusForTemplates(document, checklist)}
            </div>
            <div class="td border-end actions-btn">
              <DocumentRowButton
                {...{
                  archived,
                  document,
                  checklist,
                  recipient,
                  tryRemindNow,
                  handleDeliveryFaultPopup,
                }}
              />
              <Dropdown
                triggerType="vellipsis"
                clickHandler={(ret) => {
                  handleAssignmentDropdownClick(checklist, ret, document);
                }}
                elements={[
                  {
                    ret: 9,
                    icon: "eye",
                    text: "View",
                    disabled: document.state.status !== 0,
                  },
                  {
                    ret: 11,
                    icon: "undo",
                    text: "Update and resend",
                    disabled: document.state.status !== 0 || !document.is_rspec,
                  },
                  {
                    text: "Upload For Client",
                    icon: "file-upload",
                    iconStyle: "solid",
                    disabled: document.state.status != 0,
                    ret: 5,
                  },
                  {
                    ret: 3,
                    icon: "print",
                    text: "Print",
                    disabled: document?.state.status == 0 || isMobile(),
                  },
                  {
                    ret: 4,
                    icon: "download",
                    text: "Download",
                    disabled: document?.state.status == 0 || isMobile(),
                  },
                  {
                    ret: 2,
                    icon: "trash-alt",
                    text: "Unsend / Delete",
                  },
                ]}
              />
            </div>
          </div>
        </div>
      {/each}
      {#each checklist.file_requests as file}
        <div class="document ">
          <div
            class:green-shade={file.state.status === 4 ||
              file.state.status === 6}
            class="document-inner"
            class:red-shade={file.state.status === 2}
            class:deleted-row={file.state.status == 9 ||
              file.state.status == 10}
            on:click|stopPropagation={() => handleItemPopup(file)}
          >
            <div class="td name clickable">
              <div class="">
                <div class="filerequest md:gap-2">
                  <FAIcon
                    icon={file.type === "file"
                      ? "paperclip"
                      : file.type === "task"
                      ? "thumbtack"
                      : "font-case"}
                    iconStyle="regular"
                  />
                  <div
                    class="filerequest-name pl-1"
                    style={file.type === "data" && "padding-left: 4px;"}
                  >
                    <span>{file.name}</span>
                    <div>
                      {file.type === "file"
                        ? "File Request"
                        : file.type === "task"
                        ? "Task"
                        : "Data Request"}
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div class="td border-middle status">
              <DashboardStatus
                state={file.state}
                expiration_info={file.expiration_info}
                isMissing={file.missing_reason}
                delivery_fault={checklist.state.delivery_fault}
              />
            </div>
            <div class="td next">
              {getNextStatusForReq(file, checklist)}
            </div>
            <div class="td border-end actions-btn">
              <RequestButton
                {...{
                  archived,
                  checklist,
                  file,
                  recipient,
                  tryRemindNow,
                  showViewModal,
                  handleItemPopup,
                  handleDeliveryFaultPopup,
                }}
              />
              <Dropdown
                triggerType="vellipsis"
                clickHandler={(ret) => {
                  handleAssignmentDropdownClick(checklist, ret, file);
                }}
                elements={[
                  {
                    ret: 2,
                    icon: "trash-alt",
                    text: `${archived ? "Delete" : "Unsend / Delete"}`,
                  },
                  {
                    ret: 3,
                    icon: "print",
                    text: "Print",
                    disabled:
                      file?.type == "data" ||
                      file?.type == "task" ||
                      file?.state.status == 0 ||
                      file?.state.status == 1 ||
                      file?.state.status == 6 ||
                      isMobile(),
                  },
                  {
                    ret: 4,
                    icon: "download",
                    text: "Download",
                    disabled:
                      file?.type == "data" ||
                      file?.type == "task" ||
                      file?.state.status == 0 ||
                      file?.state.status == 1 ||
                      file?.state.status == 6 || // missing doc
                      isMobile(),
                  },
                  {
                    text: "Upload For Client",
                    icon: "file-upload",
                    iconStyle: "solid",
                    disabled:
                      file?.type == "data" ||
                      file?.type == "task" ||
                      file.state.status != 0,
                    ret: 7,
                  },
                  {
                    text: "Edit Expiration",
                    icon: "edit",
                    iconStyle: "solid",
                    ret: 8,
                    disabled:
                      file.state.status === 0 ||
                      file.state.status === 1 ||
                      file.state.status === 3 ||
                      file.state.status === 5 ||
                      file.state.status === 6 ||
                      file?.type === "task" ||
                      file?.type === "data",
                  },
                ]}
              />
            </div>
          </div>
        </div>
      {/each}
      {#each checklist.forms as form}
        <div class="document">
          <div
            class="document-inner"
            class:green-shade={form.state.status === 4}
            class:red-shade={form.state.status === 2}
            class:deleted-row={form.state.status === 9 ||
              form.state.status === 10}
            on:click|stopPropagation={() => {
              if (form.state.status == 2) {
                window.location.hash = `#review/${checklist.contents_id}/form/${form.id}`;
              } else if (form.state.status == 4) {
                window.location.hash = `#submission/view/8/${checklist.id}/${form.id}`;
              }
            }}
          >
            <div class="td name clickable">
              <div class="filerequest md:gap-2">
                <FAIcon icon="rectangle-list" iconStyle="regular" />
                <div class="filerequest-name clickable">
                  <span>{form.title}</span>
                  <div>
                    {form.description}
                  </div>
                </div>
              </div>
            </div>
            <div class="td border-middle status">
              <DashboardStatus
                state={form.state}
                delivery_fault={checklist.state.delivery_fault}
              />
            </div>
            <div class="td next">
              {getNextStatusForTemplates(form, checklist)}
            </div>
            <div class="td border-end actions-btn request">
              <div class="w-9/12">
                {#if checklist.state.delivery_fault}
                  <div
                    on:click|stopPropagation={() => {
                      handleDeliveryFaultPopup(recipient);
                    }}
                  >
                    <Button text="Resolve" color="danger" />
                  </div>
                {:else if form.state.status == 0}
                  <div
                    on:click|stopPropagation={() => {
                      tryRemindNow(
                        checklist.id,
                        recipient.id,
                        checklist.last_reminder_info
                      );
                    }}
                  >
                    <Button text="Remind" color="white" />
                  </div>
                {:else if form.state.status == 1}
                  <div
                    on:click|stopPropagation={() => {
                      tryRemindNow(
                        checklist.id,
                        recipient.id,
                        checklist.last_reminder_info
                      );
                    }}
                  >
                    <Button text="Remind" color="white" />
                  </div>
                {:else if form.state.status == 2}
                  <div
                    on:click|stopPropagation={() =>
                      (window.location.hash = `#review/${checklist.contents_id}/form/${form.id}`)}
                  >
                    <Button text="Review" />
                  </div>
                {:else if form.state.status == 3}
                  <div
                    on:click|stopPropagation={() => {
                      tryRemindNow(
                        checklist.id,
                        recipient.id,
                        checklist.last_reminder_info
                      );
                    }}
                  >
                    <Button text="Remind" color="white" />
                  </div>
                {:else if form.state.status == 4}
                  <div
                    class="view-btn"
                    on:click|stopPropagation={() => {
                      window.location.hash = `#submission/view/8/${checklist.id}/${form.id}`;
                    }}
                  >
                    <Button text="View" color="gray" />
                  </div>
                {:else if form.state.status == 9 || form.state.status == 10}
                  <span class="view-btn">
                    <Button disabled={true} text="View" color="gray" />
                  </span>
                {:else}
                  <Button text="_BUG_" />
                {/if}
              </div>
              <!-- Form Level Dropdown -->
              <Dropdown
                triggerType="vellipsis"
                clickHandler={(ret) =>
                  // handleFormDropDown(checklist, ret, form)}
                  handleFormDropDown(ret, form, checklist, recipient.id)}
                elements={[
                  {
                    ret: 1,
                    icon: "glasses",
                    text: "Review",
                    disabled: checklist.state.status !== 2,
                  },
                  {
                    text: "View/ export data",
                    icon: "file-import",
                    iconStyle: "solid",
                    ret: 10,
                  },
                  {
                    ret: 3,
                    icon: "trash-alt",
                    text: "Unsend / Delete",
                  },
                ]}
              />
            </div>
          </div>
        </div>
      {/each}
    {/if}
  </div>
</div>

{#if handleDeliveryFault}
  <EmailFaultDialog
    email={deliveryfaultData.email}
    user_name={deliveryfaultData.name}
    company={deliveryfaultData.company}
    recipient_id={deliveryfaultData.id}
    on:close={() => {
      handleDeliveryFault = false;
    }}
  />
{/if}

<style>
  .reset-style {
    margin: 0;
    padding: 0;
  }

  .filerequest {
    display: flex;
    flex-flow: row nowrap;
  }

  .filerequest:nth-child(1) {
    font-size: 24px;
    align-items: center;
    color: #606972;
  }

  .filerequest-name {
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
  }

  .filerequest-name > *:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #2a2f34;
  }

  .filerequest-name > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }

  .green-shade {
    background: #d1fae5 !important;
  }

  .red-shade {
    border-radius: 10px;
    border-color: #db5244 !important;
    border-width: 2px !important;
    border-style: dashed !important;
  }
  .actions-btn :global(button) {
    z-index: 10;
    margin-bottom: 0;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  /* Names */
  .name-description {
    width: 90%;
    display: flex;
    flex-flow: column nowrap;
  }

  .name-name {
    display: flex;
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #171f46;
  }

  .name-desc {
    display: flex;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  .actions-btn {
    width: 100%;
  }

  .checklist {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
    padding-bottom: 1rem;
  }
  .checklist-info {
    display: grid;
    width: 100%;
  }
  @media only screen and (min-width: 768px) {
    .checklist-info {
      grid-template-columns: 40px 1.7fr 1fr 1fr 145px;
      grid-template-areas: "a b c d e";
      grid-template-rows: 1fr;
      border-radius: 10px;
    }
  }

  .checklist-info .td.status {
    /* grid-area: b; */
    display: flex;
    justify-self: left;
  }

  .checklist-info .td.next {
    /* grid-area: c; */
    display: flex;
    justify-self: left;
  }

  .checklist-info .td.actions {
    /* grid-area: d; */
    justify-self: center;
    display: flex;
    justify-content: space-around;
  }

  .checklist-inner {
    display: flex;
    flex-flow: column nowrap;
    align-items: center;
    width: 100%;

    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 0.5rem;
  }

  .document {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    width: 100%;
  }

  .document-inner {
    display: grid;
    flex-flow: column nowrap;
    align-items: center;
    width: calc(100% - 14px);

    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    padding: 0.5rem;
    margin: 0.5rem auto;
  }

  .document-inner .td.border-end {
    /* grid-area: c; */
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .name-chevron {
    width: 24px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .td.name {
    flex-grow: 3;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .td.actions {
    justify-content: flex-start;
    align-items: center;
    flex-grow: 1;
  }

  .clickable {
    cursor: pointer;
  }
  .td.border-end {
    display: grid;
    justify-items: start;
  }
  @media only screen and (min-width: 768px) {
    .td.status {
      display: grid;
      justify-items: start;
    }

    .td.next {
      display: grid;
      justify-items: start;
    }

    .checklist-info .td.status {
      margin-left: 0px;
    }

    .document-inner {
      grid-template-areas: "a b c d";
      grid-template-rows: 1fr;
      grid-template-columns: 1.7fr 0.95fr 0.95fr 130px;
    }
    .document-inner .td.status {
      margin-left: 0px;
    }
  }

  .deleted-row {
    text-decoration: line-through;
    background: #f5d8cb !important;
  }

  @media only screen and (min-width: 768px) {
    .document-inner {
      padding-right: 0.6rem;
    }
  }
</style>
