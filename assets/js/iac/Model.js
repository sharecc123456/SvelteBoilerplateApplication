/*
 * In-App Completion: Model
 *
 *
 * Collects the field level information from the API and creates a
 * JS object that describes the form.
 */

import {
  iacDrawFieldTypeInto,
  iacDrawBaseHighlight,
  iacDrawTable,
  iacInitFieldDescriptor,
  iacRedrawField,
  iacHightlightField,
  iacUnhightlightAll,
  iacDrawBaseBorderHighlight,
  iacRender,
  iacDrawBordersAroundFields,
  _iacAddCanvasHook,
  _iacAddWindowHook,
  _iacResetCanvasHooks,
  iacDrawCheckbox,
} from "IAC/Render";
import { iacAssert } from "IAC/Assert";
import { iacDebug } from "Helpers/Debug";
import { isAndroidMobile } from "Helpers/util";
import { showErrorMessage } from "Helpers/Error";
import {
  iacAddField,
  iacRemoveField,
  iacUpdateField,
  iacSendEsignConsent,
  iacApplySignature,
} from "BoilerplateAPI/IAC";
import EsignConsentModal from "../ui/modals/EsignConsentModal.svelte";
import SignatureInputModal from "../ui/modals/SignatureInputModal.svelte";
import { storeSignatureFields, inputBoxClicked } from "../store";
import { iacLoadingState } from "./../stores/iacStore";

const FIELD_TYPE_CHECKBOX = 2;

const FILL_TYPE_ANYONE = 0;
const FILL_TYPE_REQUESTOR_BEFORE = 1;
const FILL_TYPE_REQUESTOR_AFTER = 2;
const FILL_TYPE_RECIPIENT = 3;

const MODE_UNKNOWN = 0;
const MODE_DISPLAY = MODE_UNKNOWN;
const MODE_SETUP = 1;
const MODE_REQUESTOR_FILL = 2;
const MODE_LOCATION_SELECT = 3;
const MODE_RECIPIENT_FILL = 4;
const MODE_REVIEW = 5;

const TEXT_FIELD_LENGTH_LIMIT = 255;

// Hook types
const HOOK_TYPE_ONCE = 1; // Execute once per canvas (not called again during page-switch)]
const HOOK_TYPE_ALWAYS = 2; // Execute always after a render

// CANNOT USE CONSTANTS HERE, THEY GET MISTRANSLATED
const defaultHooks = {
  0: [
    // MODE_UNKNOWN / MODE_DISPLAY
  ],
  1: [
    // MODE_SETUP
    {
      id: "model/defaultValue",
      type: HOOK_TYPE_ALWAYS,
      fu: iacRenderDefaultValueHook,
    },
    {
      id: "model/hightlightFields",
      type: HOOK_TYPE_ONCE,
      fu: iacAddHighlightListener,
    },
    {
      id: "model/fieldClickListener",
      type: HOOK_TYPE_ONCE,
      fu: iacActivateFieldClickListeners,
    },
    {
      id: "setup/resizeListener",
      type: HOOK_TYPE_ONCE,
      fu: iacAddResizeListeners,
    },
  ],
  2: [
    // MODE_REQUESTOR_FILL
    {
      id: "model/defaultValue",
      type: HOOK_TYPE_ALWAYS,
      fu: iacRenderDefaultValueHook,
    },
    {
      id: "model/hightlightFields",
      type: HOOK_TYPE_ONCE,
      fu: iacAddHighlightListener,
    },
    {
      id: "model/fieldClickListener",
      type: HOOK_TYPE_ONCE,
      fu: iacActivateFieldClickListeners,
    },
    {
      id: "fill/selectText",
      type: HOOK_TYPE_ONCE,
      fu: iacSelectFieldListeners,
    },
    { id: "fill/fillListeners", type: HOOK_TYPE_ONCE, fu: iacAddFillListeners },
    { id: "fill/textMarker", type: HOOK_TYPE_ONCE, fu: iacAddTextMarker },
    { id: "fill/tabListener", type: HOOK_TYPE_ONCE, fu: iacAddTabListener },
  ],
  3: [
    // MODE_LOCATION_SELECT
    {
      id: "locationSelect/borders",
      type: HOOK_TYPE_ALWAYS,
      fu: iacRenderBordersHook,
    },
    {
      id: "locationSelect/mouseListeners",
      type: HOOK_TYPE_ONCE,
      fu: iacAddLSListeners,
    },
    {
      id: "model/fieldClickListener",
      type: HOOK_TYPE_ONCE,
      fu: iacActivateFieldClickListeners,
    },
  ],
  4: [
    // MODE_RECIPIENT_FILL
    {
      id: "model/defaultValue",
      type: HOOK_TYPE_ALWAYS,
      fu: iacRenderDefaultValueHook,
    },
    {
      id: "model/hightlightFields",
      type: HOOK_TYPE_ONCE,
      fu: iacAddHighlightListener,
    },
    {
      id: "model/fieldClickListener",
      type: HOOK_TYPE_ONCE,
      fu: iacActivateFieldClickListeners,
    },
    { id: "fill/fillListeners", type: HOOK_TYPE_ONCE, fu: iacAddFillListeners },
    { id: "fill/textMarker", type: HOOK_TYPE_ONCE, fu: iacAddTextMarker },
    { id: "fill/tabListener", type: HOOK_TYPE_ONCE, fu: iacAddTabListener },
  ],
  5: [
    // MODE_REVIEW
    {
      id: "model/defaultValue",
      type: HOOK_TYPE_ALWAYS,
      fu: iacRenderDefaultValueHook,
    },
    {
      id: "model/hightlightFields",
      type: HOOK_TYPE_ONCE,
      fu: iacAddHighlightListener,
    },
    {
      id: "model/fieldClickListener",
      type: HOOK_TYPE_ONCE,
      fu: iacActivateFieldClickListeners,
    },
    { id: "fill/fillListeners", type: HOOK_TYPE_ONCE, fu: iacAddFillListeners },
    { id: "fill/textMarker", type: HOOK_TYPE_ONCE, fu: iacAddTextMarker },
    { id: "fill/tabListener", type: HOOK_TYPE_ONCE, fu: iacAddTabListener },
  ],
};

/* Field specific handlers */
function textFieldPushChar(model, field, c) {
  var fieldId = field.__field_id;
  var canvas = model.render.canvas;
  let spec = makeLocationSpec(field);
  let idx = model.fill.textMarker.charIndex;

  if (model.fieldState[fieldId].fullyInitialized == false) {
    iacInitFieldDescriptor(model, spec, fieldId);
  }

  if (c == "Enter") {
    if (model.fieldState[fieldId].allow_multiline) {
      // TODO (lev) multiline should support ENTER
      return;
    } else {
      // these shouldn't do anything
      return;
    }
  }

  if (c == "Escape") {
    model.fill.activeField = null;
    return;
  }

  /* append the character */
  if (c == "deleteContentBackward") {
    if (model.fill.textMarker.charIndex == 0) {
      return;
    }
    model.fieldState[fieldId].text_charStack.splice(idx - 1, 1);
    model.fill.textMarker.charIndex = Math.max(
      0,
      model.fill.textMarker.charIndex - 1
    );
  } else {
    // Fallback alert, ideally this block will not be executed.
    // this is handled by the top level function
    let charLimit = model.fieldState[fieldId].charLimit;
    let currentCharLen =
      model.fieldState[model.fill.activeField].text_charStack.length || 0;
    if (
      currentCharLen + 1 > charLimit ||
      model.fill.textMarker.charIndex + 1 >= charLimit
    ) {
      alert(
        `Character limit (${charLimit}) reached, please consider trimming down your answer.`
      );
      return;
    }

    // check if it would overflow. XXX: this should not be in the model
    if (model.fieldState[fieldId].allow_multiline) {
      let finalString = model.fieldState[fieldId].text_charStack.join("") + c;
      let locationSpec = makeLocationSpec(model.fieldState[fieldId]);
      let maxWidth =
        Math.abs(locationSpec[1] - locationSpec[0]) * model.viewport.width - 10;
      let line = "";
      let words = finalString.split(" ");
      let rows = 0;
      let maxRows = model.fieldState[fieldId].maxRows;
      let canvas = model.render.canvas;
      let context = canvas.getContext("2d");
      for (const word of words) {
        if (context.measureText(line + word).width > maxWidth) {
          line = "";
          rows++;
        }

        line += word + " ";
      }
      if (rows >= maxRows) {
        alert("Row limit reached.");
        return;
      }
    }
    model.fieldState[fieldId].text_charStack.splice(idx, 0, c);
    model.fill.textMarker.charIndex = model.fill.textMarker.charIndex + 1;
  }

  iacRedrawField(model, spec, true);
}

/* Return the current string in the field */
function textFieldGetString(field) {
  return field.text_charStack.join("");
}

function textFieldClicked(_m, _field) {
  inputBoxClicked.set(true);
  // do nothing.
}

function checkboxClicked(m, field) {
  inputBoxClicked.set(true);
  let fieldId = field.__field_id;
  let spec = makeLocationSpec(field);
  if (m.fieldState[fieldId].fullyInitialized == false) {
    // if it didn't have its full init yet, initialize the field
    iacInitFieldDescriptor(m, spec, fieldId);
  }

  if (m.fieldState[fieldId].checkbox_checked) {
    m.fieldState[fieldId].checkbox_checked = false;
  } else {
    m.fieldState[fieldId].checkbox_checked = true;
  }

  iacDrawCheckbox(m, spec, field);
}

async function applySignature(model, evt) {
  let txId = iacModelBeginTransaction(model);
  let detail = evt.detail;
  let signature_data = {
    audit_start: detail.audit_start,
    audit_end: detail.audit_end,
    save_signature: detail.save_signature,
    isreq:
      model.operationMode == MODE_REQUESTOR_FILL ||
      model.operationMode == MODE_REVIEW,
    data: detail.data,
  };
  let reply = await iacApplySignature(detail.fieldId, signature_data);
  if (reply.ok) {
    /* apply the signature to the model */
    let sigInfo = {
      filled: true,
      auditStart: signature_data.audit_start,
      auditEnd: signature_data.audit_end,
      signatureData: signature_data.data,
      requestor_filled:
        model.operationMode == MODE_REQUESTOR_FILL ||
        model.operationMode == MODE_REVIEW,
    };
    detail.iacModel.fieldState[detail.fieldId].signature_info = sigInfo;
    iacRedrawField(
      detail.iacModel,
      makeLocationSpec(detail.iacModel.fieldState[detail.fieldId]),
      true
    );

    if (detail.save_signature) {
      model.esign.has_saved_sig = true;
      model.esign.saved_sig = signature_data.data;
    }
  } else {
    let error = await reply.json();
    showErrorMessage("iac", error.error);
  }
  return txId;
}

