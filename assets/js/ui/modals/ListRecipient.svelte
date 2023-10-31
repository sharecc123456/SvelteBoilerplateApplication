<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  import TablePager from "Components/TablePager.svelte";
  import TableSorter from "Components/TableSorter.svelte";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";
  import { createEventDispatcher } from "svelte";
  import { convertTime } from "Helpers/util.js";
  import { SORT_FIELDS } from "BoilerplateAPI/Recipient";
  import Tag from "Atomic/Tag";

  export let sort = "";
  export let page = 1;
  export let totalPages = 1;
  export let handlePrevPage = () => {};
  export let handleNextPage = () => {};
  export let sortDirection = "";
  export let sortRecipientData = (a) => {};
  export let search_value = "";

  const dispatch = createEventDispatcher();

  const TableHeaderMapper = {
    name: { header: "Contact", sortKey: SORT_FIELDS.NAME },
    // company: { header: "Company / Org", sortKey: SORT_FIELDS.COMPANY },
    added_datetime: { header: "Date Added", sortKey: SORT_FIELDS.DATE_ADDED },
    last_modified_datetime: {
      header: "Last Modified",
      sortKey: SORT_FIELDS.LAST_MODIFIED,
    },
  };

  export let recipients = [];
  export let currently_selected;
  export let isMultipleCheck = false;

  let checkedRecipients = [];

  //if multiple enabled it will runs and give back the array to ChooseMultiRecipientModal
  $: dispatch("selectedMultiRecipients", {
    multi_selected: checkedRecipients,
  });

  function dispatchSelection() {
    dispatch("selectedRecipient", {
      currently_selected: currently_selected,
    });
  }

  const onSelectRecipient = (row) => {
    if (currently_selected == row.id) currently_selected = undefined;
    else currently_selected = row.id;
    dispatchSelection();
  };

  let showRecipientDeleteConfirmation = false;
  const SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY =
    "dontShowRecipientDeleteConfirmation";
  let hideRecipientDeleteConfirmationStatus = JSON.parse(
    localStorage.getItem(SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY)
  );
  let bulkSendConfirmation = false;
  let assigning_for = undefined;
  $: assigning_id = null;

  const assignAndSend = () => {
    const recp = assigning_for;
    assigning_for = undefined;
    onSelectRecipient(recp);
  };

  const handleRecipientDeletedClick = (bulkSend = false) => {
    bulkSendConfirmation = bulkSend;
    showRecipientDeleteConfirmation = true;
  };
  const handleRecipientDeleteConfirmation = () => {
    showRecipientDeleteConfirmation = false;
    if (bulkSendConfirmation) {
      handleBulkSelect(assigning_for);
      return;
    }
    assignAndSend();
  };
  const handleBulkSelect = () => {
    const recp = assigning_for;
    assigning_for = undefined;
    const recpIndex = checkedRecipients.findIndex(
      (crecp) => crecp.id === recp.id
    );
    if (recpIndex == -1) checkedRecipients = [...checkedRecipients, recp];
    else
      checkedRecipients = [
        ...checkedRecipients.slice(0, recpIndex),
        ...checkedRecipients.slice(recpIndex + 1),
      ];
  };
</script>

