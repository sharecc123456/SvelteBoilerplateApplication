import { writable } from "svelte/store";
import { toastLocation } from "../ui/atomic/ToastBar.svelte";

export const isToastVisible = writable(false);
export const toastMessage = writable("");
export const toastColor = writable("#2A2F34");

export const bStyle = writable("none");
export const bWidth = writable("none");
export const bColor = writable("none");
export const tColor = writable("white");

export const showToast = (message, duration, objType, objLocation) => {
  toastLocation(objLocation, message, objType);
  if (objType == "success") {
    if (duration > 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#16A086");
      bStyle.set("none");
      bWidth.set("none");
      bColor.set("none");
      tColor.set("white");
      setTimeout(hideToast, duration);
    } else if (duration == 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#16A086");
      bStyle.set("none");
      bWidth.set("none");
      bColor.set("none");
      tColor.set("white");
    }
  } else if (objType == "error") {
    if (duration > 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#DB5244");
      bStyle.set("none");
      bWidth.set("none");
      bColor.set("none");
      tColor.set("white");
      setTimeout(hideToast, duration);
    } else if (duration == 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#DB5244");
      bStyle.set("none");
      bWidth.set("none");
      bColor.set("none");
      tColor.set("white");
    }
  } else if (objType == "default") {
    if (duration > 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#4a5157");
      bStyle.set("none");
      bWidth.set("none");
      bColor.set("none");
      tColor.set("white");
      setTimeout(hideToast, duration);
    } else if (duration == 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#4a5157");
      bStyle.set("none");
      bWidth.set("none");
      bColor.set("none");
      tColor.set("white");
    }
  } else if (objType == "white") {
    if (duration > 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#FFFFFF");
      bStyle.set("solid");
      bWidth.set("2px");
      bColor.set("rgb(0 115 252)");
      tColor.set("black");
      setTimeout(hideToast, duration);
    } else if (duration == 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#FFFFFF");
      bStyle.set("solid");
      bWidth.set("2px");
      bColor.set("rgb(0 115 252)");
      tColor.set("black");
    }
  } else if (objType == "warning") {
    if (duration > 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#FFFFFF");
      bStyle.set("solid");
      bWidth.set("2px");
      bColor.set("rgb(208 52 44)");
      tColor.set("rgb(208 52 44)");
      setTimeout(hideToast, duration);
    } else if (duration == 0) {
      toastMessage.set(message);
      isToastVisible.set(true);
      toastColor.set("#FFFFFF");
      bStyle.set("solid");
      bWidth.set("2px");
      bColor.set("rgb(208 52 44)");
      tColor.set("rgb(208 52 44)");
    }
  }
};

export const hideToast = () => {
  isToastVisible.set(false);
  setTimeout(() => {
    toastMessage.set("");
  }, 100);
};