function esignOpenSingatureHandler(model, fieldId) {
  let sim = new SignatureInputModal({
    target: document.getElementById("boilerplate-error-container"),
    props: {
      iacModel: model,
      fieldId: fieldId,
    },
  });

  sim.$on("signatureApplied", (evt) => {
    storeSignatureFields.update(
      (signatureFieldId) => new Set([...signatureFieldId, fieldId])
    );
    applySignature(model, evt).then((txId) => {
      iacModelEndTransaction(model, txId);
      let container = document.getElementById("boilerplate-error-container");
      container.innerHTML = "";
    });
  });
}

async function esignConsentHandler(model, consent, fieldId) {
  let userType = "recipient";
  if (
    model.operationMode == MODE_REQUESTOR_FILL ||
    model.operationMode == MODE_REVIEW
  )
    userType = "requestor";

  let result = await iacSendEsignConsent(model.recipientId, consent, userType);

  if (result.ok) {
    model.esign.consented = consent;

    if (consent) {
      esignOpenSingatureHandler(model, fieldId);
    }
  } else {
    let error = await result.json();
    showErrorMessage("iac", error.error);
  }
}

function signatureClicked(m, field) {
  if (!m.esign.consented) {
    new EsignConsentModal({
      target: document.getElementById("boilerplate-error-container"),
      props: {
        consentHandler: esignConsentHandler,
        iacModel: m,
        fieldId: field.id,
      },
    });
  } else {
    esignOpenSingatureHandler(m, field.id);
  }
}

/* text marker */
function iacToggleTextMarker(model) {
  // bail quickly if the marker isn't enabled
  if (model.fill.textMarker.enabled == false) return;

  if (model.textSelect.select) return;

  if (model.fill.textMarker.visible) {
    let fieldId = model.fill.textMarker.field;
    let spec = makeLocationSpec(model.fieldState[fieldId]);

    // untoggle
    model.fill.textMarker.visible = false;
    iacRedrawField(model, spec, true);
  } else {
    // is there an activefield?
    if (model.fill.activeField) {
      model.fill.textMarker.field = model.fill.activeField;
      let spec = makeLocationSpec(
        model.fieldState[model.fill.textMarker.field]
      );

      if (spec[5] == 1) {
        model.fill.textMarker.visible = true;
        iacRedrawField(model, spec, false);
      }
    }
  }

  // there is no activefield anymore, clear it up
  if (model.fill.activeField == null && model.fill.textMarker.field != null) {
    model.fill.textMarker.visible = false;
    let spec = makeLocationSpec(model.fieldState[model.fill.textMarker.field]);
    iacRedrawField(model, spec, false);

    model.fill.textMarker.field = null;
  }
}

/* TAB handling */
function iacTabUpdate(model, spec) {
  // find the spec in the ordered list and update the currentIndex
  let specs = model.fill.orderedSpecs.filter(
    (x) => model.fieldState[x[4]].editable
  );
  for (let i = 0; i < specs.length; i++) {
    if (specs[i][4] == spec[4]) {
      __iacTabUpdate(model, spec, i);
      return;
    }
  }

  alert("Critical: Clicked on a field that isn't ordered?");
}

function __iacTabUpdate(model, spec, idx) {
  iacUnhightlightAll(model);
  var fieldId = spec[4];

  if (model.fieldState[fieldId].editable) {
    iacHightlightField(model, spec, false);
    model.fill.activeField = fieldId;
    iacToggleTextMarker(model);
  }

  model.fill.currentTabIndex = idx;
}

/* Default Hooks */
function iacAddTabListener(model) {
  if (isAndroidMobile()) {
    // Can't do TAB keys on Android
    console.log("IAC: Android device detected, running in quirks mode");
    return;
  }
  _iacAddWindowHook(model, "keydown", ($ev) => {
    if ($ev.data === "Tab" || $ev.data === "Enter") {
      // Filter down to the current page so that we don't switch pages while Tabbing
      let currentPage = model.multipage.currentPage;
      let thisPageSpecs = Array.from(model.fill.orderedSpecs).filter((e) => {
        return e[6] == currentPage && model.fieldState[e[4]].editable;
      });
      let numItems = thisPageSpecs.length;

      let offset = 1;
      if ($ev.shiftKey) {
        offset = -1;
      }
      let nextIndex = model.fill.currentTabIndex + offset;
      let effectiveIndex = ((nextIndex % numItems) + numItems) % numItems;
      let nextSpec = thisPageSpecs[effectiveIndex];

      __iacTabUpdate(model, nextSpec, effectiveIndex, nextSpec[5] == 1);

      // set charIndex to the end of the text
      if (nextSpec[5] == 1) {
        model.fill.textMarker.charIndex =
          model.fieldState[nextSpec[4]].text_charStack.length;
      }

      // Don't let the browser fallback to normal handling
      $ev.originalEvent.preventDefault();
    }
  });
}

function iacAddTextMarker(model) {
  window.setInterval(() => {
    iacToggleTextMarker(model);
  }, model.fill.textMarker.interval);
}

function iacCheckFillupField(model) {
  for (const spec of model.location_specs) {
    var _fieldId = spec[4];
    if (model.multipage.currentPage == spec[6]) {
      var fd = model.fieldState[_fieldId];
      var value = fd.text_charStack;
      var hasSignatureData = fd?.signature_info?.signatureData;
      var hasValue =
        value.length > 0 || fd.checkbox_checked || hasSignatureData || false;

      iacDrawBaseBorderHighlight(model, spec, hasValue);
    } else {
      model.fieldState[_fieldId].typeInfoAdded = false;
    }
  }
}

export function iacPageFieldValidation(model) {
  for (const spec of model.location_specs) {
    if (model.multipage.currentPage == spec[6]) {
      var _fieldId = spec[4];
      if (
        model.fieldState[_fieldId].fill_type == model.fill.type ||
        model.fieldState[_fieldId].fill_type == FILL_TYPE_ANYONE
      ) {
        var fd = model.fieldState[_fieldId];
        var value = fd.text_charStack;
        var hasSignatureData = fd?.signature_info?.signatureData;
        var hasValue = value.length > 0 || hasSignatureData || false;
        if (!hasValue && fd.field_type != FIELD_TYPE_CHECKBOX) {
          return true;
        }
      }
    }
  }
  return false;
}

export function iacAllFieldValidation(model) {
  for (const spec of model.location_specs) {
    var _fieldId = spec[4];
    if (
      model.fieldState[_fieldId].fill_type == model.fill.type ||
      model.fieldState[_fieldId].fill_type == FILL_TYPE_ANYONE
    ) {
      var fd = model.fieldState[_fieldId];
      var value = fd.text_charStack;
      var hasSignatureData = fd?.signature_info?.signatureData;
      var hasValue = value.length > 0 || hasSignatureData || false;

      if (!hasValue && fd.field_type != FIELD_TYPE_CHECKBOX) {
        return true;
      }
    }
  }
  return false;
}