<div class="table">
  {#if recipients.length}
    <div class="tr th">
      <div class="td toggle" />
      {#each Object.keys(TableHeaderMapper) as header}
        <div
          class:name={header == "name"}
          class:name-hd={header == "name"}
          class:date={header != "name"}
          class="td"
        >
          <span
            on:click={() =>
              sortRecipientData(TableHeaderMapper[header].sortKey)}
            class="headerRecipient sortable {TableHeaderMapper[header]
              .sortKey == sort
              ? 'selectedBorder'
              : ''}"
          >
            &nbsp; {TableHeaderMapper[header].header} &nbsp;
            <TableSorter
              column={TableHeaderMapper[header].sortKey}
              {sort}
              {sortDirection}
            />
            &nbsp;
          </span>
        </div>
      {/each}
    </div>

    <div>
      {#each recipients as cl}
        {#if !isMultipleCheck}
          <div
            class="tr cursor-pointer {assigning_id === cl.id ? 'active' : ''}"
            class:recipient-deleted={cl.deleted}
            on:click={() => {
              assigning_for = cl;
              assigning_id = cl.id;
              if (cl.deleted && !hideRecipientDeleteConfirmationStatus) {
                handleRecipientDeletedClick();
                return;
              }
              assignAndSend();
            }}
          >
            <div class="td toggle">
              {#if currently_selected == cl.id}
                <span>
                  <FAIcon icon="dot-circle" />
                </span>
              {:else}
                <span>
                  <FAIcon icon="circle" iconStyle="regular" />
                </span>
              {/if}
            </div>
            <div class="td name">
              <p>
                {cl.name}
                {cl.company.length > 1 ? "(" + cl.company + ")" : ""}
              </p>
              <p>{"<" + cl.email + ">"}</p>
              {#if cl.tags}
                <ul class="reset-style">
                  {#each cl.tags.values as tag}
                    <Tag isSmall={true} {tag} allowDeleteTags={false} />
                  {/each}
                </ul>
              {/if}
            </div>
            <!-- <div class="td date">{cl.company}</div> -->
            <div class="td date is-double-line">
              <div>{cl.added}</div>
              <div class="small-font-size">
                {convertTime(cl.added, cl.added_time)}
              </div>
            </div>
            <div class="td date is-double-line">
              <div>{cl.last_modified}</div>
              <div class="small-font-size">
                {convertTime(cl.last_modified, cl.modified_time)}
              </div>
            </div>
            <!-- <div class="td toggle padding" /> -->
          </div>
        {:else}
          <!-- Multiple check for bulk assign -->
          {#if cl.email
            .toLowerCase()
            .includes(search_value.toLowerCase()) || cl.name
              .toLowerCase()
              .includes(search_value.toLowerCase())}
            <label for={cl?.id}>
              <div
                class="tr cursor-pointer"
                class:recipient-deleted={cl.deleted}
                on:click={() => {
                  assigning_for = cl;
                  const alreadyChecked =
                    checkedRecipients.find((crecp) => crecp.id === cl.id) ||
                    false;
                  if (
                    !alreadyChecked &&
                    cl.deleted &&
                    !hideRecipientDeleteConfirmationStatus
                  ) {
                    handleRecipientDeletedClick(true);
                    return;
                  }
                  handleBulkSelect();
                }}
              >
                <div class="td toggle">
                  <label for={cl?.id}>
                    <span>
                      {#if checkedRecipients.find((crecp) => crecp.id === cl.id) || false}
                        <FAIcon icon="check-square" iconStyle="solid" />
                      {:else}
                        <FAIcon icon="square" iconStyle="regular" />
                      {/if}
                    </span>
                  </label>
                </div>
                <div class="td name">
                  <p>
                    {cl.name}
                    {cl.company.length > 1 ? "(" + cl.company + ")" : ""}
                  </p>
                  <p>{"<" + cl.email + ">"}</p>
                </div>
                <!-- <div class="td date">{cl.company}</div> -->
                <div class="td date is-double-line">
                  <div>{cl.added}</div>
                  <div class="small-font-size">
                    {convertTime(cl.added, cl.added_time)}
                  </div>
                </div>
                <div class="td date is-double-line">
                  <div>{cl.last_modified}</div>
                  <div class="small-font-size">
                    {convertTime(cl.last_modified, cl.modified_time)}
                  </div>
                </div>
              </div>
            </label>
          {/if}
        {/if}
      {/each}
    </div>

    <TablePager {page} {totalPages} {handleNextPage} {handlePrevPage} />
  {:else}
    <div class="tr-full">
      <p>
        No Contacts Found. Please add them using the Add New Contact button
        above.
      </p>
    </div>
  {/if}
</div>

{#if showRecipientDeleteConfirmation && !hideRecipientDeleteConfirmationStatus}
  <ConfirmationDialog
    question={`Are you sure you want to assign to deleted Contact?`}
    yesText="Yes, retrieve the contact"
    noText="No"
    yesColor="secondary"
    noColor="gray"
    on:yes={handleRecipientDeleteConfirmation}
    on:close={() => {
      showRecipientDeleteConfirmation = false;
    }}
    checkBoxEnable={"enable"}
    checkBoxText={"Don't ask me this again"}
    on:hide={(event) => {
      if (event?.detail) {
        localStorage.setItem(
          SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY,
          event?.detail
        );
        hideRecipientDeleteConfirmationStatus = true;
      } else {
        localStorage.setItem(SHOW_RECIPIENT_DELETE_CONFIRMATION_KEY, false);
      }
    }}
  />
{/if}

<style>
  .headerRecipient {
    width: 95%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .headerRecipient:first-of-type {
    margin-left: -2rem;
  }
  .selectedBorder {
    border: 1px solid #76808b;
    border-radius: 5px;
  }

  .recipient-deleted {
    text-decoration: line-through;
    background: #f5d8cb !important;
  }

  .is-double-line {
    flex-direction: column !important;
    text-align: center;
  }

  .small-font-size {
    font-size: 10px;
  }

  .cursor-pointer {
    cursor: pointer;
  }
  .sortable {
    cursor: pointer;
    left: 6px;
    top: 0px;
    position: relative;
    color: #76808b;
  }

  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    width: 100%;
    position: relative;
  }

  .th {
    display: none;
    position: sticky;
    top: 145px;
    background: #ffffff;
    margin-top: 4px;
    margin-bottom: 4px;
  }

  .th > .td {
    justify-content: left;
    align-items: left;

    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 16px;
    letter-spacing: 0.01em;
    text-transform: capitalize;
    color: #7e858e;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    cursor: pointer;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 0.5rem 0rem;
    padding-left: 0.5rem;
    margin-bottom: 1rem;
  }

  .tr.cursor-pointer.active {
    box-shadow: 0 4px 6px rgba(50, 50, 93, 0.11), 0 1px 3px rgba(0, 0, 0, 0.08);
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
  }

  .tr-full {
    display: flex;
    flex-flow: column nowrap;

    font-style: normal;
    font-weight: normal;
    font-size: 16px;
    line-height: 16px;
    letter-spacing: 0.01em;
    color: #7e858e;

    justify-content: center;
    align-items: center;
  }

  .td.toggle {
    flex-grow: 0;
    flex-basis: 25px;
    width: 25px;
    user-select: none;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    cursor: pointer;
  }

  .td.name {
    flex-grow: 1;
    display: flex;
    flex-flow: column nowrap;
  }
  .td.name-hd {
    display: flex;
    flex-direction: row;
  }

  .td.name > p {
    padding: 0;
    margin: 0;
  }

  .td.name > p:nth-child(1) {
    font-size: 14px;
    line-height: 18px;
    color: #171f46;
  }

  .td.name > p:nth-child(2) {
    font-size: 12px;
    line-height: 14px;
    color: #7e858e;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .td.date {
    display: none;
  }

  :not(.th) > .td.date {
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #2a2f34;
  }

  .reset-style {
    margin-block-start: 0em;
    margin-block-end: 0em;
    padding-inline-start: 0px;
  }
  @media only screen and (min-width: 640px) {
    .tr {
      padding-left: 1rem;
      padding-right: 1rem;
    }
  }
  @media only screen and (min-width: 780px) {
    .td.date {
      justify-content: center;
      display: flex;
    }
    .td.name {
      grid-template-columns: 1fr;
    }
    .td.name > p:nth-child(1) {
      font-size: 14px;
    }

    .tr:not(.th) {
      background: #ffffff;
      border: 0.5px solid #b3c1d0;
      box-sizing: border-box;
      border-radius: 10px;
      padding: 1;
      margin-bottom: 1rem;
    }

    .td.name > p:nth-child(2) {
      font-size: 12px;
    }
  }
</style>
