<script>
  import { createEventDispatcher } from "svelte";
  import Button from "../../atomic/Button.svelte";
  import ConfirmationDialog from "../ConfirmationDialog.svelte";
  import EmailFaultDialog from "../EmailFaultDialog.svelte";
  import { getDocumentCompletion } from "../../../api/RecipientPortal";
  import { getXdaysFrom } from "../../../helpers/dateUtils";
  import NotificationMobileView from "./NotificationMobileView.svelte";

  const dispatch = createEventDispatcher();

  export let handleExpiredDocument = false;
  export let deliveryfaultData;
  export let handleDeliveryFault = false;
  export let notification = {};
  export let actionButtonTypes = {};
</script>

<span
  class:outer-border-unread={!notification["read"]}
  class="outer-border desktop-only"
>
  <div
    class="notifications-tr"
    class:row-unread-color={!notification["read"]}
    on:click={() => {
      dispatch("notificationClick", notification);
    }}
  >
    <div class="notifications-td checkbox">
      <div
        class="cross bolder-icon"
        on:click|stopPropagation={() => {
          dispatch("removeNotification", notification);
        }}
      >
        <i class="fas fa-times-circle" />
      </div>
    </div>
    <div class="notifications-td clickable flex-grow">
      <span class:is-unread={!notification["read"]} style="white-space: nowrap"
        >{getXdaysFrom(notification["inserted_at"])}</span
      >
    </div>

    <div class="notifications-td type flex-grow">
      <span class:is-unread={!notification["read"]} style="white-space: nowrap"
        >{notification["title"]}</span
      >
    </div>

    <div class="notifications-td description">
      <span class:is-unread={!notification["read"]}
        >{notification["message"]}</span
      >
    </div>
    <div class="notifications-td actions with-ellipsis w-full">
      <span
        on:click={() => {
          dispatch("notificationActions", notification);
        }}
        class="btn w-full"
      >
        <Button {...actionButtonTypes[notification["type"]]} />
      </span>
    </div>
  </div>
</span>

<span class="mobile-only">
  <NotificationMobileView
    {notification}
    {getXdaysFrom}
    {actionButtonTypes}
    on:notificationClick
    on:notificationActions
    on:removeNotification
  />
</span>

{#if handleExpiredDocument}
  {#await getDocumentCompletion(2, notification.assignmentId, notification.document_id) then { name, description }}
    <ConfirmationDialog
      title="The document has expired. What would you like to do next?"
      itemDisplay={{ name, description }}
      yesText="Resend for Upload"
      yesColor="primary"
      noColor="white"
      noText="Cancel"
      popUp={false}
      on:close={() => {
        handleExpiredDocument = false;
      }}
      on:yes={() => {
        const { document_id } = notification;
        dispatch("returnExpiredDoc", document_id);
      }}
    />
  {/await}
{/if}
{#if handleDeliveryFault}
  <EmailFaultDialog
    email={deliveryfaultData.email}
    user_name={deliveryfaultData.name}
    company={deliveryfaultData.company}
    recipient_id={deliveryfaultData.recipient_id}
    on:close={() => {
      handleDeliveryFault = false;
    }}
  />
{/if}

<style>
  * {
    box-sizing: border-box;
  }

  .row-unread-color {
    background-color: #eef3f8 !important;
  }

  .is-unread {
    color: #000;
    font-weight: bolder;
  }

  .notifications-tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    position: relative;
    cursor: pointer;
  }

  .flex-grow {
    flex-grow: 2;
  }

  .notifications-tr:not(.notifications-th) {
    display: grid;
    grid-template-columns: 0.5fr 0.5fr 1.75fr 0.5fr;
    grid-template-areas: "a d b c";
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #2a2f34;
    padding: 0.5rem 0;
    position: relative;
  }

  .notifications-tr:not(.notifications-th) .checkbox {
    grid-area: e;
    justify-self: center;
  }

  .notifications-tr .cross {
    position: absolute;
    top: -12px;
    right: -5px;
    z-index: 11;
    color: #db5244;
    display: none;
  }
  .w-full {
    width: 100%;
  }

  .notifications-tr:hover .cross {
    display: block;
  }

  .bolder-icon {
    font-size: larger;
    font-weight: bolder;
  }

  .notifications-tr:not(.notifications-th) .clickable {
    grid-area: a;
    justify-content: center;
  }

  .notifications-tr:not(.notifications-th) .type {
    grid-area: d;
    justify-content: center;
  }

  .notifications-tr:not(.notifications-th) .description {
    grid-area: b;
    justify-content: center;
  }

  .notifications-tr:not(.notifications-th) .actions {
    grid-area: c;
    justify-self: center;
    padding: 0.5rem;
  }

  .notifications-tr:not(.notifications-th) .actions span {
    width: 100%;
  }

  .outer-border {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    margin-bottom: 1em;
  }

  .outer-border-unread {
    border: 3px solid #b3c1d0;
  }

  .notifications-td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
    color: #7e858e;
  }

  .notifications-td.actions {
    flex-grow: 1;
    justify-content: center;
    align-items: center;
    /* padding-right: 2rem; */
    padding-right: 0.5rem;
  }

  .with-ellipsis {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .clickable {
    cursor: pointer;
  }

  .notifications-tr .btn {
    display: flex;
  }

  .actions {
    padding-right: 3rem;
  }
  .mobile-only {
    display: none;
  }
  @media only screen and (max-width: 968px) {
    .notifications-tr:not(.notifications-th) {
      grid-template-columns: 0.5fr 0.5fr 1.75fr 0.7fr;
    }
  }
  @media only screen and (max-width: 767px) {
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
  }
</style>