function iacAddFillListeners(model) {
  iacAddFieldClickHook(model, (m, fieldId) => {
    iacDebug("clicked on fieldId: " + fieldId);
    let field = m.fieldState[fieldId];
    if (field.editable == false) {
      return;
    }
    iacDebug("^ -> editable");

    // disables iac fill on fields when the requestor is editing the document
    if (window.temp_disable_recipient_fill || window.temp_disable_review_fill) {
      return;
    }

    // Ok the field is editable and was clicked, based on the field_type,
    // we forward the event.
    switch (field.field_type) {
      case 1: // Text field
        textFieldClicked(m, field);
        break;
      case 2: // Checkbox
        checkboxClicked(m, field);
        break;
      case 3:
        signatureClicked(m, field);
        break;
      default:
        console.log(
          "ERROR: clicked a field with an invalid field type: " +
            field.field_type
        );
        break;
    }

    iacCheckFillupField(model);

    iacTabUpdate(model, makeLocationSpec(field));
  });

  _iacAddWindowHook(model, "keydown", (ev) => {
    if (model.fill.enabled == false) {
      return;
    }

    let key = ev.data; // Detecting key
    let ctrl = ev.originalEvent.ctrlKey; // Detecting Ctrl
    let metaKey = ev.originalEvent.metaKey; // Detecting Meta Key

    if ((ctrl || metaKey) && ["a", "c", "v", "x"].includes(key.toLowerCase())) {
      return;
    }
    if (model.textSelect.selectAll && key == "deleteContentBackward") {
      return;
    }

    /* check if a field has been correctly selected */
    if (
      model.fill.activeField &&
      model.fieldState[model.fill.activeField].field_type == 1
    ) {
      /* log for debugging TODO */
      iacDebug(ev);

      const banned_keys = [
        "Tab",
        "Shift",
        "Meta",
        "Control",
        "CapsLock",
        "Delete",
        "Insert",
        "F1",
        "F2",
        "F3",
        "F4",
        "F5",
        "F6",
        "F7",
        "F8",
        "F9",
        "F10",
        "F11",
        "F12",
        "Help",
        "Home",
        "End",
        "PageUp",
        "PageDown",
        "F13",
        "ArrowUp",
        "ArrowDown",
        "ArrowRight",
        "Alt",
        "NumLock",
        "ArrowLeft",
        "Unidentified",
        "Clear",
        "ContextMenu",
      ];

      let navigationType = [
        "cursorUp",
        "cursorDown",
        "cursorLeft",
        "cursorRight",
      ];

      if (banned_keys.includes(ev.data)) {
        iacDebug("   -> key banned");
        return;
      }

      if (navigationType.includes(ev.navigationType)) {
        return;
      }

      /* Check if we should marshall this back into a Backspace,
       * see: https://rawgit.com/w3c/input-events/v1/index.html#interface-InputEvent-Attributes
       */
      let append = true;
      if (ev.originalEvent instanceof InputEvent) {
        if (ev.originalEvent.inputType == "insertCompositionText") {
          /* Compare the length of the new origData with the text in the field */
          let lengthOfNewText = 0;
          if (ev.originalData != null) {
            lengthOfNewText = ev.originalData.length;
          }
          let fieldText = textFieldGetString(
            model.fieldState[model.fill.activeField]
          );
          // Slice with whitespace
          let fieldArr = fieldText.split(" ");
          fieldText = fieldArr[fieldArr.length - 1];
          let lengthOfField = fieldText.length;
          if (lengthOfNewText == lengthOfField) {
            append = false;
          }

          console.log(
            "newText = %s, fieldText = %s, lengths %d vs %d",
            ev.originalData,
            fieldText,
            lengthOfNewText,
            lengthOfField
          );
          if (lengthOfNewText < lengthOfField) {
            ev.data = "deleteContentBackward";
          }
        }
      }

      /* append the character to the text */
      if (append) {
        model.textSelect.select = false;
        let charLimit = model.fieldState[model.fill.activeField].charLimit;
        let currentCharLen =
          model.fieldState[model.fill.activeField].text_charStack.length || 0;
        if (
          currentCharLen + 1 > charLimit ||
          model.fill.textMarker.charIndex + 1 >= charLimit
        ) {
          alert(
            `Character limit (${charLimit}) reached, please consider trimming down your answer.`
          );
          return;
        }
        textFieldPushChar(
          model,
          model.fieldState[model.fill.activeField],
          ev.data
        );
      }

      iacCheckFillupField(model);

      /* stop the event propagation so it does not scroll the view */
      ev.originalEvent.stopPropagation();
      ev.originalEvent.preventDefault();
    }
  });

  _iacAddWindowHook(model, "keydown", (ev) => {
    if (
      model.fill.activeField &&
      model.fill.textMarker.enabled &&
      model.fieldState[model.fill.activeField].field_type == 1
    ) {
      if (ev.data == "ArrowLeft" || ev.navigationType == "cursorLeft") {
        iacDebug(ev);

        model.fill.textMarker.charIndex = Math.max(
          0,
          model.fill.textMarker.charIndex - 1
        );
        iacToggleTextMarker(model);
      } else if (
        ev.data == "ArrowRight" ||
        ev.navigationType == "cursorRight"
      ) {
        let fd = model.fieldState[model.fill.activeField];
        iacDebug(ev);

        model.fill.textMarker.charIndex = Math.min(
          model.fill.textMarker.charIndex + 1,
          fd.text_charStack.length
        );
        iacToggleTextMarker(model);
      }
    }
  });

  _iacAddWindowHook(model, "keydown", (ev) => {
    let key = ev.data; // Detecting key
    let metaKey = ev.originalEvent.metaKey; // Detecting Meta Key
    let ctrl = ev.originalEvent.ctrlKey; // Detecting Ctrl

    if ((ctrl || metaKey) && key.toLowerCase() == "v") {
      if (model.fill.enabled == false) {
        return;
      }

      /* check if a field has been correctly selected */
      if (
        model.fill.activeField &&
        model.fieldState[model.fill.activeField].field_type == 1
      ) {
        if (navigator.clipboard && navigator.clipboard.readText) {
          navigator.clipboard.readText().then((copied_texts) => {
            copied_texts = copied_texts.split("");
            let charLimit =
              model.fieldState[model.fill.activeField].charLimit || 255;
            let currentCharLen =
              model.fieldState[model.fill.activeField].text_charStack.length ||
              0;
            let totalCharLenth = currentCharLen + copied_texts.length;
            console.log(copied_texts);
            console.log(currentCharLen);
            console.log(totalCharLenth);
            if (
              totalCharLenth > charLimit ||
              model.fill.textMarker.charIndex + 1 >= charLimit
            ) {
              alert(
                `Copied text too large. Character limit (${charLimit}) reached, please consider trimming down your answer.`
              );
              return;
            }
            console.log(model.fieldState[model.fill.activeField]);
            console.log(model.fill.textMarker.charIndex);
            copied_texts.forEach((copied_text) => {
              textFieldPushChar(
                model,
                model.fieldState[model.fill.activeField],
                copied_text
              );
            });
          });
        }
      }
    }

    if (model.textSelect.select) {
      let { spec } = model.textSelect;

      if ((ctrl || metaKey) && key.toLowerCase() == "c") {
        let fieldId = spec[4];
        let { startIndex, endIndex } = model.textSelect;
        if (startIndex > endIndex) {
          [startIndex, endIndex] = [endIndex, startIndex];
        }
        let text = model.fieldState[fieldId].text_charStack.slice(
          startIndex,
          endIndex
        );
        let copyText = text.join("");
        navigator.clipboard.writeText(copyText).then(
          () => {
            console.log("Copied to clipboard");
          },
          () => {
            console.log("Error setting clipboard");
          }
        );

        iacRedrawField(model, spec, true);
        model.textSelect.select = false;
      } else if ((ctrl || metaKey) && key.toLowerCase() == "x") {
        let fieldId = spec[4];
        let { startIndex, endIndex } = model.textSelect;
        if (startIndex > endIndex) {
          [startIndex, endIndex] = [endIndex, startIndex];
        }
        let text = model.fieldState[fieldId].text_charStack.splice(
          startIndex,
          endIndex - startIndex
        );
        let copyText = text.join("");
        navigator.clipboard.writeText(copyText).then(
          () => {
            console.log("Copied to clipboard");
          },
          () => {
            console.log("Error setting clipboard");
          }
        );

        model.fill.textMarker.charIndex = startIndex;
        iacRedrawField(model, spec, true);
        model.textSelect.select = false;
      }
    }

    if (model.textSelect.selectAll) {
      let { spec } = model.textSelect;
      if (key == "deleteContentBackward") {
        let fieldId = spec[4];
        model.fieldState[fieldId].text_charStack = [];
        model.fill.textMarker.charIndex = 0;
        iacRedrawField(model, spec, true);
        model.textSelect.selectAll = false;
        model.textSelect.select = false;
      }
    }
  });
}
function iacSelectFieldListeners(model) {
  let canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  let bX, bY, width, height;
  _iacAddCanvasHook(model, "mousedown", ($e) => {
    let rect = canvas.getBoundingClientRect(),
      scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;

    /* calculate the relative coordinates */
    let rX = (($e.clientX - rect.left) * scaleX) / model.viewport.width;
    let rY = (($e.clientY - rect.top) * scaleY) / model.viewport.height;

    let spec = iacFindFieldByLocation(model, rX, rY);

    bX = parseInt(($e.clientX - rect.left) * scaleX);

    model.textSelect.pdfData = context.getImageData(
      0,
      0,
      model.viewport.width,
      model.viewport.height
    );

    if (spec != null && !model.textSelect.select) {
      model.textSelect.mouseDown = true;
      model.textSelect.spec = spec;
      let oX = Math.abs(rX - spec[0]);
      let oY = Math.abs(rY - spec[2]);
      model.textSelect.startIndex = getBestGuessCharIndex(
        model,
        spec[4],
        oX,
        oY
      );
    }
  });
  _iacAddCanvasHook(model, "mousemove", ($e) => {
    var rect = canvas.getBoundingClientRect();
    var scaleX = canvas.width / rect.width;
    var mousex = parseInt(
      ($e.clientX - canvas.getBoundingClientRect().left) * scaleX
    );
    if (model.textSelect.mouseDown) {
      let { spec } = model.textSelect;
      let fd = model.fieldState[spec[4]];
      let fontSize = fd.text_fontSize;

      if (fontSize == 0 || fd.text_charStack.length == 0) {
        return;
      }

      context.putImageData(model.textSelect.pdfData, 0, 0);
      context.beginPath();

      let startX = spec[0] * model.viewport.width;
      let endX = spec[1] * model.viewport.width;
      let startY = spec[2] * model.viewport.height;
      let endY = spec[3] * model.viewport.height;
      let field_width = Math.abs(endX - startX);
      let distance = Math.abs(startX - bX);

      width = mousex - bX;
      height = Math.abs(endY - startY);
      bY = startY;

      if (width + distance > field_width) {
        width = field_width - distance;
      }
      if (width < 0 && Math.abs(width) > distance) {
        width = -distance;
      }

      context.rect(bX, bY, width, height);

      context.fillStyle = "rgba(137, 207, 240, 50%)";
      context.lineWidth = 5;
      context.fill();
      model.textSelect.select = true;
    }
  });
  _iacAddCanvasHook(model, "mouseup", ($e) => {
    model.textSelect.mouseDown = false;
    let { spec } = model.textSelect;

    if (spec != null) {
      let rect = canvas.getBoundingClientRect(),
        scaleX = canvas.width / rect.width,
        scaleY = canvas.height / rect.height;
      let rX = (($e.clientX - rect.left) * scaleX) / model.viewport.width;
      let rY = (($e.clientY - rect.top) * scaleY) / model.viewport.height;
      let oX = Math.abs(rX - spec[0]);
      let oY = Math.abs(rY - spec[2]);

      model.textSelect.endIndex = getBestGuessCharIndex(model, spec[4], oX, oY);
    }
  });

  _iacAddWindowHook(model, "keydown", (ev) => {
    let key = ev.data; // Detecting key
    let ctrl = ev.originalEvent.ctrlKey; // Detecting Ctrl
    let metaKey = ev.originalEvent.metaKey; // Detecting Meta Key

    if ((ctrl || metaKey) && key.toLowerCase() == "a") {
      if (model.fill.enabled == false) {
        return;
      }
      let { spec } = model.textSelect;
      let fd = model.fieldState[spec[4]];
      let fontSize = fd.text_fontSize;

      if (fontSize == 0 || fd.text_charStack.length == 0) {
        return;
      }
      iacRedrawField(model, spec, true);

      let startX = spec[0] * model.viewport.width;
      let endX = spec[1] * model.viewport.width;
      let startY = spec[2] * model.viewport.height;
      let endY = spec[3] * model.viewport.height;
      let width = Math.abs(endX - startX);
      let height = Math.abs(endY - startY);
      context.rect(startX, startY, width, height);

      context.fillStyle = "rgba(137, 207, 240, 50%)";
      context.lineWidth = 5;
      context.fill();
      model.textSelect.select = true;
      model.textSelect.selectAll = true;
      model.textSelect.startIndex = 0;
      model.textSelect.endIndex = fd.text_charStack.length;
    }
  });
}

