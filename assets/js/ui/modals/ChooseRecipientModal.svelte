<script>
  import { createEventDispatcher, onDestroy, onMount } from "svelte";
  import Button from "../atomic/Button.svelte";
  import TextField from "../components/TextField.svelte";
  import Loader from "../components/Loader.svelte";
  import ListRecipient from "../modals/ListRecipient.svelte";
  import QuickAddClient from "../modals/QuickAddClient.svelte";
  import {
    getRecipients,
    newRecipient,
    SORT_FIELDS,
    getRecipientsPaginated,
    SHOW_DELETED_RECIPIENT_KEY,
    getRecipient,
    recipientRestore,
  } from "BoilerplateAPI/Recipient";
  import { debounce, getLocalStorage, isNullOrUndefined } from "Helpers/util";
  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";
  import { showToast } from "../../helpers/ToastStorage";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;
  let submitClicked = false;
  let tagsSelected = [];
  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  let duplicateAssign = false;

  let search_value;
  let currently_selected = undefined;
  let selection_count = 0;

  function submitSelection() {
    dispatch("selectionMade", {
      recipientId: currently_selected,
    });
  }

  let showQuickAddClient = false;

  let newR = { name: "", organization: "", email: "" };

  const onSubmitNewContact = async (event) => {
    const {
      firstName,
      lastName,
      organization,
      email,
      phone_number,
      start_date,
    } = event.detail;

    const name = `${firstName} ${lastName}`;
    newR = { name, organization, email, phone_number, start_date };
    newR.tags = tagsSelected.map((x) => x.id);
    let reply = await newRecipient(newR);
    if (reply.ok) {
      await loadRecipientData();
      resetRecipientModal(newR);
      newR = {};
      submitClicked = false;
    } else {
      if (reply.status === 400) {
        const { error, is_deleted, id } = await reply.json();
        const alreadyExists = error === "already_exists";
        if (alreadyExists && is_deleted) {
          deletedId = id;
          showDeleteRestoreModal = true;
        } else showToast("User already exists", 1000, "default", "MM");
        search_value = newR.email;
        submitClicked = false;
      }
    }
  };
  let showDeleteRestoreModal = false;
  let deletedId = -1;
  const handleRecipientRestoration = async () => {
    const recp = await getRecipient(deletedId);
    const restored = await handleRecipientRestore(recp);
    if (restored) {
      showDeleteRestoreModal = false;
      resetRecipientModal(recp);
    }
  };

  const resetRecipientModal = (recp) => {
    search_value = recp.email;
    showQuickAddClient = false;
    currently_selected_email = recp.email;
    loadRecipientData();
  };

  const handleRecipientRestore = async (recp) => {
    try {
      const reply = await recipientRestore(recp.id);
      if (!reply.ok) throw new Error("Unknown Error");
      loadRecipientData(page);
      return true;
    } catch (err) {
      console.error(err);
      alert("Error occured while restoring Contact Id:", recp.id);
      return false;
    }
  };

  async function addNewRecip(recp, fName) {
    /* submit the information */
    let reply = await newRecipient(recp);
    if (reply.ok) {
      // select and display the newly added contact in the contacts modal
      search_value = fName;
      showQuickAddClient = false;
      currently_selected_email = recp.email;
      loadRecipientData();
    }
  }

  function getCompanies(obj) {
    const companies = obj.map((recp) => recp.company);
    return [...new Set(companies)];
  }

  let value;
  $: currently_selected = value;
  // pagination stuff
  let page = 1;
  let totalPages = 1;
  let recipients = [];
  let hasNext = false;
  let loading = true;
  let count = 0;
  let sort = SORT_FIELDS.NAME;
  let sortDirection = "asc";
  let elm;
  let currently_selected_email = "";
  const show_deleted_recipients = getLocalStorage(SHOW_DELETED_RECIPIENT_KEY);

  const loadRecipientData = async (targetPage = 1) => {
    loading = true;
    try {
      const params = {
        page: targetPage,
        search: search_value || "",
        sort,
        sort_direction: sortDirection,
        show_deleted_recipients,
      };

      const res = await getRecipientsPaginated(params);

      console.log(res);

      page = res.page;
      recipients = res.data;
      totalPages = res.total_pages;
      hasNext = res.has_next;
      count = res.count;
      console.log("recipients", recipients);
      //set automatically selected the search value
      const selectedContact = recipients.find(
        (recipient) =>
          recipient.email.toLowerCase() ===
          currently_selected_email.toLowerCase()
      );
      currently_selected = isNullOrUndefined(selectedContact)
        ? undefined
        : selectedContact.id;

      if (currently_selected !== undefined) {
        submitSelection();
      }
    } catch (err) {
      console.error(err);
      page = 1;
      totalPages = 1;
      recipients = [];
      hasNext = false;
      count = 0;
    }
    loading = false;
  };

  const handleNextPage = () => {
    if (hasNext) loadRecipientData(page + 1);
  };

  const handlePrevPage = () => {
    if (page > 1) loadRecipientData(page - 1);
  };

  const handleServerSearch = () => {
    loadRecipientData();
  };

  const sortRecipientData = (_targetSort = "name") => {
    // direction change
    if (sort === _targetSort)
      sortDirection = sortDirection === "asc" ? "desc" : "asc";
    else {
      // sort change
      sort = _targetSort;
      sortDirection = "asc";
    }

    loadRecipientData();
  };

  const debouncedSearch = debounce(handleServerSearch, 1000);

  const bindSearchKeyup = () => {
    elm.addEventListener("keyup", debouncedSearch);
  };

  onMount(async () => {
    bindSearchKeyup();
    try {
      await loadRecipientData();
    } catch (err) {
      console.error(err);
    }
  });
  // pagination stuff
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          Add or select a contact to assign
          <span on:click={close}>
            <slot name="closer" />
          </span>
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>

        <div class="inner-preamble" style="margin-bottom: 0.5rem">
          <span style="grid-area: a / a / b / b;">
            <TextField
              bind:value={search_value}
              bind:elm
              icon="search"
              text="Add Email or Search Contacts"
              width="100%"
              enterCallback={(evt) => {
                if (!recipients.length) {
                  showQuickAddClient = true;
                }
              }}
            />
          </span>
          <span
            style="grid-area: c;"
            on:click={() => {
              showQuickAddClient = true;
            }}
          >
            <Button
              color="primary"
              text="Add New Contact"
              disabled={currently_selected != undefined}
            />
          </span>
        </div>
        <span class="sm-hide" style="font-weight: bold; color: #76808B">
          To show previously deleted contacts, go to Contacts tab and switch
          'show deleted contacts'.
        </span>
      </div>
      <div class="content">
        {#if loading}
          <Loader loading />
        {:else}
          <ListRecipient
            {recipients}
            on:selectedRecipient={(event) => {
              value = event.detail.currently_selected;
              currently_selected = value;
            }}
            {currently_selected}
            {sort}
            {sortDirection}
            {sortRecipientData}
            {page}
            {totalPages}
            {handlePrevPage}
            {handleNextPage}
          />
        {/if}
      </div>
    </div>
    <div class="footer">
      <span class="Assign-Selected">
        <Button
          color="secondary medium"
          text="Select and Next"
          disabled={isNullOrUndefined(currently_selected)}
          onClickHandler={() => submitSelection()}
        />
      </span>
    </div>
  </div>
</div>

{#if showQuickAddClient}
  <QuickAddClient
    companies={getCompanies(recipients)}
    on:message={onSubmitNewContact}
    on:close={() => {
      showQuickAddClient = false;
      duplicateAssign = false;
    }}
    SearchEmail={search_value}
    {recipients}
    {duplicateAssign}
    bind:submitClicked
    bind:tagsSelected
  />
{/if}

{#if showDeleteRestoreModal}
  <ConfirmationDialog
    question="This user has been deleted, do you want to restore them?"
    yesText="Yes"
    noText="No"
    yesColor="secondary"
    noColor="gray"
    on:yes={handleRecipientRestoration}
    on:close={() => {
      showDeleteRestoreModal = false;
    }}
  />
{/if}

<style>
  .inner-preamble {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }

  .inner-content {
    position: sticky;
    top: 0;
    z-index: 98;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 14px;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 101;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    padding-right: 0.6875em;
    margin-bottom: 1rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .modal-content {
    padding: 1rem;
    display: flex;
    flex-direction: column;
  }

  .modal-x {
    /* position: absolute; */

    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;
    cursor: pointer;
  }

  .Assign-Selected {
    position: absolute;
    right: 17px;
    bottom: 15px;
    width: 167px;
  }

  .footer {
    position: sticky;
    bottom: 0;
    z-index: 98;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
    height: 15px;
  }

  /* .padding , .td.name-hd{
    display: none;
} */
  @media only screen and (min-width: 768px) {
    .inner-preamble {
      display: grid;
      grid-template-rows: 1fr;
      grid-template-columns: 3fr 1fr 1fr;
      grid-template-areas: "a b c";
      justify-items: stretch;
      column-gap: 1rem;
      align-items: center;
    }
    .inner-preamble > span {
      max-width: 100%;
    }
  }
  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 100%;
    max-height: 80%;
    overflow: auto;
    transform: translate(-50%, -50%);
    background: #ffffff;
    border-radius: 10px;
    z-index: 99;
    padding-top: 0;
    margin-top: 20px;
  }

  @media only screen and (max-width: 767px) {
    .Assign-Selected {
      position: absolute;
      right: 15px;
      left: 15px;
      width: unset;
    }
    .modal-header {
      font-size: 1.2rem;
    }
    .inner-content {
      padding-bottom: 0;
    }
  }

  @media only screen and (max-width: 767px) {
    .modal {
      max-height: 90%;
    }
  }
  @media only screen and (min-width: 768px) {
    .modal {
      width: 90%;
    }
  }
  @media only screen and (min-width: 1024px) {
    .modal {
      width: 60%;
    }
  }
</style>
