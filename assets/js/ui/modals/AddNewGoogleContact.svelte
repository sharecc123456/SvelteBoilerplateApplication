<script>
  import { createEventDispatcher, onMount } from "svelte";
  import {
    bulkNewRecipient,
    googleListContacts,
  } from "BoilerplateAPI/Recipient";
  import { getCompanyInfo } from "BoilerplateAPI/Features";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Button from "../atomic/Button.svelte";
  import TextField from "../components/TextField.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage.js";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;

  //export let default_selection_list = selection_list;
  let title = "Import Contact from Google";
  export let showSelectionCount = true;

  let googleContacts = [];
  let notEnabled = false;

  onMount(() => {
    googleContacts = googleListContacts();
    getCompanyInfo().then((x) => {
      notEnabled = !x.integrations.some((i) => i.type == "contacts_google");
    });
  });

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }

    if (e.key === "Tab") {
      const nodes = modal.querySelectorAll("*");
      const tabbable = Array.from(nodes).filter((n) => n.tabIndex >= 0);

      let index = tabbable.indexOf(document.activeElement);
      if (index === -1 && e.shiftKey) index = 0;

      index += tabbable.length + (e.shiftKey ? -1 : 1);
      index %= tabbable.length;

      tabbable[index].focus();
      e.preventDefault();
    }
  };

  let search_value;
  let selection_list = [];
  let selectedGoogleContacts = [];
  let selection_count = 0;

  function submitSelection() {
    bulkNewRecipient(selectedGoogleContacts)
      .then((r) => r.json())
      .then((reply) => {
        let { success, failure } = reply;

        showToast(
          `Successfully imported ${success} contacts, failed to import ${failure}.`,
          2000,
          "success",
          "MM"
        );

        close();
      });
  }

  function handleSelectRow(googleContact, event) {
    const { id } = googleContact;
    if (event == "remove") {
      selection_list = selection_list.filter((x) => {
        return x != id;
      });
      selectedGoogleContacts = selectedGoogleContacts.filter((x) => {
        return x.id != id;
      });
      selection_count -= 1;
    } else {
      selection_list = [...selection_list, id];
      selectedGoogleContacts = [...selectedGoogleContacts, googleContact];
      selection_count += 1;
    }
  }
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          {title}
          <span on:click={close}>
            <slot name="closer" />
          </span>
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>
        <div class="inner-preamble">
          <div>
            <TextField
              bind:value={search_value}
              icon="search"
              text="Search Google Contact"
            />
          </div>
          <div on:click={() => selection_count !== 0 && submitSelection()}>
            <Button
              color="secondary"
              disabled={selection_count === 0}
              text={"Add Selection" +
                (showSelectionCount && selection_count > 0
                  ? ` (${selection_count})`
                  : "")}
            />
          </div>
        </div>
        <div class="table">
          <div class="tr th">
            <div class="td toggle" />
            <div class="td name">Name</div>
            <div class="td name">Organization</div>
          </div>
        </div>

        {#if !notEnabled}
          <div class="content">
            {#await googleContacts}
              <p>Loading google contacts...</p>
            {:then contacts}
              <div class="table">
                {#if contacts != null && contacts != undefined && contacts.length > 0}
                  {#each contacts as googleContact}
                    {#if googleContact.email
                      .toLowerCase()
                      .includes(search_value.toLowerCase()) || googleContact.name
                        .toLowerCase()
                        .includes(search_value.toLowerCase())}
                      <div
                        class="tr cursor-pointer"
                        on:click={() => {
                          if (selection_list.includes(googleContact.id)) {
                            handleSelectRow(googleContact, "remove");
                          } else {
                            handleSelectRow(googleContact, "add");
                          }
                        }}
                      >
                        <div class="td toggle">
                          {#if selection_list.includes(googleContact.id)}
                            <span>
                              <FAIcon icon="check-square" />
                            </span>
                          {:else}
                            <span>
                              <FAIcon icon="square" iconStyle="regular" />
                            </span>
                          {/if}
                        </div>
                        <div class="td name">
                          <p>{googleContact.name}</p>
                          <p>{googleContact.email}</p>
                        </div>
                        <div class="td name">
                          <p>
                            {googleContact.organization
                              ? googleContact.organization
                              : "N/A"}
                          </p>
                        </div>
                      </div>
                    {/if}
                  {/each}
                {:else}
                  <p>No google contacts found.</p>
                {/if}
              </div>
            {/await}
          </div>
        {:else}
          <h1>
            This integration is not enabled - please go to your Admin page ->
            Integrations tab to enable it.
          </h1>
        {/if}
      </div>
    </div>
  </div>
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .inner-preamble {
    display: flex;
    align-items: center;
    padding-top: 1rem;
  }

  .inner-preamble > div:first-child {
    flex: 1;
    margin-right: 1rem;
  }

  h1 {
    max-width: 50%;
    font-family: "Nunito", sans-serif;
    font-size: 24px;
  }

  .table {
    padding-top: 1rem;
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    width: 100%;
    position: relative;
  }

  .th {
    display: none;
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
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
  }

  .td.toggle {
    flex-grow: 0;
    flex-basis: 40px;
    width: 40px;
    user-select: none;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    cursor: pointer;
  }

  .td.name {
    flex-grow: 2;
    display: flex;
    flex-flow: column nowrap;
  }

  .td.name > p {
    padding: 0;
    margin: 0;
  }

  .td.name > p:nth-child(1) {
    font-size: 14px;
    line-height: 24px;
    color: #171f46;
  }

  .td.name > p:nth-child(2) {
    font-size: 12px;
    line-height: 24px;
    color: #7e858e;
  }

  .inner-content {
    position: sticky;
    top: 0;
    z-index: 10;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
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
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
  }

  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 60%;
    min-width: fit-content;
    height: 80%;
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 9999;
    padding-top: 0;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-direction: column;
  }

  .modal-x {
    font-size: 24px;
    left: calc(100% - 4em);
    top: 0.85em;

    cursor: pointer;
  }
  .cursor-pointer {
    cursor: pointer;
  }

  @media only screen and (max-width: 767px) {
    .modal {
      width: 100%;
    }
    .modal-header {
      font-size: 1.2rem;
    }
    .inner-preamble {
      flex-direction: column;
      align-items: center;
    }
    .inner-preamble > div:first-child {
      margin-right: 0;
      margin-bottom: 1rem;
    }
    .inner-content {
      padding-bottom: 0rem;
    }
  }
</style>