function iacActivateFieldClickListeners(model) {
  _iacAddCanvasHook(model, "click", async ($ev) => {
    if (model.preventClick) {
      model.preventClick = false;
      return;
    }

    let canvas = model.render.canvas;
    var context = canvas.getContext("2d");
    let rect = canvas.getBoundingClientRect(),
      scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;

    /* calculate the relative coordinates */
    let rX = (($ev.clientX - rect.left) * scaleX) / model.viewport.width;
    let rY = (($ev.clientY - rect.top) * scaleY) / model.viewport.height;

    let spec = iacFindFieldByLocation(model, rX, rY);
    if (spec != null) {
      // found the field that we clicked on;
      var fieldId = spec[4];

      // calculate offsets inside the field
      let oX = Math.abs(rX - spec[0]);
      let oY = Math.abs(rY - spec[2]);
      iacModelHandleClick(model, oX, oY, fieldId);

      model.setupActiveField = fieldId;
      if (model.operationMode == MODE_LOCATION_SELECT) {
        /**
         * For the case of the field being resized, we need to update the field image and the field state
         * stopHiglightListener is a hack flag, use for prevent capture border.
         */
        await iacSwitchOperationMode(model, MODE_SETUP);
        model.stopHiglightListener = true;
        model.locationSelect.pdfData = context.getImageData(
          0,
          0,
          model.viewport.width,
          model.viewport.height
        );
        iacInitFieldDescriptor(model, spec, fieldId);
        model.stopHiglightListener = false;
        canvas.style.cursor = "default";
        iacActiveFieldHandler(model, fieldId);
      } else {
        model.stopHiglightListener = true;
        if (model.operationMode == MODE_SETUP) {
          context.putImageData(model.locationSelect.pdfData, 0, 0);
        }
        model.stopHiglightListener = false;
        canvas.style.cursor = "default";
        iacActiveFieldHandler(model, fieldId);
      }
    } else {
      // Resets the active field if the clicked co-ordinate doesnot contains any field
      model.fill.activeField = null;
    }
  });
}

function iacActiveFieldHandler(model, field) {
  if (model.operationMode != MODE_SETUP) {
    return;
  }

  for (const spec of model.location_specs) {
    var fieldId = spec[4];
    var fd = model.fieldState[fieldId];
    if (fd.defaultImageData) {
      iacRedrawField(model, spec, true);
    }
  }

  let canvas = model.render.canvas;
  let spec = model.location_specs.find((elem) => {
    return elem[4] == field;
  });

  if (model.multipage.enabled && model.multipage.currentPage != spec[6]) {
    // This spec is not on the current page, refuse to update it.
    return;
  }
  var context = canvas.getContext("2d");
  var prevStrokeStyle = context.strokeStyle;
  var prevLineWidth = context.lineWidth;
  var startX = spec[0] * model.viewport.width;
  var startY = spec[2] * model.viewport.height;
  var endX = spec[1] * model.viewport.width;
  var endY = spec[3] * model.viewport.height;
  var width = Math.abs(endX - startX);
  var height = Math.abs(endY - startY);
  // context.strokeStyle = "rgba(0, 0, 0, 100%)";
  context.strokeStyle = "red";
  context.lineWidth = 5;
  context.strokeRect(startX, startY, width, height);

  context.strokeStyle = prevStrokeStyle;
  context.lineWidth = prevLineWidth;
}

function iacAddLSListeners(model) {
  let canvas = model.render.canvas;
  let context = canvas.getContext("2d");

  let oldSetupActiveField = model.setupActiveField;
  let oldCanvasImage = context.getImageData(
    0,
    0,
    model.viewport.width,
    model.viewport.height
  );

  _iacAddCanvasHook(model, "mousedown", ($e) => {
    iacAssert(
      model,
      model.operationMode == MODE_LOCATION_SELECT ||
        model.operationMode == MODE_SETUP,
      "invalid mousedown event"
    );

    if (canvas.style.cursor == "progress") {
      return;
    }

    var rect = canvas.getBoundingClientRect();
    var scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;
    model.locationSelect.lastMouseX = parseInt(
      ($e.clientX - rect.left) * scaleX
    );
    model.locationSelect.lastMouseY = parseInt(
      ($e.clientY - rect.top) * scaleY
    );

    model.locationSelect.mouseDown = true;
    model.locationSelect.finalMouseX = null;
    model.locationSelect.finalMouseY = null;
    model.setupActiveField = null;
    iacRenderBordersHook(model);

    model.locationSelect.pdfData = context.getImageData(
      0,
      0,
      model.viewport.width,
      model.viewport.height
    );
  });

  _iacAddCanvasHook(model, "mouseup", async ($e) => {
    iacAssert(
      model,
      model.operationMode == MODE_LOCATION_SELECT ||
        model.operationMode == MODE_SETUP,
      "invalid mouseup event"
    );
    model.locationSelect.mouseDown = false;
    var rect = canvas.getBoundingClientRect();
    var scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;

    // save to the window
    model.locationSelect.finalMouseX = parseInt(
      ($e.clientX - rect.left) * scaleX
    );
    model.locationSelect.finalMouseY = parseInt(
      ($e.clientY - rect.top) * scaleY
    );

    // spec[0] relative baseX
    // spec[1] relative finalX
    // spec[2] relative baseY
    // spec[3] relative finalY
    // spec[4] concrete fieldId
    // spec[5] concrete fieldType
    // spec[6] concrete pageNumber
    //return [bX, fX, bY, fY, lv5, lv6, page_no];
    let baseX = model.locationSelect.lastMouseX / model.viewport.width;
    let finalX = model.locationSelect.finalMouseX / model.viewport.width;
    let baseY = model.locationSelect.lastMouseY / model.viewport.height;
    let finalY = model.locationSelect.finalMouseY / model.viewport.height;
    let fieldType = model.locationSelect.fieldType;
    let pageNumber = model.multipage.currentPage;
    let fill_type = model.version === 1 ? FILL_TYPE_RECIPIENT : 0;

    if (baseX == finalX && baseY == finalY) {
      model.setupActiveField = oldSetupActiveField;
      context.putImageData(oldCanvasImage, 0, 0);
      return;
    }

    if (canvas.style.cursor == "progress") {
      model.setupActiveField = oldSetupActiveField;
      context.putImageData(oldCanvasImage, 0, 0);
      return;
    }

    // if (fieldType != 2) {
    if (Math.abs(baseX - finalX) * 100 <= 0.8) {
      finalX = baseX + 0.008;
    }

    if (Math.abs(baseY - finalY) * 100 <= 0.6) {
      finalY = baseY + 0.006;
    }
    // }

    if (baseX > finalX) {
      let _temp = baseX;
      baseX = finalX;
      finalX = _temp;
    }
    if (baseY > finalY) {
      let _temp = baseY;
      baseY = finalY;
      finalY = _temp;
    }

    if (model.selectedField.fill_type) {
      if (model.version == 1) {
        fill_type =
          model.selectedField.fill_type == FILL_TYPE_ANYONE
            ? FILL_TYPE_RECIPIENT
            : model.selectedField.fill_type;
      } else {
        fill_type = model.selectedField.fill_type;
      }
    }

    iacLoadingState.set(true);

    canvas.style.cursor = "progress";

    let newIdReply = await iacAddField(
      model.iacDocument.id,
      fieldType,
      baseX,
      baseY,
      finalX,
      finalY,
      pageNumber,
      fill_type
    );
    if (newIdReply.ok) {
      // Add to the location_spec list
      let newIdR = await newIdReply.json();
      let ls = [baseX, finalX, baseY, finalY, newIdR.id, fieldType, pageNumber];
      let field = newIdR.field;

      model.location_specs.push(ls);
      iacUndoHistory(model, ls, "newAdd");
      model.fieldState[newIdR.id] = makeFieldState(
        field,
        MODE_SETUP,
        model.sesMode
      );
      model.locationSelect.fieldType = model.selectedField.field_type;

      model.setupActiveField = newIdR.id;

      await iacSwitchOperationMode(model, MODE_LOCATION_SELECT);
      _iacFieldClick(model, newIdR.id);

      iacLoadingState.set(false);

      canvas.style.cursor = "crosshair";
    } else {
      let error = await newIdReply.json();
      showErrorMessage("iac", error.error);

      iacLoadingState.set(false);

      canvas.style.cursor = "default";

      // Revert back to SETUP_MODE
      await iacSwitchOperationMode(model, MODE_SETUP);
    }
  });
  _iacAddCanvasHook(model, "mousemove", ($e) => {
    iacAssert(
      model,
      model.operationMode == MODE_LOCATION_SELECT ||
        model.operationMode == MODE_SETUP,
      "invalid mousemove event"
    );
    var rect = canvas.getBoundingClientRect();
    var scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;
    var mousex = parseInt(
      ($e.clientX - canvas.getBoundingClientRect().left) * scaleX
    );
    var mousey = parseInt(
      ($e.clientY - canvas.getBoundingClientRect().top) * scaleY
    );
    if (model.locationSelect.mouseDown) {
      context.putImageData(model.locationSelect.pdfData, 0, 0);
      context.beginPath();
      var pWidth = mousex - model.locationSelect.lastMouseX;
      var pHeight = mousey - model.locationSelect.lastMouseY;
      context.rect(
        model.locationSelect.lastMouseX,
        model.locationSelect.lastMouseY,
        pWidth,
        pHeight
      );
      context.strokeStyle = "red";
      context.lineWidth = 5;
      context.stroke();
    }
  });
}

function iacRenderBordersHook(model) {
  iacDrawBordersAroundFields(model);
  for (const spec of model.location_specs) {
    iacDrawFieldTypeInto(model, spec);
  }
}

function checkCloseEnough(p1, p2, closeEnough = 0.005) {
  return Math.abs(p1 - p2) < closeEnough;
}

