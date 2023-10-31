<script>
  import { onMount } from "svelte";

  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import {
    getNotifications,
    markNotificationRead,
    getNotificationDetails,
    markNotificationArchive,
  } from "../../../api/notifications";
  import { returnExpiredItem } from "BoilerplateAPI/FileRequest";
  import EmptyDefault from "../../util/EmptyDefault.svelte";
  import Loader from "../../components/Loader.svelte";
  import NotificationRow from "../../components/NotificationsHelpers/NotificationRow.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import {
    has_unread_notification,
    count_unread_notification,
  } from "./../../../store";

  let deliveryfaultData;
  const EXPIREDDOCUMENTRETURNTEXT = "Expired";

  let loadingState = true;
  let notifications = [];
  let handleExpiredDocument = false;
  let handleDeliveryFault = false;

  const actionButtonTypes = {
    expired: {
      type: "expired",
      text: "View Details",
      icon: "",
      color: "white",
    },
    expiring: {
      type: "expiring",
      text: "View Doc",
      icon: "",
      color: "white",
    },
    internal: {
      type: "internal",
      text: "Dismiss",
      icon: "",
      color: "white",
    },
    delivery_fault: {
      type: "delivery_fault",
      text: "Learn More",
      color: "white",
    },
  };

  onMount(() => {
    getNotifications().then((x) => {
      notifications = x || [];
      loadingState = false;
    });
  });

  const handleNotificationActions = (e) => {
    let notification = e.detail;
    const {
      type: actionType,
      document_id: completionId,
      assignment_id: assignmentId,
    } = notification;

    switch (actionType) {
      case "expired":
        handleExpiredDocument = true;
        break;
      case "internal":
        handleNotificationRemove(e);
        break;
      case "expiring":
        window.open(
          `#submission/view/2/${assignmentId}/${completionId}?newTab=true`,
          "_blank"
        );
        break;
      default:
        break;
    }
  };

  const handleNotificationClick = async (e) => {
    let row = e.detail;
    if (row.type == "delivery_fault") {
      const reply = await getNotificationDetails(row.id);
      if (reply.ok) {
        reply.json().then((data) => {
          deliveryfaultData = data;
          handleDeliveryFault = true;
        });
        return;
      }
    }
    const reply = await markNotificationRead(row.id);
    if (reply.ok) {
      const up = notifications.map((x) => {
        if (x["id"] === row["id"]) {
          x["read"] = true;
        }
        return x;
      });
      notifications = [...up];

      let unread_notifications = notifications.filter(
        (x) => x["read"] === false
      );

      $has_unread_notification = unread_notifications.length || false;
      $count_unread_notification = unread_notifications.length;
    }
  };

  const handleNotificationRemove = async (e) => {
    let row = e.detail;
    const reply = await markNotificationArchive(row.id);
    if (reply.ok) {
      const up = notifications.filter((x) => x["id"] !== row["id"]);
      notifications = [...up];
    }
  };

  const returnExpiredDoc = async (e) => {
    let requestId = e.detail;
    let type = "request",
      comment = EXPIREDDOCUMENTRETURNTEXT;

    const reply = await returnExpiredItem(requestId, type, comment);
    if (reply.ok) {
      showToast(`File send back to recipient`, 3000, "default", "MM");
    } else {
      showToast(
        `Error! Somthing went wrong. Please try again later`,
        3000,
        "default",
        "MM"
      );
    }
    handleExpiredDocument = false;
  };
</script>

<div class="page-header">
  <RequestorHeaderNew title="Alerts" icon="bell" enable_search_bar={false} />
  {#if loadingState}
    <Loader loadingState />
  {:else if notifications.length == 0}
    <EmptyDefault
      defaultHeader="No Alerts"
      defaultMessage="Seems like there are no alerts for you to view, check back later!"
    />
  {:else}
    <section class="notifications-main">
      <div class="notifications-table">
        <div class="notifications-tr notifications-th">
          <div class="notifications-td" style="flex-grow: 2;">Date</div>
          <div class="notifications-td type">Title</div>
          <div class="notifications-td description" style="flex-grow: 2;">
            Description
          </div>
          <div class="notifications-td actions actions-hd" />
        </div>
        {#each notifications as notification (notification.id)}
          <NotificationRow
            {notification}
            {actionButtonTypes}
            bind:handleExpiredDocument
            bind:handleDeliveryFault
            bind:deliveryfaultData
            on:removeNotification={handleNotificationRemove}
            on:notificationClick={handleNotificationClick}
            on:notificationActions={handleNotificationActions}
            on:returnExpiredDoc={returnExpiredDoc}
          />
        {/each}
      </div>
    </section>
  {/if}
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  * {
    box-sizing: border-box;
  }
  .page-header {
    position: sticky;
    top: 10px;
    z-index: 12;
    background: #fcfdff;
  }

  .notifications-main {
    width: calc(100% - 2rem);
    margin: auto;
  }

  /* contents */
  .notifications-table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 1rem auto;
    padding-top: 0.5rem;
  }

  .notifications-th > .notifications-td {
    white-space: normal;
    justify-content: left;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    align-self: center;
    height: 37px;
    align-items: center;
  }
  .notifications-th .notifications-td {
    color: #76808b;
  }
  .notifications-tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    position: relative;
  }

  .notifications-tr:not(.notifications-th) {
    /* height: 60px; */
    display: grid;
    row-gap: 0.3rem;
    grid-template-columns: 20px 1fr 1fr;

    grid-template-areas:
      "a b b"
      ". e e"
      ". f f"
      ". g g";
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #2a2f34;
    padding: 0.5rem;
    position: relative;
  }

  .notifications-tr:not(.notifications-th) .type {
    grid-area: d;
  }

  .notifications-tr:not(.notifications-th) .description {
    grid-area: b;
    justify-content: center;
  }

  .notifications-tr:not(.notifications-th) .actions {
    grid-area: c;
    justify-self: center;
    /* width: 100%; */
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

  .notifications-tr:not(.notifications-th) {
    row-gap: 0.5rem;
    grid-template-columns: 0.5fr 1.75fr 0.5fr;
    grid-template-areas: "a d b c";
    padding-right: 0px;
    padding-left: 0px;
    /* padding: 1rem; */
  }

  .notifications-tr.notifications-th {
    display: grid;
    grid-template-columns: 0.5fr 0.5fr 1.75fr 0.5fr;
    justify-items: center;
    position: sticky;
    top: 0;
    height: 60px;
    z-index: 10;
    background: #f8fafd;
  }

  .notifications-tr .actions {
    justify-self: center;
  }
  .notifications-tr:not(.notifications-th) .actions {
    padding: 0.5rem;
  }

  @media only screen and (max-width: 767px) {
    .notifications-tr.notifications-th {
      display: none;
    }

    .notifications-main {
      width: 100%;
    }
  }
</style>
