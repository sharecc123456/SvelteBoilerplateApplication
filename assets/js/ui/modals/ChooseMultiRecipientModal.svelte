<script>
  import { createEventDispatcher, onDestroy, onMount } from "svelte";
  import Button from "../atomic/Button.svelte";
  import TextField from "../components/TextField.svelte";
  import Loader from "../components/Loader.svelte";
  import ListRecipient from "../modals/ListRecipient.svelte";
  import { getRecipients } from "BoilerplateAPI/Recipient";
  import { assignContents } from "BoilerplateAPI/Assignment";
  import { showToast } from "Helpers/ToastStorage";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  onMount(async () => {
    recipients = await getRecipients();
    loading = false;
  });

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }
  };

  let modal;
  let recipients = [];
  let loading = true;
  let search_value;
  let multi_selected = [];
  let value;
  export let checklistId = undefined;

  const handleSubmitChecklist = async () => {
    let promises = [];
    multi_selected.forEach((rec) => {
      let contentsPromise = loadContents(rec.id, checklistId);
      promises = [...promises, contentsPromise];
    });
    await Promise.all(promises)
      .then((promises) => {
        promises.forEach(async (promise, i) => {
          let reply = await assignContents(promise);
          if (reply.ok) {
            setTimeout(() => {
              window.location.reload();
              window.location.hash = "#dashboard";
            }, 2000);
            //window.location.reload();
            showToast(
              `Success! Checklist sent. The other party will receive a link in an email to complete the checklist. If you need to unsend or delete this request, go to the dashboard, find the request, then click the unsend button on the hamburger menu on the right.`,
              3000,
              "white",
              "MM"
            );
          }
        });
      })
      .catch((error) => alert("Something wrong: ", error.message));
  };

  const loadContents = async (recipientId, checklistId) => {
    return getContents(recipientId, checklistId).then(async (c) => {
      return c;
    });
  };

  const getContents = async (recipientId, checklistId) => {
    let request = await fetch(
      `/n/api/v1/contents/${recipientId}/${checklistId}`
    );
    if (request.ok) {
      // If the request was OK, then a contents was found.
      let assignments = await request.json();
      console.log("Found existing contents");
      console.log(assignments);
      return assignments;
    } else if (request.status == 404) {
      // No existing valid Contents was found, ask the API to create one for us.
      let request = await fetch("/n/api/v1/contents", {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          recipientId: recipientId,
          packageId: checklistId,
        }),
      });
      if (request.ok) {
        let new_contents = await request.json();
        console.log("Made new contents");
        console.log(new_contents);
        return new_contents;
      } else {
        alert("Failed to create a new Contents object for this assignment");
      }
    } else {
      alert("A fatal, unexpected error occured while fetching Contents");
    }
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          Add or select contacts to assign
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
              icon="search"
              text="Add Email or Search Contacts"
              width="100%"
            />
          </span>
        </div>
        <span style="font-weight: bold; color: #76808B">
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
            {search_value}
            isMultipleCheck={true}
            on:selectedMultiRecipients={(event) => {
              value = event.detail.multi_selected;
              multi_selected = value;

              console.log(multi_selected);
            }}
            {multi_selected}
          />
        {/if}
      </div>
    </div>
    <div class="footer">
      <span class="Assign-Selected" on:click={() => handleSubmitChecklist()}>
        <Button
          color="secondary"
          text="Select and Next"
          disabled={multi_selected.length <= 1}
        />
      </span>
    </div>
  </div>
</div>

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
    padding-bottom: 2rem;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 98;
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

  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 60%;
    min-width: fit-content;
    height: 80%;
    overflow: scroll;
    transform: translate(-50%, -50%);
    /* padding: 1em; */
    background: #ffffff;
    border-radius: 10px;
    z-index: 99;
    padding-top: 0;
    margin-top: 20px;
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
  @media only screen and (min-width: 780px) {
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

  @media only screen and (max-width: 767px) {
    .modal {
      width: 80%;
    }
    .Assign-Selected {
      position: absolute;
      right: 15px;
      left: 15px;
      width: unset;
    }
  }
</style>