function iacAddResizeListeners(model) {
  let canvas = model.render.canvas;
  let context = canvas.getContext("2d");

  model.resizeLocationSelect.pdfData = context.getImageData(
    0,
    0,
    model.viewport.width,
    model.viewport.height
  );
  _iacAddCanvasHook(model, "mousedown", ($e) => {
    var rect = canvas.getBoundingClientRect();
    var scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;

    /**
     * field resize functionality
     */
    model.resizeLocationSelect.lastMouseX = parseInt(
      ($e.clientX - rect.left) * scaleX
    );
    model.resizeLocationSelect.lastMouseY = parseInt(
      ($e.clientY - rect.top) * scaleY
    );

    let mouseX = model.resizeLocationSelect.lastMouseX / model.viewport.width;
    let mouseY = model.resizeLocationSelect.lastMouseY / model.viewport.height;

    model.location_specs.forEach((element) => {
      element.position = "";
      element.dragging = false;
    });

    model.location_specs.forEach((element) => {
      let [x1, x2, y1, y2] = element;
      let width = x2 - x1;
      let height = y2 - y1;
      if (!model.resizeLocationSelect.resize) {
        if (width < 0.006 || height < 0.006) {
        }
        // Check top left edges
        else if (checkCloseEnough(mouseX, x1) && checkCloseEnough(mouseY, y1)) {
          model.resizeLocationSelect.resize = true;
          element.position = "top-left";
          canvas.style.cursor = "nwse-resize";
        }
        // 2. top right
        else if (
          checkCloseEnough(mouseX, x1 + width) &&
          checkCloseEnough(mouseY, y1)
        ) {
          model.resizeLocationSelect.resize = true;
          element.position = "top-right";
          canvas.style.cursor = "nesw-resize";
        }
        // 3. bottom left
        else if (
          checkCloseEnough(mouseX, x1) &&
          checkCloseEnough(mouseY, y1 + height)
        ) {
          model.resizeLocationSelect.resize = true;
          element.position = "bottom-left";
          canvas.style.cursor = "nesw-resize";
        }
        // 4. bottom right
        else if (
          checkCloseEnough(mouseX, x1 + width) &&
          checkCloseEnough(mouseY, y1 + height)
        ) {
          model.resizeLocationSelect.resize = true;
          element.position = "bottom-right";
          canvas.style.cursor = "nwse-resize";
        }
      }
    });

    model.resizeLocationSelect.mouseDown = false;
    model.resizeLocationSelect.finalMouseX = null;
    model.resizeLocationSelect.finalMouseY = null;

    model.resizeLocationSelect.pdfData = context.getImageData(
      0,
      0,
      model.viewport.width,
      model.viewport.height
    );
  });
  _iacAddCanvasHook(model, "mousemove", ($e) => {
    var rect = canvas.getBoundingClientRect();
    var mousex = parseInt($e.clientX - rect.left);
    var mousey = parseInt($e.clientY - rect.top);
    var scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;

    /**
     * field resize functionality
     */

    if (model.resizeLocationSelect.resize) {
      context.putImageData(model.resizeLocationSelect.pdfData, 0, 0);
      context.beginPath();

      model.location_specs.forEach((element) => {
        if (element.position != "") {
          mousex = mousex * scaleX;
          mousey = mousey * scaleY;
          let x1, x2, y1, y2;
          let _width = mousex / model.viewport.width;
          let _height = mousey / model.viewport.height;
          if (element.position == "top-left") {
            canvas.style.cursor = "nwse-resize";
            x1 = _width * model.viewport.width;
            y1 = _height * model.viewport.height;
            x2 = element[1] * model.viewport.width - mousex;
            y2 = element[3] * model.viewport.height - mousey;
          } else if (element.position == "top-right") {
            canvas.style.cursor = "nesw-resize";
            x1 = element[0] * model.viewport.width;
            y1 = _height * model.viewport.height;
            x2 = mousex - element[0] * model.viewport.width;
            y2 = element[3] * model.viewport.height - mousey;
          } else if (element.position == "bottom-left") {
            canvas.style.cursor = "nesw-resize";
            x1 = _width * model.viewport.width;
            y1 = element[2] * model.viewport.height;
            x2 = element[1] * model.viewport.width - mousex;
            y2 = mousey - element[2] * model.viewport.height;
          } else if (element.position == "bottom-right") {
            canvas.style.cursor = "nwse-resize";
            x1 = element[0] * model.viewport.width;
            y1 = element[2] * model.viewport.height;
            x2 = mousex - element[0] * model.viewport.width;
            y2 = mousey - element[2] * model.viewport.height;
          }
          context.rect(x1, y1, x2, y2);
          context.strokeStyle = "red";
          context.lineWidth = 5;
          context.stroke();

          model.resizeLocationSelect.lastMouseX = x1;
          model.resizeLocationSelect.lastMouseY = y1;
          model.resizeLocationSelect.finalMouseX = x2;
          model.resizeLocationSelect.finalMouseY = y2;
          model.resizeLocationSelect.fieldId = element[4];
          model.resizeLocationSelect.fieldType = element[5];
          model.resizeLocationSelect.pageNumber = element[6];
        }
      });
    }
  });

  /**
   * resize field update functionality
   */
  _iacAddCanvasHook(model, "mouseup", async () => {
    let {
      lastMouseX,
      lastMouseY,
      finalMouseX,
      finalMouseY,
      fieldId,
      fieldType,
      pageNumber,
      resize,
    } = model.resizeLocationSelect;

    if (resize) {
      model.resizeLocationSelect.resize = false;
      canvas.style.cursor = "default";
    }

    if (!lastMouseX || !lastMouseY || !finalMouseX || !finalMouseY) {
      return;
    }

    let minX = lastMouseX / model.viewport.width;
    let fieldWidth = finalMouseX / model.viewport.width + minX;
    let minY = lastMouseY / model.viewport.height;
    let fieldHeight = finalMouseY / model.viewport.height + minY;

    if (minX > fieldWidth) {
      let temp = minX;
      minX = fieldWidth;
      fieldWidth = temp;
    }

    if (minY > fieldHeight) {
      let temp = minY;
      minY = fieldHeight;
      fieldHeight = temp;
    }

    model.preventClick = true;

    let reply = await iacUpdateField(model.iacDocument.id, fieldId, {
      type: fieldType,
      pageNo: pageNumber,
      minX,
      fieldWidth,
      minY,
      fieldHeight,
    });
    if (reply.ok) {
      let res = await reply.json();
      let _index = model.location_specs.findIndex((elem) => elem[4] == fieldId);

      let field = res.field;
      let ls = [
        minX,
        fieldWidth,
        minY,
        fieldHeight,
        fieldId,
        fieldType,
        pageNumber,
      ];
      model.location_specs[_index] = ls;

      ls.fill_type = field.fill_type;
      let _tempItem = Object.assign({}, ls);
      iacUndoHistory(model, _tempItem, "updateFillType");

      let fieldState = makeFieldState(field, MODE_SETUP, model.sesMode);
      model.fieldState[fieldId] = fieldState;

      await iacRender(model, model.render.canvas);

      /**
       * For the case of the field being resized, we need to update the field image and the field state
       * stopHiglightListener is a hack flag, use for prevent capture border.
       */

      model.stopHiglightListener = true;
      model.setupActiveField = fieldId;
      iacInitFieldDescriptor(model, ls, fieldId);
      model.stopHiglightListener = false;
      model.locationSelect.pdfData = context.getImageData(
        0,
        0,
        model.viewport.width,
        model.viewport.height
      );
      iacActiveFieldHandler(model, fieldId);
      model.preventClick = false;
      if (model.showFieldInformation) {
        model.showFieldInformation(model, fieldId);
      }
    } else {
      let error = await reply.json();
      showErrorMessage("iac", error.error);
      model.preventClick = false;
    }

    model.resizeLocationSelect = {
      lastMouseX: null,
      lastMouseY: null,
      mouseDown: false,
      pdfData: null,
      fieldType: null,
      finalMouseX: null,
      finalMouseY: null,
      fieldId: null,
      fieldType: null,
      pageNumber: null,
    };
    canvas.style.cursor = "default";
  });
}

function iacAddHighlightListener(model) {
  let canvas = model.render.canvas;
  let context = canvas.getContext("2d");

  _iacAddCanvasHook(model, "mousemove", ($e) => {
    if (model.stopHiglightListener) {
      return;
    }
    var rect = canvas.getBoundingClientRect();
    var mousex = parseInt($e.clientX - rect.left);
    var mousey = parseInt($e.clientY - rect.top);
    var scaleX = canvas.width / rect.width, // relationship bitmap vs. element for X
      scaleY = canvas.height / rect.height;
    var spec = iacFindFieldByLocation(
      model,
      (mousex * scaleX) / model.viewport.width,
      (mousey * scaleY) / model.viewport.height
    );

    if (model.operationMode == MODE_SETUP) {
      if (!model.highlightedField) {
        if (!model.setupActiveField) {
          model.locationSelect.pdfData = context.getImageData(
            0,
            0,
            model.viewport.width,
            model.viewport.height
          );
        }
      }
    }

    if (
      spec != null &&
      model.highlightedField != spec[4] &&
      model.highlightedField != null
    ) {
      iacUnhightlightAll(model);
    }

    if (spec != null) {
      // the mouse is currently over a valid field
      iacHightlightField(model, spec, false);
      model.highlightedField = spec[4];
    }

    if (spec == null) {
      iacUnhightlightAll(model);
      model.highlightedField = null;
    }

    if (spec == null) {
      if (model.operationMode == MODE_SETUP) {
        context.putImageData(model.locationSelect.pdfData, 0, 0);
      }
      if (model.setupActiveField) {
        iacActiveFieldHandler(model, model.setupActiveField);
      }
    }
  });
}

function textFieldChanged(fd) {
  if (fd.field_type == 1) {
    let final_value = fd.text_charStack.join("");

    return final_value != fd.set_value;
  } else {
    return false;
  }
}

function iacRenderDefaultValueHook(model) {
  for (const spec of model.location_specs) {
    var fieldId = spec[4];
    if (model.multipage.currentPage == spec[6]) {
      var fd = model.fieldState[fieldId];

      if (model.operationMode == MODE_SETUP) {
        iacDrawFieldTypeInto(model, spec);
      } else {
        if (model.sesMode && fd.field_type == 4) {
          iacDrawTable(model, fd, spec);
        }
        iacDrawBaseHighlight(model, spec);
      }

      if (
        fd.checkbox_checked == true ||
        (fd.set_value != null && fd.set_value != "") ||
        textFieldChanged(fd) ||
        fd.field_type == 3
      ) {
        // trigger a redraw
        if (model.fieldState[fieldId].fullyInitialized == false) {
          iacInitFieldDescriptor(model, spec, fieldId);
        }

        iacRedrawField(model, spec, false);
      }
    }
  }

  if (model.operationMode != MODE_SETUP) {
    iacCheckFillupField(model);
  }
}

function handleActionButtonStyle(id, type = "active") {
  let elem = document.getElementById(id);
  if (elem) {
    if (type == "active") {
      elem.style.color = "black";
    } else {
      elem.style.color = "#b3c1d0";
    }
  }
}

