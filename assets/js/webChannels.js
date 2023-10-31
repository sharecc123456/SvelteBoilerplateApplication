import { Presence } from "phoenix";

import socket from "./socket";
import {
  isRecipientInFillMode,
  isRequestorInEditMode,
  isRequestorInReviewMode,
} from "./store";

const MAXUNIQUEUSERS = 2;
const FILLCHANNELTOPIC = "iac_fill";

const listBy = (id, { metas: [first, ...rest] }) => {
  return first;
};

const setStoreValues = (userType) => {
  switch (userType) {
    case "requestor":
      isRecipientInFillMode.set(false);
      isRequestorInEditMode.set(true);
      break;
    case "recipient":
      isRecipientInFillMode.set(true);
      // recipient associated to requestor update and requestor review
      // requestor <---> recipient <----> review
      isRequestorInEditMode.set(false);
      isRequestorInReviewMode.set(false);
      break;
    case "review":
      isRecipientInFillMode.set(false);
      isRequestorInReviewMode.set(true);
    default:
      break;
  }
};

const setRequestorStates = (userType) => {
  switch (userType) {
    case "requestor":
      isRequestorInEditMode.set(true);
      // reset field
      isRequestorInReviewMode.set(false);
      break;
    case "review":
      isRequestorInReviewMode.set(true);
      // reset field
      isRequestorInEditMode.set(false);
      break;
    default:
      isRequestorInEditMode.set(false);
      isRequestorInReviewMode.set(false);
      break;
  }
};

const syncPresentUsers = (presences) => {
  const pList = Presence.list(presences, listBy).map((presence) => {
    const { user_type: userType } = presence;
    return userType;
  });

  /** TODO: yaakies... uglies! could not figure out how to trigger state change in svelte */
  if (pList.length === MAXUNIQUEUSERS) {
    isRecipientInFillMode.set(true);
    const userType = pList.filter((_userType) => _userType !== "recipient");
    setRequestorStates(userType[0]);
  } else if (pList === []) {
    isRecipientInFillMode.set(false);
    isRequestorInEditMode.set(false);
  } else {
    setStoreValues(pList[0]);
  }
};

export const getIACFillChannel = (customizationId, params) => {
  let channel = socket.channel(
    `${FILLCHANNELTOPIC}:${customizationId}`,
    params
  );

  let presences = {};
  channel.on("presence_diff", (diff) => {
    presences = Presence.syncDiff(presences, diff);
    syncPresentUsers(presences);
  });

  channel.on("presence_state", (response) => {
    presences = Presence.syncState(presences, response);
    syncPresentUsers(presences);
  });

  channel
    .join()
    .receive("ok", (resp) => {
      console.log(`joined channel ${customizationId}`, resp);
    })
    .receive("error", (resp) => {
      console.error(`unable to join ${customizationId} channel`, resp);
    });

  return channel;
};
