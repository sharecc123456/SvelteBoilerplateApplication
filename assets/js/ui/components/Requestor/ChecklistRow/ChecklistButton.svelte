<script>
  import Button from "Atomic/Button.svelte";

  export let archived = false;
  export let checklist = {};
  export let recipient = {};
  const state = checklist?.state?.status;
  export let tryRemindNow = (id1, id2, lastReminder) => {};
  export let toggleChevron = (id) => {};
  export let handleDeliveryFaultPopup = (recipient) => {};

  let buttonText = (state) => {
    // Delivery Fault can occur at ANY state
    if (checklist.state.delivery_fault) return "Resolve";
    if (archived) return "View";
    switch (state) {
      case 0:
      case 1:
      case 3:
        return "Remind";
      case 2:
        return "Review";
      case 4:
      case 7: // TODO: change state to 8 when user conversation ticket is merged
      case 9:
      case 10:
        return "View";
      default:
        return "_BUG_";
    }
  };
  let buttonColor = (state) => {
    if (checklist.state.delivery_fault) return "danger";
    if (archived) return "gray";
    switch (state) {
      case 0:
      case 1:
      case 3:
        return "white";
      case 4:
      case 7: // TODO: change state to 8 when user conversation ticket is merged
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
    if (archived) {
      toggleChevron(checklist.id);
      return;
    }
    switch (state) {
      case 0:
      case 1:
      case 3:
        tryRemindNow(checklist.id, recipient.id, checklist.last_reminder_info);
        break;
      case 2:
        window.location.hash = `#review/${checklist.contents_id}`;
        break;
      case 4:
        toggleChevron(checklist.id);
        break;
      case 7:
      case 9:
      case 10:
        toggleChevron(checklist.id);
        break;
      default:
        break;
    }
  };
</script>

<div
  on:click|stopPropagation={() => {
    buttonAction(state);
  }}
>
  <Button text={buttonText(state)} color={buttonColor(state)} />
</div>

<style>
  div {
    width: 75%;
  }
</style>