function iacUndoHistory(model, ls, action) {
  ls.action = action;
  let { temp_undo_location_specs } = model;
  temp_undo_location_specs.push(ls);
  if (temp_undo_location_specs.length > 0) {
    handleActionButtonStyle("iac_undo_button");
  }
}
function iacRedoHistory(model, ls, action) {
  ls.action = action;
  let { temp_redo_location_specs } = model;
  temp_redo_location_specs.push(ls);
  if (temp_redo_location_specs.length > 0) {
    handleActionButtonStyle("iac_redo_button");
  }
}

async function iacUndo(model) {
  let { temp_undo_location_specs } = model;
  if (temp_undo_location_specs.length > 0) {
    let lastItemAction =
      temp_undo_location_specs[temp_undo_location_specs.length - 1];
    let fieldState = null;
    if (lastItemAction.action == "updateFillType") {
      let popItem = temp_undo_location_specs.pop();

      let field = {
        id: popItem[4],
        __field_id: popItem[4],
        fill_type: 0,
        field_type: 1,
        location: {
          values: [
            popItem[0],
            popItem[1],
            popItem[2],
            popItem[3],
            popItem[5],
            popItem[6],
          ],
        },
      };

      if (popItem.fill_type) {
        field.fill_type = popItem.fill_type;
      }

      if (popItem.field_type) {
        field.field_type = popItem.field_type;
      }

      let oldFillType = model.fieldState[popItem[4]].fill_type;
      let oldFieldType = model.fieldState[popItem[4]].field_type;

      fieldState = await iacModelUpdateField(model, field, false);
      if (fieldState) {
        let _tempItem;
        popItem.fill_type = oldFillType;
        popItem.field_type = oldFieldType;
        _tempItem = Object.assign({}, popItem);
        iacRedoHistory(model, _tempItem, "updateFillType");
      }
    } else if (lastItemAction.action == "newAdd") {
      let popItem = temp_undo_location_specs.pop();
      let field = { __field_id: popItem[4] };
      fieldState = await iacModelRemoveField(model, field, false);
      let _tempItem = Object.assign({}, popItem);
      iacRedoHistory(model, _tempItem, "newAdd");
    } else if (lastItemAction.action == "itemRemoved") {
      let popItem = temp_undo_location_specs.pop();
      let oldFieldId = popItem[4];
      let addNew = await iacModelAddField(model, popItem, false);
      if (addNew) {
        temp_undo_location_specs.forEach((item) => {
          if (item[4] == oldFieldId) {
            item[4] = addNew;
          }
        });
        popItem[4] = addNew;
        let _tempItem = Object.assign({}, popItem);
        iacRedoHistory(model, _tempItem, "itemRemoved");
      }
    }

    if (temp_undo_location_specs.length == 0) {
      handleActionButtonStyle("iac_undo_button", "inactive");
    }
    return fieldState;
  }
  return null;
}

async function iacRedo(model) {
  let { temp_redo_location_specs } = model;
  if (temp_redo_location_specs.length > 0) {
    let lastItemAction =
      temp_redo_location_specs[temp_redo_location_specs.length - 1];
    let fieldState = null;
    if (lastItemAction.action == "updateFillType") {
      let field = {
        id: lastItemAction[4],
        __field_id: lastItemAction[4],
        fill_type: 0,
        field_type: 1,
        location: {
          values: [
            lastItemAction[0],
            lastItemAction[1],
            lastItemAction[2],
            lastItemAction[3],
            lastItemAction[5],
            lastItemAction[6],
          ],
        },
      };

      if (lastItemAction.fill_type) {
        field.fill_type = lastItemAction.fill_type;
      }
      if (lastItemAction.field_type) {
        field.field_type = lastItemAction.field_type;
      }
      let oldFillType = model.fieldState[lastItemAction[4]].fill_type;
      let oldFieldType = model.fieldState[lastItemAction[4]].field_type;

      fieldState = await iacModelUpdateField(model, field, false);
      if (fieldState) {
        let popItem = temp_redo_location_specs.pop();
        let _tempItem = Object.assign({}, popItem);
        _tempItem.fill_type = oldFillType;
        _tempItem.field_type = oldFieldType;
        iacUndoHistory(model, _tempItem, "updateFillType");
      }
    } else if (lastItemAction.action == "newAdd") {
      let popItem = temp_redo_location_specs.pop();
      let oldFieldId = popItem[4];
      let addNew = await iacModelAddField(model, popItem);
      if (addNew) {
        temp_redo_location_specs.forEach((item) => {
          if (item[4] == oldFieldId) {
            item[4] = addNew;
          }
        });
      }
    } else if (lastItemAction.action == "itemRemoved") {
      let popItem = temp_redo_location_specs.pop();
      let field = { __field_id: popItem[4] };
      fieldState = await iacModelRemoveField(model, field, false);
      let _tempItem = Object.assign({}, popItem);
      iacUndoHistory(model, _tempItem, "itemRemoved");
    }

    if (temp_redo_location_specs.length == 0) {
      handleActionButtonStyle("iac_redo_button", "inactive");
    }
    return fieldState;
  }
  return null;
}

async function iacModelAddField(model, field, flag = true) {
  let fieldType = field[5];
  let pageNumber = field[6];
  let baseX = field[0];
  let finalX = field[1];
  let baseY = field[2];
  let finalY = field[3];
  let fill_type = field.fill_type || 0;
  if (model.version === 1 && fill_type === 0) {
    fill_type = FILL_TYPE_RECIPIENT;
  }
  let newIdReply = await iacAddField(
    model.iacDocument.id,
    fieldType,
    baseX,
    baseY,
    finalX,
    finalY,
    pageNumber,
    fill_type
  );
  if (newIdReply.ok) {
    // Add to the location_spec list
    let newIdR = await newIdReply.json();
    let ls = [baseX, finalX, baseY, finalY, newIdR.id, fieldType, pageNumber];
    let field = newIdR.field;

    model.location_specs.push(ls);
    if (flag) {
      iacUndoHistory(model, ls, "newAdd");
    }
    model.fieldState[newIdR.id] = makeFieldState(
      field,
      MODE_SETUP,
      model.sesMode
    );
    if (fieldType == 1) {
      model.fieldState[newIdR.id].label_question_type = "shortAnswer";
    } else if (fieldType == 2) {
      model.fieldState[newIdR.id].label_question_type = "checkbox";
    }
    await iacSwitchOperationMode(model, MODE_SETUP);
    model.setupActiveField = newIdR.id;
    iacActiveFieldHandler(model, newIdR.id);

    _iacFieldClick(model, newIdR.id);
    return newIdR.id;
  } else {
    let error = await newIdReply.json();
    showErrorMessage("iac", error.error);

    // Revert back to SETUP_MODE
    await iacSwitchOperationMode(model, MODE_SETUP);
  }
  return null;
}

function inputFakerFocus(model, fd) {
  let f = model.fill.inputFaker;

  if (f != null && fd.field_type == 1) {
    f.style = "opacity: 0; position: fixed; z-index: 0;";
    f.focus();
  }
}

/* Events */

function iacModelHandleClick(model, offsetX, offsetY, fieldId) {
  if (model.fill.enabled) {
    let fd = model.fieldState[fieldId];
    if (isAndroidMobile() && fd.editable) {
      model.fill.activeField = fieldId;

      inputFakerFocus(model, fd);
      /* Disable this functionality for Android devices */
      model.fill.textMarker.charIndex = fd.text_charStack.length;
      iacToggleTextMarker(model);
    } else {
      if (fd.editable) {
        model.fill.activeField = fieldId;

        inputFakerFocus(model, fd);

        /* figure out where the click was  */
        iacDebug(`click was +x ${offsetX} +y ${offsetY} in the field`);
        let fontSize = fd.text_fontSize;

        if (fontSize == 0 || fd.text_charStack.length == 0) {
          iacDebug(
            `BestGuessCharIndex @ 0 because fontSize=${fontSize} cs_len=${fd.text_charStack.length}`
          );
          model.fill.textMarker.charIndex = 0;
        } else {
          let [bestGuessCharIndex, bestGuessFound, rowIndex, columnIndex] =
            getBestGuessCharIndex(model, fieldId, offsetX, offsetY, true);

          model.fill.textMarker.charIndex = bestGuessCharIndex;
          model.fill.textMarker.rowIndex = rowIndex;
          model.fill.textMarker.columnIndex = columnIndex;
          if (bestGuessFound) {
            let theChar = fd.text_charStack[bestGuessCharIndex];
            iacDebug(
              `BestGuessCharIndex @ ${bestGuessCharIndex}, before ${theChar}`
            );
          } else {
            iacDebug(
              `BestGuessCharIndex @ ${bestGuessCharIndex}, at the end of line`
            );
          }

          model.fill.textMarker.charIndex = bestGuessCharIndex;
        }

        // update textmarker immediately
        iacToggleTextMarker(model);
      }
    }
  }

  _iacFieldClick(model, fieldId);
}

function _iacFieldClick(model, fieldId) {
  for (const fu of model.events.fieldClick) {
    fu(model, fieldId);
  }
}

function getBestGuessCharIndex(
  model,
  fieldId,
  offsetX,
  offsetY,
  DEBUG = false
) {
  let fd = model.fieldState[fieldId];
  let fontSize = fd.text_fontSize;
  let canvas = model.render.canvas;
  let context = canvas.getContext("2d");
  context.font = `${fontSize}px sans-serif`;
  /* there is text in the field, figure out where we cliecked */
  let bestGuessCharIndex = 0;
  let bestGuessFound = false;
  let stringSoFar = "";
  let locationSpec = makeLocationSpec(fd);
  let maxWidth =
    Math.abs(locationSpec[1] - locationSpec[0]) * model.viewport.width - 10;

  iacDebug(
    `BestGuessCharIndex trying to find fontSize=${fontSize} cs_len=${fd.text_charStack.length} offsetX=${offsetX} offsetY=${offsetY}`
  );

  if (fd.allow_multiline) {
    let line = "";
    let words = fd.text_charStack.join("").split(" ");
    let rowIndex = 0;
    let foundRow = false;
    for (const word of words) {
      if (context.measureText(line + word).width > maxWidth) {
        rowIndex++;
        if ((rowIndex * fontSize) / model.viewport.height > offsetY) {
          foundRow = true;
          break;
        }
        bestGuessCharIndex += line.length;
        line = "";
      }

      line += word + " ";
    }

    if (!foundRow) {
      rowIndex++;
    }
    iacDebug(
      `BestGuessCharIndex: rowIndex ${rowIndex} index: ${bestGuessCharIndex}`
    );

    let startOfRow = bestGuessCharIndex;

    // now that we know where it begins - let's fire up the rest of the code to find it in the row
    for (let i = bestGuessCharIndex; i <= fd.text_charStack.length; i++) {
      let textDims = context.measureText(stringSoFar);
      let textWidth = textDims.width;
      iacDebug(
        `BestGuessCharIndex i=${i} textWidth=${textWidth} (${
          textWidth / model.viewport.width
        }) stringSoFar=${stringSoFar}`
      );

      if (textWidth / model.viewport.width < offsetX) {
        bestGuessCharIndex = i;
      } else {
        bestGuessFound = true;
        break;
      }

      if (i != fd.text_charStack.length)
        stringSoFar = stringSoFar + fd.text_charStack[i];
    }

    if (DEBUG) {
      return [
        bestGuessCharIndex,
        bestGuessFound,
        rowIndex,
        bestGuessCharIndex - startOfRow,
      ];
    }
    return bestGuessCharIndex;
  } else {
    for (let i = 0; i <= fd.text_charStack.length; i++) {
      let textDims = context.measureText(stringSoFar);
      let textWidth = textDims.width;
      iacDebug(
        `BestGuessCharIndex i=${i} textWidth=${textWidth} (${
          textWidth / model.viewport.width
        }) stringSoFar=${stringSoFar}`
      );

      if (textWidth / model.viewport.width < offsetX) {
        bestGuessCharIndex = i;
      } else {
        bestGuessFound = true;
        break;
      }

      if (i != fd.text_charStack.length)
        stringSoFar = stringSoFar + fd.text_charStack[i];
    }
  }
  if (DEBUG) {
    return [bestGuessCharIndex, bestGuessFound, 1, 0];
  }
  return bestGuessCharIndex;
}

