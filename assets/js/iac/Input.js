/* IAC Input normalizers  */
import { isAndroidMobile } from "Helpers/util";

// Figure out if the current browser supports InputEvents
export const IS_INPUT_SUPPORTED = (function () {
  try {
    // just kill browsers off, that throw an error if they don't know
    // `InputEvent`
    const event = new InputEvent("input", {
      data: "xyz",
      inputType: "deleteContentForward",
    });
    let support = false;

    // catch the others
    // https://github.com/chromium/chromium/blob/c029168ba251a240b0ec91fa3b4af4214fbbe9ab/third_party/blink/renderer/core/events/input_event.cc#L78-L82
    const el = document.createElement("input");
    el.addEventListener("input", function (e) {
      if (e.inputType === "deleteContentForward") {
        support = true;
      }
    });

    el.dispatchEvent(event);
    return support;
  } catch (error) {
    return false;
  }
})();

/* Given an InputEvent or KeyboardEvent, marshall it into an IACInputEvent  */
export const marshallInputevent = function (event) {
  const e = {
    originalEvent: event,
  };

  if (event instanceof KeyboardEvent) {
    if (event.key === "Backspace") {
      e.inputType = "deleteContentBackward";
      e.data = "deleteContentBackward";
      // e.navigationType = "cursorLeft";
    } else if (event.key === "Delete") {
      e.inputType = "deleteContentForward";
    } else if (event.key.startsWith("Arrow")) {
      e.navigationType = event.key.replace("Arrow", "cursor");
    } else {
      e.data = event.key;
      e.shiftKey = event.shiftKey;
      e.inputType = "insertText";
    }
  } else {
    const { inputType } = event;
    e.inputType = inputType;
    if (
      event.data != undefined &&
      event.data != null &&
      event.data != "deleteContentForward" &&
      event.data != "deleteContentBackward"
    ) {
      e.data = event.data.charAt(event.data.length - 1);
    } else {
      e.data = event.data;
    }

    if (inputType === "deleteContentBackward") {
      e.data = "deleteContentBackward";
    }

    if (inputType === "insertText") {
      // e.navigationType = "cursorRight";
    }

    /* Store the originalData so that downstream users can still access it if
     * need-be for extra marshalling
     */
    e.originalData = event.data;
  }

  return e;
};

function supportedAndroidKeyEvent(evt) {
  if (evt.key == "Backspace") return true;

  return false;
}

export const transformKeydownEvent = function (evt, hook) {
  const e = marshallInputevent(evt);

  console.log("transformKeydownEvent: evt.key = '%s'", evt.key);

  if (
    (!isAndroidMobile() || supportedAndroidKeyEvent(evt)) &&
    (!IS_INPUT_SUPPORTED || evt.key.length >= 1)
  ) {
    hook(e);
  } else {
    console.log("transformKeydownEvent: dropped");
  }
};

export const transformInputEvent = function (evt, hook) {
  if (IS_INPUT_SUPPORTED) {
    hook(marshallInputevent(evt));
  }
};
