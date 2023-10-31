<script>
  import Button from "Atomic/Button.svelte";

  export let archived = false;
  export let file = {};
  export let checklist = {};
  export let recipient = {};
  const state = file?.state?.status;
  export let tryRemindNow = (id1, id2, _) => {};
  export let handleDeliveryFaultPopup = (recipient) => {};
  export let handleItemPopup = (file) => {};
  let buttonText = (state) => {
    // Delivery Fault can occur at ANY state
    if (checklist.state.delivery_fault) return "Resolve";
    switch (state) {
      case 0:
      case 1:
      case 3:
        return "Remind";
      case 2:
      case 5:
        return "Review";
      case 4:
      case 6:
      case 9:
      case 10:
        return "View";
      default:
        return "_BUG_";
    }
  };
  let buttonColor = (state) => {
    if (checklist.state.delivery_fault) return "danger";
    switch (state) {
      case 0:
      case 1:
      case 3:
        return "white";
      case 4:
      case 9:
      case 10:
        return "gray";
      default:
        return "primary";
    }
  };

  let buttonAction = (state) => {
    if (checklist.state.delivery_fault)
      return handleDeliveryFaultPopup(recipient);
    switch (state) {
      case 0:
      case 1:
      case 3:
        tryRemindNow(checklist.id, recipient.id, checklist.last_reminder_info);
        break;
      case 2:
      case 5:
        if (location.hash.startsWith("#recipient")) {
          if (archived)
            localStorage.setItem("docTabActiveArchive", checklist.id);
          else localStorage.setItem("docTabActiveChecklist", checklist.id);
        }
        window.location.hash = `#review/${checklist.contents_id}`;
        break;
      case 4:
        if (file.type == "data") {
          handleItemPopup(file);
        } else {
          if (location.hash.startsWith("#recipient")) {
            if (archived)
              localStorage.setItem("docTabActiveArchive", checklist.id);
            else localStorage.setItem("docTabActiveChecklist", checklist.id);
          }
          window.location.hash = `#submission/view/2/${checklist.id}/${file.completion_id}`;
        }
        break;
      default:
        break;
    }
  };

  const buttonDisabled = (state) => {
    switch (state) {
      case 9:
      case 10:
        return true;
      default:
        return false;
    }
  };
</script>

{#if (archived && state === 4) || !archived}
  <div
    on:click|stopPropagation={() => {
      buttonAction(state);
    }}
  >
    <Button
      text={buttonText(state)}
      color={buttonColor(state)}
      disabled={buttonDisabled(state)}
    />
  </div>
{:else}
  <!-- place holder for button to fix design issue -->
  <div />
{/if}

<style>
  div {
    width: 75%;
  }
</style>