/* Helpers */

function iacFindFieldByLocation(model, rX, rY) {
  for (const spec of model.location_specs) {
    if (rX >= spec[0] && rX <= spec[1] && rY >= spec[2] && rY <= spec[3]) {
      // found the field that we clicked on
      // spec[4] has the field id, so we use that to find the field to focus

      if (model.multipage.enabled && model.multipage.currentPage == spec[6]) {
        return spec;
      } else if (!model.multipage.enabled) {
        return spec;
      }
    }
  }

  return null;
}

function signatureEditable(field, operationMode) {
  console.log(`signatureEditable for ${field.id}`);
  console.log(`field.signature_info: ${field.signature_info}`);
  let ret = false;
  if (field.signature_info != undefined && field.signature_info.data == "") {
    ret = true;
  } else if (operationMode == MODE_REQUESTOR_FILL) {
    ret = true;
  } else if (operationMode == MODE_REVIEW) {
    ret =
      field.signature_info != undefined && field.signature_info.data != ""
        ? false
        : true;
  } else {
    console.log(field.signature_info != undefined);
    console.log(field.signature_info.data != "");
    console.log(!field.signature_info.requestor_filled);
    ret =
      field.signature_info != undefined &&
      field.signature_info.data != "" &&
      !field.signature_info.requestor_filled;
  }
  console.log(` -> ret ${ret}`);
  return ret;
}

const isEmptyOrNullFields = (value) => {
  return value === "" || value === null || value === "false";
};

function iacModelFillableField(mft, op, field, sesMode) {
  if (field.type == 4) return false;
  if (sesMode) return true;

  if (op != MODE_SETUP && field.fill_type != 0 && field.fill_type != mft) {
    return false;
  }

  if (field.type != 3) {
    if (op === MODE_REVIEW) {
      // fields allocated for review fill
      if (field.fill_type === 2) {
        return true;
      }
      // Allow fields to be edited if values not set
      const defaultValues = isEmptyOrNullFields(field.default_value); // for fill type 0; if prefilled sets as default value
      const textBoxValues =
        field.type === 1 ? isEmptyOrNullFields(field.set_value) : false;
      const checkboxValues =
        field.type === 2 ? isEmptyOrNullFields(field.set_value) : false;
      return defaultValues && (textBoxValues || checkboxValues);
    }
    return (
      field.default_value == "" ||
      field.default_value == null ||
      op == MODE_SETUP ||
      op == MODE_REQUESTOR_FILL
    );
  } else {
    return signatureEditable(field, op);
  }
}

function makeFieldState(field, operationMode, sesMode) {
  try {
    let mft = iacModelFillType(operationMode);
    let charStack = [];
    let checked = false;
    let sigInfo = {};
    if (field.type == 1) {
      if (field.set_value != null && field.set_value != "") {
        /* Initialize text specific items in the state */
        for (let i = 0; i < field.set_value.length; i++) {
          charStack.push(field.set_value.charAt(i));
        }
      } else if (
        (mft === field.fill_type || field.fill_type === 0) &&
        field.default_value != null &&
        field.default_value != undefined &&
        field.default_value != ""
      ) {
        /* Initialize text specific items in the state */
        for (let i = 0; i < field.default_value.length; i++) {
          charStack.push(field.default_value.charAt(i));
        }
      }
    } else if (field.type == 2) {
      /* Checkbox */
      checked = field.set_value == "true";
    } else if (field.type == 3) {
      let rawSigInfo = field.signature_info;
      /* Signature */
      if (rawSigInfo != undefined) {
        sigInfo = {
          filled: rawSigInfo.data != "",
          auditStart: null,
          auditEnd: null,
          signatureData: rawSigInfo.data,
          requestor_filled: rawSigInfo.requestor_filled,
        };
      } else {
        sigInfo = {
          filled: false,
          auditStart: null,
          auditEnd: null,
          signatureData: null,
          requestor_filled: false,
        };
      }
    } else if (field.type == 4) {
      /* Table (export only) */
      // do nothing
    } else {
      /* Unknown */
      alert(
        "Encountered an unknown field type, some issues may occur: " +
          field.type
      );
    }

    return {
      __field_id: field.id,
      id: field.id,
      type: field.type,
      fullyInitialized: false,
      defaultImageData: null,
      text_charStack: charStack,
      text_fontSize: 0,
      checkbox_checked: checked,
      location: field.location,
      set_value: field.set_value,
      default_value: field.default_value,
      fill_type: field.fill_type,
      editable: iacModelFillableField(mft, operationMode, field, sesMode),
      field_type: field.type,
      signature_info: sigInfo,
      highlighted: false,
      label: field.label,
      label_value: field.label_value,
      label_question: field.label_question,
      label_question_type: field.label_question_type,
      repeat_entry_form_id: field.repeat_entry_form_id,
      allow_multiline: field.allow_multiline,
      charLimit: TEXT_FIELD_LENGTH_LIMIT,
      maxRows: 0,
    };
  } catch (err) {
    console.log("caught error while making field state ...");
    console.error(err);
    throw err;
  }
}

function implodeFieldStates(acc, x) {
  acc[x.__field_id] = x;

  return acc;
}

export function iacAddFieldClickHook(model, fu) {
  model.events.fieldClick.push(fu);
}

/* Secondary entrypoint, prepares an existing model for location selection, for a new field */
function iacStartLocationSelect(model, fieldType) {
  model.locationSelect.fieldType = fieldType;
  iacSwitchOperationMode(model, MODE_LOCATION_SELECT);
}

async function iacSwitchOperationMode(model, new_op) {
  iacDebug(`Switching operation mode from ${model.operationMode} to ${new_op}`);
  model.operationModeChange = true;
  model.operationMode = new_op;
  model.render.canvasRendered = false;
  model.render.renderHooks = defaultHooks[new_op];
  model.render.renderHooksDone = false;
  // model.events.fieldClick = [];
  _iacResetCanvasHooks(model);
  model.render.eventHooks = [];
  model.render.windowHooks = [];
  model.render.canvas.style.cursor = "crosshair";
  await iacRender(model, model.render.canvas);

  model.operationModeChange = false;
}

export async function iacModelRemoveField(model, field, flag = true) {
  let fieldId = field.__field_id;

  iacLoadingState.set(true);

  // tell the API
  let reply = await iacRemoveField(model.iacDocument.id, fieldId);
  if (reply.ok) {
    let canvas = model.render.canvas;
    let context = canvas.getContext("2d");

    if (flag) {
      let { fill_type } = model.fieldState[fieldId];
      let item = model.location_specs.find((x) => x[4] == fieldId);
      item.fill_type = fill_type;
      let _tempItem = Object.assign({}, item);
      iacUndoHistory(model, _tempItem, "itemRemoved");
    }
    // remove from location_specs
    model.location_specs = model.location_specs.filter((x) => x[4] != fieldId);

    // make new orderedSpecs
    model.fill.orderedSpecs = makeOrderedSpecs(model.location_specs);

    // remove from fieldState
    delete model.fieldState[fieldId];

    // rerender the scene
    await iacRender(model, model.render.canvas);

    model.stopHiglightListener = true;

    model.locationSelect.pdfData = context.getImageData(
      0,
      0,
      model.viewport.width,
      model.viewport.height
    );
    model.stopHiglightListener = false;

    model.setupActiveField = null;

    iacLoadingState.set(false);

    return "removed";
  } else {
    let error = await reply.json();
    showErrorMessage("iac", error.error);
    iacLoadingState.set(false);
  }
  return null;
}

export async function iacModelUpdateField(model, field, flag = true) {
  let fieldId = field.__field_id;
  let specIndex = model.location_specs.findIndex((elem) => {
    return elem[4] == field.__field_id;
  });
  let oldFillType = model.fieldState[fieldId].fill_type;
  let oldFieldType = model.fieldState[fieldId].field_type;

  iacLoadingState.set(true);

  let reply = await iacUpdateField(model.iacDocument.id, fieldId, {
    fill_type: field.fill_type,
    field_type: field.field_type,
    label: field.label,
    label_value: field.label_value,
    label_question: field.label_question,
    label_question_type: field.label_question_type,
    allow_multiline: field.allow_multiline,
  });
  if (reply.ok) {
    let canvas = model.render.canvas;
    let context = canvas.getContext("2d");
    let res = await reply.json();
    let _field = res.field;
    let spec = model.location_specs[specIndex];
    // update model
    let fieldState = makeFieldState(_field, MODE_SETUP, model.sesMode);
    model.location_specs[specIndex][5] = fieldState.field_type;
    model.fieldState[fieldId] = fieldState;
    // redraw the field, nuke it
    // XXX: This is a terrible hack, we should redraw the field.
    //      Issue is that iacRedrawField isn't responsible for drawing
    //      the background text, it's a hook.

    await iacRender(model, model.render.canvas);

    model.stopHiglightListener = true;

    iacInitFieldDescriptor(model, spec, fieldId);
    model.locationSelect.pdfData = context.getImageData(
      0,
      0,
      model.viewport.width,
      model.viewport.height
    );
    model.stopHiglightListener = false;
    model.setupActiveField = fieldId;
    iacActiveFieldHandler(model, fieldId);

    if (model.showFieldInformation) {
      model.showFieldInformation(model, fieldId);
    }

    if (flag) {
      spec.fill_type = oldFillType;
      spec.field_type = oldFieldType;
      let _tempItem = Object.assign({}, spec);
      iacUndoHistory(model, _tempItem, "updateFillType");
    }

    iacLoadingState.set(false);

    return model.fieldState[fieldId];
  } else {
    iacLoadingState.set(false);

    let error = await reply.json();
    showErrorMessage("iac", error.error);
  }
  return null;
}

