<script>
  import Modal from "Components/Modal.svelte";
  import TextField from "Components/TextField.svelte";
  import ClickButton from "../../../atomic/ClickButton.svelte";
  import { returnReviewItem } from "BoilerplateAPI/Review";

  export let requestId = null;
  export let closeModal = () => {};
  export let checklistId = null;
  export let reviewType = "request";
  export let maxWidth = null;
  export let modaltitle = "Return reason";
  export let placeholderText = "Return comment for Contact";
  export let customButtonText = "Send Return";
  let returnReason = "";

  export let doReturnIt = (comment) => {
    closeModal();
    returnReviewItem({ id: requestId }, reviewType, comment).then(() => {
      if (checklistId) window.location.hash = `#review/${checklistId}`;
      else window.location.reload();
    });
  };
</script>

<Modal {maxWidth} on:close={closeModal}>
  <div slot="header">
    <h4 style="margin: 0;line-height: 17px;font-weight: normal;">
      {modaltitle}
    </h4>
    <small style="font-size: 14px; font-weight: normal;"
      >The submitter will notified via email</small
    >
  </div>

  <div
    on:keyup={(evt) => {
      if (returnReason.trim() != "" && evt.code == "Enter") {
        doReturnIt(returnReason);
      }
    }}
    class="return-modal"
  >
    <TextField bind:value={returnReason} text={placeholderText} />
    <div class="buttons">
      <span>
        <ClickButton on:click={closeModal} color="gray" text="Cancel" />
      </span>
      <span>
        <ClickButton
          disabled={returnReason.trim() == ""}
          color="primary"
          on:click={() => doReturnIt(returnReason)}
          text={customButtonText}
        />
      </span>
    </div>
  </div>
</Modal>

<style>
  .return-modal {
    padding-top: 0.2rem;
  }

  .return-modal > .buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    padding-top: 1rem;
  }
</style>
