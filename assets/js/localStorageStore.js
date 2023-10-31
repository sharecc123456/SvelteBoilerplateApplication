//Samelessly copied from https://gist.github.com/joshnuss/aa3539daf7ca412202b4c10d543bc077

import { writable, get } from "svelte/store";

// wraps a regular writable store
function __writable__(key, initialValue) {
  // create an underlying store
  const store = writable(initialValue);
  const { subscribe, set } = store;
  // get the last value from localStorage
  const json = localStorage.getItem(key);

  // use the value from localStorage if it exists
  if (json) {
    set(JSON.parse(json));
  }

  // return an object with the same interface as svelte's writable()
  return {
    // capture set and write to localStorage
    set(value) {
      localStorage.setItem(key, JSON.stringify(value));
      set(value);
    },
    // capture updates and write to localStore
    update(cb) {
      const value = cb(get(store));
      this.set(value);
    },
    // punt subscriptions to underlying store
    subscribe,
  };
}

// Initailize store
const assignedChecklistInfo = __writable__("assignedChecklistInfo", {
  assigneeId: "",
  contentsId: -1,
  recipientId: -1,
});

export default assignedChecklistInfo;