function makeLocationSpec(field) {
  var lv1 = field.location.values[0];
  var lv2 = field.location.values[1];
  var lv3 = field.location.values[2];
  var lv4 = field.location.values[3];
  var page_no = field.location.values[5];
  var lv5 = field.id;
  var lv6 = field.type;
  var bX = Math.min(lv2, lv2 + lv3);
  var fX = Math.max(lv2, lv2 + lv3);
  var bY = Math.min(lv1, lv1 + lv4);
  var fY = Math.max(lv1, lv1 + lv4);
  // spec[0] relative baseX
  // spec[1] relative finalX
  // spec[2] relative baseY
  // spec[3] relative finalY
  // spec[4] concrete fieldId
  // spec[5] concrete fieldType
  // spec[6] concrete pageNumber
  if (lv6 == 4) {
    console.log({ msg: "makeLocationSpec/tableDebug", field });
  }
  return [bX, fX, bY, fY, lv5, lv6, page_no];
}

export function iacModelSetRecipient(model, recipientId) {
  model.recipientId = recipientId;
}

export function iacModelSetAssignment(model, assignmentId) {
  model.assignmentId = assignmentId;
}

export function iacModelSetContents(model, contentsId) {
  model.contentsId = contentsId;
}

export function iacModelSetInputFaker(model, f) {
  model.fill.inputFaker = f;
}

export async function iacModelSetEsignConsent(model, consent_info) {
  let r = await consent_info;

  model.esign.consented = r.consented;
  model.esign.has_saved_sig = r.has_saved_signature;
  model.esign.saved_sig = r.saved_signature;
}

/* Create a data format suitable for processing by the API */
export function iacPrepareModelSubmission(model) {
  let fields = model.fieldState
    .filter((field) => field.field_type != 3) // signatures are handled separately
    .filter((field) => field.fullyInitialized) // only include fields that may have changed
    .map((field) => {
      let field_value = "";
      if (field.field_type == 1) {
        /* text */
        field_value = field.text_charStack.join("");
      } else if (field.field_type == 2) {
        /* checkbox */
        field_value = field.checkbox_checked ? "true" : "false";
      } else if (field.field_type == 4) {
        /* table */
        // do nothing
      } else {
        /* something else */
        console.error(
          `Unhandled field type in iacPrepareModelSubmission: ${field.field_type}`
        );
      }
      return {
        field_id: field.id,
        field_value: field_value,
      };
    });

  return {
    type:
      model.operationMode == MODE_RECIPIENT_FILL
        ? "recipient"
        : model.operationMode == MODE_REVIEW
        ? "review"
        : "requestor",
    iacDocId: model.iacDocument.id,
    recipientId: model.recipientId,
    assignmentId:
      model.operationMode == MODE_RECIPIENT_FILL
        ? model.assignmentId
        : model.contentsId,
    fields: fields,
    sesMode: model.sesMode,
    editMode: model.editMode,
  };
}

function iacModelBeginTransaction(model) {
  let txId = 0;
  do {
    txId = Math.floor(Math.random() * 133713371337);
  } while (model.transactionsInProgress.includes(txId));

  model.transactionsInProgress.push(txId);

  console.log(`[IACAtomic] Begin transaction ID ${txId}`);
  return txId;
}

function iacModelToggleFieldIds(model) {
  // Toggle the debug tracker
  model.debug.debugUsed = true;
  model.debug.__showFieldIds = !model.debug.__showFieldIds;

  // Rerender to allow the toggle to take effect
  iacRender(model, model.render.canvas);
}

function iacModelEndTransaction(model, txId) {
  if (model.transactionsInProgress.includes(txId)) {
    model.transactionsInProgress = model.transactionsInProgress.filter(
      (x) => x != txId
    );
  } else {
    console.error(
      `[IACAtomic] End transaction failed for id ${txId}, inProgress: ${model.transactionsInProgress}`
    );
    return false;
  }

  console.log(`[IACAtomic] End transaction ID ${txId}`);
  return true;
}

function iacModelFillType(operationMode) {
  let model_fill_type =
    operationMode == MODE_RECIPIENT_FILL
      ? 3
      : operationMode == MODE_REQUESTOR_FILL
      ? 1
      : operationMode == MODE_REVIEW
      ? 2
      : 0;

  return model_fill_type;
}

function iacModelReadyToSubmit(model) {
  return model.transactionsInProgress.length == 0;
}

function iacMapFieldsInOrder(model, func) {
  let result = [];
  for (let i = 0; i < model.fill.orderedSpecs.length; i++) {
    let orderedSpec = model.fill.orderedSpecs[i];
    let fieldId = orderedSpec[4];
    let field = model.fieldState[fieldId];

    result.push(func(field));
  }

  return result;
}

function makeOrderedSpecs(location_specs) {
  let orderedSpecs = location_specs;
  orderedSpecs.sort((f, s) => {
    // sort by page
    if (f[6] < s[6]) {
      return -1;
    }
    if (f[6] > s[6]) {
      return 1;
    }
    if (f[6] == s[6]) {
      // sort by baseY's 10%
      let fY = Math.floor(f[2] * 100);
      let sY = Math.floor(s[2] * 100);
      if (fY < sY) {
        return -1;
      }
      if (fY > sY) {
        return 1;
      }
      if (fY == sY) {
        // sort by baseX's 10%
        let fX = Math.floor(f[0] * 100);
        let sX = Math.floor(s[0] * 100);
        if (fX < sX) {
          return -1;
        }
        if (fX > sX) {
          return 1;
        }
        if (fX == sX) {
          return 0;
        }
      }
    }
  });

  return orderedSpecs;
}

/*
 * Main entrypoint, queries the API for the fields, constructs the model
 * and returns it
 */
function iacInitializeModel(iacDocument, operationMode, sesMode = false) {
  let fields = iacDocument.fields;
  window.defaultHooks = defaultHooks;
  let location_specs = fields
    .filter((field) => field.location.type == 1)
    .map(makeLocationSpec);

  let orderedSpecs = makeOrderedSpecs(location_specs);

  let model = {
    iacDocument: iacDocument,
    recipientId: null,
    assignmentId: null,
    contentsId: null,
    operationMode: operationMode,
    operationModeChange: false,
    multipage: {
      enabled: true,
      pageCount: 0,
      currentPage: 0,
      pdfObject: undefined,
    },
    viewport: {
      width: 0,
      height: 0,
      scale: 5,
    },
    render: {
      canvas: null /* set when first rendered */,
      canvasRendered: false,
      pageCanvases: [],
      renderHooks: defaultHooks[operationMode],
      renderHooksDone: false,
      eventHooks: [],
      windowHooks: [],
      isLoading: false,
    },
    highlightedField: null,
    setupActiveField: null,
    fill: {
      type: iacModelFillType(operationMode),
      enabled:
        operationMode == MODE_RECIPIENT_FILL ||
        operationMode == MODE_REVIEW ||
        operationMode == MODE_REQUESTOR_FILL,
      activeField: null,
      textMarker: {
        enabled: true, // Is the textmarker enabled?
        visible: false, // is it visible in @field currently?
        field: null, // the active field
        charIndex: 0, // *AFTER* which character is the textMarker, 0 if at the very left.
        rowIndex: 0,
        columnIndex: 0,
        color: "#606972", // color of the textmarker
        interval: 500, // interval at which to blink
        textWidth: 0, // width of the textMarker
      },
      orderedSpecs: orderedSpecs,
      currentTabIndex: -1,
      inputFaker: null,
    },
    esign: {
      consented: false,
      has_saved_sig: false,
      saved_sig: "",
    },
    locationSelect: {
      lastMouseX: 0,
      lastMouseY: 0,
      mouseDown: false,
      pdfData: null,
      fieldType: 0,
      finalMouseX: 0,
      finalMouseY: 0,
    },
    textSelect: {
      lastMouseX: 0,
      lastMouseY: 0,
      startIndex: 0,
      endIndex: 0,
      mouseDown: false,
      select: false,
    },
    resizeLocationSelect: {
      lastMouseX: 0,
      lastMouseY: 0,
      mouseDown: false,
      pdfData: null,
      fieldType: 0,
      finalMouseX: 0,
      finalMouseY: 0,
      fieldId: null,
      fillType: null,
      pageNumber: null,
    },
    assert: {
      failed: false,
    },
    events: {
      fieldClick: [],
    },
    tables: {
      empty: [],
    },
    transactionsInProgress: [],
    temp_undo_location_specs: [],
    temp_redo_location_specs: [],
    location_specs: location_specs,
    fieldState: fields
      .map((x) => makeFieldState(x, operationMode, sesMode))
      .reduce(implodeFieldStates, []),
    sesMode: sesMode, // Single Entry System: used for single-entry form filling
    debug: {
      generateSubmissionData: (model) => {
        model.debug.debugUsed = true;
        return iacPrepareModelSubmission(model);
      },
      toggleFieldIds: (model) => {
        iacModelToggleFieldIds(model);
        if (model.debug.__showFieldIds) {
          console.log("[IAC/debug] Now showing fieldIds");
        } else {
          console.log("[IAC/debug] Now hidden fieldIds");
        }
        return model.debug.__showFieldIds;
      },
      __showFieldIds: false,
      debugUsed: false,
    },
    version: iacDocument.version,
  };

  return model;
}

/* Destroy the model by removing all global handlers. */
function iacModelDestroy(model) {
  /* Reset the hooks  */
  _iacResetCanvasHooks(model);
}

export {
  iacInitializeModel,
  iacStartLocationSelect,
  iacModelDestroy,
  iacUndo,
  iacRedo,
  iacSwitchOperationMode,
  iacMapFieldsInOrder,
};
