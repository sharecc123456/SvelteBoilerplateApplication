<script>
  import { onMount } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { convertTime } from "Helpers/util";
  import { convertUTCToLocalDateString } from "../../helpers/dateUtils";
  import { isNullOrUndefined } from "../../helpers/util";
  export let missing_reason = false;
  export let state;
  export let is_partial = false;
  export let time;
  export let recipient = false;
  export let colorful = false;
  export let reason = null;
  export let info = false;
  export let isMissing = null;
  export let onlyIcon = false;
  export let latest_activity_date;
  export let dueDate = {};
  export let delivery_fault = false;
  export let expiration_info = {};
  export let isExpirationEnabled = false;
  let checklistLevelStatus = false;
  onMount(() => {
    if (
      isNullOrUndefined(state.latest_activity_info) ||
      state.latest_activity_date === {}
    ) {
      return;
    }

    checklistLevelStatus = true;
  });

  const showReasonCheck = state.status === 3 && reason;
  const showMissingCheck =
    (state.status === 5 || state.status === 6) && isMissing;
  export let row;
  function markup_text(st, row) {
    // The Delivery fault can occur at ANY point so having this be
    //  prioritize allows for the status to be saved and show delivery fault
    if (delivery_fault) return "Delivery Fault";
    switch (st.status) {
      case 0:
        return "Open";
      case 1:
        return "In Progress";
      case 2:
        if (row && row.flags === 2) return "Uploaded";
        if (!recipient)
          return `Ready for review ${is_partial ? "(partial)" : ""}`;
        return "Submitted to Requester";
      case 3:
        return showReasonCheck
          ? `Returned for updates (${reason})`
          : "Returned for updates";
      case 4:
        if (st.type && st.type === "manually_added") return "Added manually";
        if (!recipient) return "Completed";
        return info ? "Viewed" : "Completed";
      case 5:
      case 6:
        return missing_reason || `Unavailable (${isMissing})`;
      case 7:
        return "Partially Completed";
      case 9:
        return "Auto Removed";
      case 10:
        return "Manually Removed ";
      case 11:
        return "Contact Removed";
      /* case 4: */
      /*   return "Deleted Automatically"; */
      default:
        return "UNKNOWN";
    }
  }

  function statusToText(status) {
    switch (status) {
      case 0:
        return "Sent";
      case 1:
        return "In Progress";
      case 2:
      case 5:
        return `Submitted`;
      case 3:
        return "Returned";
      case 6:
      case 4:
        return state.status === 4 ? "Completed" : "Submitted";
      case 9:
        return "Auto Removed";
      case 10:
        return "Manual Removed ";
      case 11:
        return "Contact Removed";
      default:
        return "";
    }
  }

  function recipientStatusToText(status) {
    switch (status) {
      case 0:
        return "Assigned";
      default:
        return statusToText(status);
    }
  }

  function getRecipientStatusText(status) {
    const statusText = recipientStatusToText(status);
    return statusText === "" ? statusText : `${statusText}:`;
  }

  function markup_icon(st, row) {
    if (delivery_fault) return "exclamation-triangle";
    switch (st.status) {
      case 0:
        return "circle";
      case 1:
        return "adjust";
      case 2:
        if (row && row.flags === 2) return "cloud-upload";
        if (recipient) return "check-circle";
        return "exclamation-circle";
      case 3:
        return "undo";
      case 4:
        return "check-circle";
      case 5:
      case 6:
        return "xmark";
      case 7:
        return "adjust";
      case 9:
        return "recycle";
      case 10:
      case 11:
        return "trash";
      default:
        return "circle";
    }
  }

  function markup_icon_style(st) {
    if (delivery_fault) return "regular";
    switch (st.status) {
      case 2:
        if (!recipient) return "regular";
        return "solid";
      case 4:
        return "solid";
      case 5:
      case 6:
        return "solid";
      case 7:
        return "regular";
      case 9:
        return "solid";
      case 10:
      case 11:
        return "solid";
      default:
        return "regular";
    }
  }

  function markup_date(st, key = "date") {
    if (delivery_fault) return "";
    if (st[key] == "") {
      return "";
    }
    if (st[key]) {
      return `${st[key].split(" ")[0]} ${
        time !== undefined ? convertTime(st[key]?.split(" ")[0], time) : ""
      }`;
    }
  }
</script>

<div class="state">
  <div class="status">
    <span class="icon">
      {#key state}
        <FAIcon
          icon={markup_icon(state, row)}
          iconStyle={markup_icon_style(state)}
          iconSize="small"
        />
      {/key}
    </span>
    {#if !onlyIcon}
      <p class:colorful-upload={colorful && state.status == 1}>
        {#if row && row.flags === 2 && (state.status == 2 || state.status == 4)}
          File
        {/if}
        <span>
          {markup_text(state, row)}
          {#if recipient}
            {#if Object.keys(dueDate).length !== 0}
              <span>- Due {convertUTCToLocalDateString(dueDate.date)}</span>
            {/if}

            {#if (state.status == 2 || state.status == 4) && isExpirationEnabled}
              <span style="display: block;"
                >Expiration: {expiration_info.value || "Not set"}</span
              >
            {/if}
          {/if}
        </span>
      </p>
    {/if}
  </div>
  <div class="date">
    <p>
      {#if delivery_fault}
        <span />
      {:else if checklistLevelStatus}
        <span>
          {#if recipient}
            {`${getRecipientStatusText(
              state.latest_activity_info.status
            )} ${markup_date(state.latest_activity_info, "date_time_data")}`}
          {:else}
            {markup_date(state.latest_activity_info, "date_time_data")}
            [{state.status == 9 || state.status == 10
              ? "Deleted"
              : statusToText(state.latest_activity_info.status)}]
          {/if}
        </span>
      {:else if state.date != ""}
        <span>
          {#if recipient}
            {`${getRecipientStatusText(state.status)} ${markup_date(
              state,
              state?.date_time_data ? "date_time_data" : "date"
            )}`}
          {:else}
            {state.status == 9 || state.status == 10
              ? "Deleted"
              : delivery_fault == true
              ? ""
              : "Sent:"}
            {markup_date(state)}
            [{state.status == 9 || state.status == 10
              ? "Deleted"
              : statusToText(state.status)}]
          {/if}
        </span>
      {/if}
    </p>
    <p>
      {latest_activity_date != undefined ? latest_activity_date : ""}
    </p>
  </div>
</div>

<style>
  /* State column */
  .state {
    display: flex;
    flex-flow: column nowrap;
  }

  .state > .status {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .state > .status > p {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    margin: 0;
    color: var(--text-dark);
  }

  .state > .status > .icon {
    padding-right: 0.5em;
  }

  .state > .date > p {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 21px;
    letter-spacing: 0.1px;
    margin: 0;
  }
  .date {
    margin-left: 24px;
    display: flex;
    flex-direction: column;
  }
</style>
