import { iacDebug } from "Helpers/Debug";
import { isAndroidMobile } from "Helpers/util";
import { iacAssertEq } from "IAC/Assert";
import { transformKeydownEvent, transformInputEvent } from "IAC/Input";

// XXX: Some Webpack guru please help me understand why import doesn't work here.
//      I literally spent 4am-6:30am figuring this out.
//let pdfjsLib = require("pdfjs-dist");
const FILL_TYPE_ANYONE = 0;
const FILL_TYPE_REQUESTOR_BEFORE = 1;
const FILL_TYPE_REQUESTOR_AFTER = 2;
const FILL_TYPE_RECIPIENT = 3;

const MODE_SETUP = 1;
const MODE_LOCATION_SELECT = 3;
// Hook types
const HOOK_TYPE_ONCE = 1; // Execute once per canvas (not called again during page-switch)]
const HOOK_TYPE_ALWAYS = 2; // Execute always after a render

// Configuration
const CONFIG_DRAW_TRIANGLE = false; // Draw triangle SIGN HERE?
const FONT_STYLE = {
  bold: "bold",
  italic: "italic",
};
const TEXT_SIGN_FIELD_TYPE = [1, 3]; // contains fieldType for Text and Signature.
const IAC_FILL_TYPE = {
  ANYONE: 0,
  REQUESTOR_BEFORE: 1,
  REQUESTOR_AFTER: 2,
  CLIENT: 3,
};
const IAC_FIELD_TYPE = {
  TEXT: 1,
  CHECKBOX: 2,
  SIGNATURE: 3,
  TABLE: 4,
};

export const IAC_MODE = {
  REQUESTOR_FILL: 2,
  RECIPIENT_FILL: 4,
  REVIEW: 5,
};

// this arrays match the index with IAC_FILL_TYPE
const IAC_FIELD_PREFIX = ["UNKNOWN", "TEXT", "CHECKBOX", "SIGNATURE", "TABLE"];
const IAC_FIELD_SUFFIX = [" / ANYONE", " / BEFORE", " / AFTER", " / CLIENT"];

const getFieldPrefix = (fieldType) => {
  const checkFieldType = Object.values(IAC_FIELD_TYPE).includes(fieldType);
  if (!checkFieldType) return "UNKNOWN";
  else return IAC_FIELD_PREFIX[fieldType];
};

const getFieldSuffix = (fillType) => {
  const checkFillType = Object.values(IAC_FILL_TYPE).includes(fillType);
  if (!checkFillType) return "UNKNOWN";
  else return IAC_FIELD_SUFFIX[fillType];
};

const getFieldPlaceholder = (fieldType, fillType) => {
  return getFieldPrefix(fieldType) + getFieldSuffix(fillType);
};

function iacRenderLoadingScreen(canvas) {
  let context = canvas.getContext("2d");
  let loadingText = "Loading your document, please wait.";

  console.log(loadingText);
  canvas.width = 1024;
  let fontSize = 36;
  context.font = `${fontSize}px sans-serif`;
  context.fillStyle = "rgba(0, 0, 0)";
  // draw the text
  let tM = context.measureText(loadingText);
  context.fillText(
    loadingText,
    canvas.width / 2 - tM.width / 2,
    canvas.height / 2
  );
}

function iacFirstRender(iacModel, canvas) {
  let pdfjsLib = window["pdfjs-dist/build/pdf"];
  pdfjsLib.GlobalWorkerOptions.workerSrc =
    "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.9.359/pdf.worker.min.js";
  let url = `/iac/${iacModel.iacDocument.id}/download`;
  iacModel.render.canvas = canvas;
  let loadingTask = pdfjsLib.getDocument(url);

  return new Promise(async (resolve, error) => {
    try {
      let pdf = await loadingTask.promise;

      if (iacModel.multipage.enabled) {
        // get the number of pages
        iacModel.multipage.pageCount = pdf.numPages;
        iacModel.multipage.pdfObject = pdf;
      }

      let page = await pdf.getPage(iacModel.multipage.currentPage + 1);

      var scale = iacModel.viewport.scale;

      var viewport = page.getViewport({ scale: scale });

      canvas.height = viewport.height;
      canvas.width = viewport.width;
      iacModel.viewport.width = viewport.width;
      iacModel.viewport.height = viewport.height;
      canvas.style.width = "100%";
      let context = canvas.getContext("2d");

      var renderContext = {
        canvasContext: context,
        viewport: viewport,
      };

      await page.render(renderContext).promise;

      iacDebug("IAC Canvas finished rendering");
      iacModel.render.canvasRendered = true;
      if (iacModel.render.renderHooks != undefined) {
        for (let f of iacModel.render.renderHooks) {
          iacDebug(`iacRender: executing hook ${f.id}`);
          f.fu(iacModel);
          iacDebug(`iacRender: done executing hook ${f.id}`);
        }
      }
      iacModel.render.renderHooksDone = true;

      resolve(iacModel);
    } catch (e) {
      console.error("pdf loading error on iacFirstRender: error", e);
      error(e);
    }
  });
}

function iacReRender(iacModel) {
  let displayCanvas = iacModel.render.canvas;
  let pdf = iacModel.multipage.pdfObject;

  // save locally, so we can access it during the promise
  let operationModeChange = iacModel.operationModeChange;

  return new Promise(async (resolve, error) => {
    try {
      if (
        iacModel.render.pageCanvases[iacModel.multipage.currentPage] !=
        undefined
      ) {
        let displayContext = displayCanvas.getContext("2d");
        displayContext.drawImage(
          iacModel.render.pageCanvases[iacModel.multipage.currentPage],
          0,
          0
        );
        iacDebug(
          `IAC page canvas for page ${iacModel.multipage.currentPage} grabbed from Cache`
        );
      } else {
        var canvas = document.createElement("canvas");
        let page = await pdf.getPage(iacModel.multipage.currentPage + 1);

        var scale = iacModel.viewport.scale;
        var viewport = page.getViewport({ scale: scale });
        canvas.height = viewport.height;
        canvas.width = viewport.width;
        iacModel.viewport.width = viewport.width;
        iacModel.viewport.height = viewport.height;
        canvas.style.width = "100%";
        let context = canvas.getContext("2d");

        var renderContext = {
          canvasContext: context,
          viewport: viewport,
        };

        await page.render(renderContext).promise;
        iacModel.render.pageCanvases[iacModel.multipage.currentPage] = canvas;
        let displayContext = displayCanvas.getContext("2d");
        displayContext.drawImage(canvas, 0, 0);
      }

      iacDebug(
        `IAC Canvas finished re-rendering, operationModeChange=${operationModeChange}`
      );
      iacModel.render.canvasRendered = true;
      if (iacModel.render.renderHooks != undefined) {
        for (let f of iacModel.render.renderHooks) {
          if (f.type == HOOK_TYPE_ALWAYS || operationModeChange) {
            iacDebug(`iacReRender: executing hook ${f.id}`);
            f.fu(iacModel);
            iacDebug(`iacReRender: done executing hook ${f.id}`);
          } else {
            iacDebug(`iacReRender: skipped executing hook ${f.id}`);
          }
        }
      }
      iacModel.render.renderHooksDone = true;
      iacModel.render.isLoading = false;

      resolve(iacModel);
    } catch (e) {
      console.error("iacReRender: error", e);
      error(e);
    }
  });
}

function iacRender(iacModel, canvas) {
  if (iacModel.render.canvas == null) {
    return iacFirstRender(iacModel, canvas);
  } else {
    return iacReRender(iacModel);
  }
}

function iacAddCanvasRenderHook(model, id, f) {
  let render = model.render;
  if (render.renderHooks == undefined) {
    iacDebug(
      `iacAddCanvasRenderHook: adding ${id}, resulted in hook structure being initialized`
    );
    render.renderHooks = [];
  }

  if (render.canvasRendered) {
    iacDebug(
      `iacAddCanvasRenderHook: adding ${id} failed, because canvas is up already`
    );
    f(model);
  } else {
    iacDebug(`iacAddCanvasRenderHook: added ${id} to hooks`);
    render.renderHooks.push({ id: id, fu: f });
  }
}

function iacDrawBaseHighlight(model, spec) {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  let fieldId = spec[4];

  // Only highlight editable fields
  if (!model.fieldState[fieldId].editable) return;

  var startX = spec[0] * model.viewport.width;
  var startY = spec[2] * model.viewport.height;
  var endX = spec[1] * model.viewport.width;
  var endY = spec[3] * model.viewport.height;
  var width = Math.abs(endX - startX);
  var height = Math.abs(endY - startY);

  /* draw the highlight */
  var prevFillStyle = context.fillStyle;
  if (model.fieldState[fieldId].type == 3) {
    context.fillStyle = "rgba(255, 174, 168, 40%)";
  } else {
    context.fillStyle = "rgba(158, 158, 158, 20%)";
  }
  context.fillRect(startX, startY, width, height);
  context.fillStyle = prevFillStyle;

  var prevStrokeStyle = context.strokeStyle;
  var prevLineWidth = context.lineWidth;
  context.strokeStyle = "rgba(255, 0, 0, 100%)";
  context.lineWidth = 6;
  context.strokeRect(startX, startY, width, height);
  context.strokeStyle = prevStrokeStyle;
  context.lineWidth = prevLineWidth;
}

function iacDrawBaseBorderHighlight(model, spec, hasValue) {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  let fieldId = spec[4];
  let fieldType = spec[5];

  if (!model.fieldState[fieldId].editable) {
    if (
      model.operationMode === IAC_MODE.REQUESTOR_FILL &&
      TEXT_SIGN_FIELD_TYPE.includes(fieldType) &&
      !model.fieldState[fieldId].typeInfoAdded
    ) {
      let fillType = model.fieldState[fieldId].fill_type;
      const fieldPlaceholder = getFieldPlaceholder(fieldType, fillType);
      drawFieldPlaceholder(model, spec, fieldPlaceholder, FONT_STYLE.italic);
      model.fieldState[fieldId].typeInfoAdded = true;
    }
    return;
  }

  var startX = spec[0] * model.viewport.width;
  var startY = spec[2] * model.viewport.height;
  var endX = spec[1] * model.viewport.width;
  var endY = spec[3] * model.viewport.height;
  var width = Math.abs(endX - startX);
  var height = Math.abs(endY - startY);

  var prevStrokeStyle = context.strokeStyle;
  var prevLineWidth = context.lineWidth;
  if (hasValue) {
    context.strokeStyle = "rgba(0, 0, 0, 100%)";
  } else {
    context.strokeStyle = "rgba(255, 0, 0, 100%)";
  }
  context.lineWidth = 6;
  context.strokeRect(startX, startY, width, height);
  context.strokeStyle = prevStrokeStyle;
  context.lineWidth = prevLineWidth;
}

const drawFieldPlaceholder = (model, spec, finalText, fontStyle = "") => {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  let fieldId = spec[4];

  const fieldHeight = Math.abs(spec[3] - spec[2]) * model.viewport.height;
  const fieldWidth =
    Math.abs(spec[1] - spec[0]) * model.viewport.width - 4 * context.lineWidth;
  const fontSize = Math.floor(fieldHeight * 0.6);
  let bX = spec[0] * model.viewport.width,
    bY = Math.min(spec[2], spec[3]) * model.viewport.height;
  if (model.multipage.enabled && model.multipage.currentPage != spec[6]) {
    return;
  }

  context.font = `${fontStyle ? fontStyle + " " : ""}${fontSize}px sans-serif`;
  if (
    ((model.fieldState[fieldId].label_question != null &&
      model.fieldState[fieldId].label_question != "") ||
      model.fieldState[fieldId].field_type == 4) &&
    model.fieldState[fieldId].label != null &&
    model.fieldState[fieldId].label != ""
  ) {
    context.fillStyle = "rgba(0, 122, 0, 45%)";
  } else {
    context.fillStyle = "rgba(0, 0, 0, 45%)";
  }
  let tM = context.measureText(finalText);

  // draw the text
  context.fillText(
    finalText,
    bX + fieldWidth / 2 - tM.width / 2,
    bY + fieldHeight / 2 + fontSize / 2
  );
};

function iacDrawFieldTypeInto(model, spec) {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  let fieldId = spec[4];
  let fieldType = spec[5];

  if (fieldType == 2) {
    context.strokeStyle = "red";
    __iacDrawCheckbox(model, spec, true, true);
    return;
  }

  let finalText = "";
  if (model.debug.__showFieldIds == false) {
    let fill_type = model.fieldState[fieldId].fill_type;
    if (model.fieldState[fieldId].label == "") {
      finalText = getFieldPlaceholder(fieldType, fill_type);
    } else {
      finalText = `${model.fieldState[fieldId].label}${getFieldSuffix(
        fill_type
      )}`;
    }
  } else {
    finalText = `${fieldId}`;
  }

  drawFieldPlaceholder(model, spec, finalText);
}

function drawTextFieldMarker(model, spec, widthOfText) {}

/* oldIAC:iacRefreshText */
function iacRedrawField(model, locationSpec, clean) {
  var fieldId = locationSpec[4];
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  var fieldType = locationSpec[5];

  if (model.fieldState[fieldId] == null) {
    return;
  }

  if (
    model.multipage.enabled &&
    model.multipage.currentPage != locationSpec[6]
  ) {
    // This spec is not on the current page, refuse to update it.
    return;
  }

  /* now update text by first clearing it, then overwriting it */
  if (clean) {
    if (model.operationMode == MODE_SETUP) {
      context.putImageData(
        model.fieldState[fieldId].defaultImageData,
        locationSpec[0] * model.viewport.width,
        locationSpec[2] * model.viewport.height
      );
    } else {
      context.putImageData(
        model.fieldState[fieldId].defaultImageData,
        locationSpec[0] * model.viewport.width + 5,
        locationSpec[2] * model.viewport.height + 5
      );
    }
  }

  if (clean && model.fieldState[fieldId].highlighted) {
    iacDebug(`forcehighlight for ${fieldId}`);
    iacHightlightField(model, locationSpec, true);
  }

  if (fieldType == 1) {
    /* now draw the text */
    var finalString = model.fieldState[fieldId].text_charStack.join("");

    // if (model.fill.textMarker.enabled &&
    //     model.fill.textMarker.field == fieldId &&
    //     model.fill.textMarker.visible) {
    //       finalString += "|";
    // }

    /* figure out a proper text size in pixels */
    var textSize = Math.min(
      12 * model.viewport.scale,
      Math.floor(
        0.9 *
          Math.abs(locationSpec[3] - locationSpec[2]) *
          model.viewport.height
      )
    );
    model.fieldState[fieldId].text_fontSize = textSize;

    // Text positioning
    let tX = locationSpec[0] * model.viewport.width + 10;
    let tY = Math.max(locationSpec[3], locationSpec[2]) * model.viewport.height;
    let maxWidth =
      Math.abs(locationSpec[1] - locationSpec[0]) * model.viewport.width - 10;
    let fieldHeight =
      Math.abs(locationSpec[2] - locationSpec[3]) * model.viewport.height;

    // tY += 0;

    if (model.fieldState[fieldId].allow_multiline) {
      tY -= fieldHeight - textSize;
    }
    context.font = `${textSize}px sans-serif`;
    context.textBaseline = "bottom";
    context.fillStyle = "black";
    let textWidth = context.measureText(finalString);
    let origtY = tY;
    if (model.fieldState[fieldId].allow_multiline) {
      // Wrap the text at the word boundaries
      let line = "";
      let words = finalString.split(" ");
      let rows = 0;
      let maxRows = model.fieldState[fieldId].maxRows;
      for (const word of words) {
        if (context.measureText(line + word).width > maxWidth) {
          if (rows < maxRows) {
            context.fillText(line, tX, tY, maxWidth);
            tY += textSize;
          }
          line = "";
          rows++;
        }

        line += word + " ";
      }

      if (rows < maxRows) {
        context.fillText(line, tX, tY, maxWidth);
      } else {
        // do nothing ???
      }
    } else {
      context.fillText(finalString, tX, tY, maxWidth);
    }
    tY = origtY;

    if (
      (model.operationMode == MODE_SETUP ||
        model.operationMode == MODE_LOCATION_SELECT) &&
      model.setupActiveField == fieldId &&
      model.fieldState[fieldId].allow_multiline
    ) {
      // draw row lines
      for (let i = 0; i < model.fieldState[fieldId].maxRows; i++) {
        // startY -> startY
        // tX  -> tX + textWidth
        context.beginPath();
        context.lineWidth = 2;
        context.moveTo(tX, tY + i * textSize);
        context.lineTo(tX + maxWidth, tY + i * textSize);
        context.stroke();
      }
    }

    if (
      model.fill.textMarker.enabled &&
      model.fill.textMarker.field == fieldId &&
      model.fill.textMarker.visible
    ) {
      if (model.fieldState[fieldId].allow_multiline) {
        let line = "";
        let words = model.fieldState[fieldId].text_charStack
          .slice(0, model.fill.textMarker.charIndex)
          .join("")
          .split(" ");
        let rowIndex = 0;
        let startOfRow = 0;
        for (const word of words) {
          if (context.measureText(line + word).width > maxWidth) {
            rowIndex++;
            startOfRow += line.length;
            line = "";
          }

          line += word + " ";
        }
        iacDebug(`rowIndex: ${rowIndex}`);

        let soFarString = model.fieldState[fieldId].text_charStack
          .slice(startOfRow, model.fill.textMarker.charIndex)
          .join("");
        let soFarStringDims = context.measureText(soFarString);
        let prevStrokeStyle = context.strokeStyle;
        context.strokeStyle = model.fill.textMarker.color;
        let effectiveX = Math.min(
          tX + maxWidth - 12,
          tX + soFarStringDims.width
        );
        context.beginPath();
        context.lineWidth = 5;
        context.moveTo(effectiveX, tY + rowIndex * textSize - textSize);
        context.lineTo(effectiveX, tY + rowIndex * textSize);
        context.stroke();
        context.strokeStyle = prevStrokeStyle;
      } else {
        let soFarString = model.fieldState[fieldId].text_charStack
          .slice(0, model.fill.textMarker.charIndex)
          .join("");
        let soFarStringDims = context.measureText(soFarString);
        let prevStrokeStyle = context.strokeStyle;
        context.strokeStyle = model.fill.textMarker.color;
        let effectiveX = Math.min(
          tX + maxWidth - 12,
          tX + soFarStringDims.width
        );
        context.beginPath();
        context.lineWidth = 5;
        context.moveTo(effectiveX, tY - textSize);
        context.lineTo(effectiveX, tY);
        context.stroke();
        context.strokeStyle = prevStrokeStyle;
      }
    }
    context.textBaseline = "alphabetic";
  } else if (fieldType == 2) {
    __iacDrawCheckbox(
      model,
      locationSpec,
      model.fieldState[fieldId].checkbox_checked,
      false
    );
  } else if (fieldType == 3) {
    iacDrawSignature(model, locationSpec);
  } else if (fieldType == 4) {
  }
}

function iacInitFieldDescriptor(model, locationSpec, fieldId) {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");

  var rX = locationSpec[0] * model.viewport.width;
  var rY = locationSpec[2] * model.viewport.height;
  var rW = Math.abs(locationSpec[1] - locationSpec[0]) * model.viewport.width;
  var rH = Math.abs(locationSpec[3] - locationSpec[2]) * model.viewport.height;
  var fieldType = locationSpec[5];
  var dfID;

  if (model.operationMode == MODE_SETUP) {
    dfID = context.getImageData(rX, rY, rW, rH + 5);
  } else {
    if (fieldType == 2) {
      dfID = context.getImageData(rX, rY, rW, rH + 5);
    } else {
      dfID = context.getImageData(rX + 5, rY + 5, rW - 8, rH - 8);
    }
  }

  // calculate the maxRows if it's multiline
  if (model.fieldState[fieldId].allow_multiline) {
    var textSize = Math.min(
      12 * model.viewport.scale,
      Math.floor(
        0.9 *
          Math.abs(locationSpec[3] - locationSpec[2]) *
          model.viewport.height
      )
    );

    let rows = Math.floor(rH / textSize);
    model.fieldState[fieldId].maxRows = rows;
  }

  model.fieldState[fieldId].defaultImageData = dfID;
  model.fieldState[fieldId].fullyInitialized = true;
}

function iacDrawBordersAroundFields(model) {
  model.location_specs.forEach(($spec) => {
    if (model.multipage.enabled && model.multipage.currentPage != $spec[6]) {
      return;
    }
    var canvas = model.render.canvas;
    var context = canvas.getContext("2d");
    var prevStrokeStyle = context.strokeStyle;
    var prevLineWidth = context.lineWidth;
    var fieldType = $spec[5];
    var startX = $spec[0] * model.viewport.width;
    var startY = $spec[2] * model.viewport.height;
    var endX = $spec[1] * model.viewport.width;
    var endY = $spec[3] * model.viewport.height;
    var width = Math.abs(endX - startX);
    var height = Math.abs(endY - startY);
    if (model.setupActiveField && model.setupActiveField == $spec[4]) {
      context.strokeStyle = "red";
    } else {
      context.strokeStyle = "rgba(115, 171, 133, 100%)";
    }
    context.lineWidth = 5;
    context.strokeRect(startX, startY, width, height);

    context.strokeStyle = prevStrokeStyle;
    context.lineWidth = prevLineWidth;
  });
}

function iacHightlightField(model, spec, force) {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  var startX = spec[0] * model.viewport.width;
  var startY = spec[2] * model.viewport.height;
  var endX = spec[1] * model.viewport.width;
  var endY = spec[3] * model.viewport.height;
  var fieldId = spec[4];
  var fieldType = spec[5];
  var width = Math.abs(endX - startX);
  var height = Math.abs(endY - startY);
  let fd = model.fieldState[fieldId];
  let isHighlighted = model.highlightedField;
  var prevStrokeStyle = context.strokeStyle;
  var prevLineWidth = context.lineWidth;

  if (!fd.highlighted || force) {
    if (!isHighlighted && !fd.editable) {
      return;
    }
    /* check for full init */
    if (fd.fullyInitialized == false) {
      iacInitFieldDescriptor(model, spec, fieldId);
    }
    // iacInitFieldDescriptor(model, spec, fieldId);
    /* draw the highlight */
    var prevFillStyle = context.fillStyle;
    context.fillStyle = "rgba(86, 174, 211, 20%)";

    if (model.operationMode == MODE_SETUP) {
      context.fillRect(startX, startY, width, height);
    } else {
      if (model.fieldState[fieldId].fill_type != model.fill.type) {
        return;
      }
      context.fillRect(startX + 2, startY + 2, width - 4, height - 4);
    }

    context.fillStyle = prevFillStyle;

    if (model.operationMode == MODE_SETUP) {
      // context.strokeStyle = "rgba(0, 0, 0, 100%)";
      context.strokeStyle = "red";
      context.lineWidth = 5;
      context.strokeRect(startX, startY, width, height);

      context.strokeStyle = prevStrokeStyle;
      context.lineWidth = prevLineWidth;
    }

    /* refresh the text on top */
    if (!force) {
      iacRedrawField(model, spec, false);
    }

    /* mark as highlighted */
    fd.highlighted = true;

    if (model.operationMode == MODE_SETUP) {
      /* draw the edges for resize */
      let r = 10;

      if (width > 30 && height > 20) {
        if (fieldType == 2) {
          r = 5;
          drawEdges(model, startX + r, startY + r, r); //top left
          drawEdges(model, startX + width - (r + 2), startY + r, r); //top right
          drawEdges(model, startX + r, startY + height - r, r); //bottom left
          drawEdges(model, startX + width - (r + 2), startY + height - r, r); //bottom right
        } else {
          drawEdges(model, startX + r - 5, startY + r - 5); //top left
          drawEdges(model, startX + width, startY + r - 5); //top right
          drawEdges(model, startX + r - 5, startY + height - 5); //bottom left
          drawEdges(model, startX + width, startY + height - 5); //bottom right
        }
      } else {
        if (fieldType == 2) {
          r = 5;
          drawEdges(model, startX + r, startY + r, r); //top left
          drawEdges(model, startX + width - (r + 2), startY + r, r); //top right
          drawEdges(model, startX + r, startY + height - r, r); //bottom left
          drawEdges(model, startX + width - (r + 2), startY + height - r, r); //bottom right
        }
      }
    }
  }
}

function drawEdges(model, x, y, r = 10) {
  var strokeStyle = "red";
  var fillStyle = "red";
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  context.strokeStyle = strokeStyle;
  context.fillStyle = fillStyle;
  context.beginPath();
  context.arc(x, y, r, 0, Math.PI * 2);
  context.closePath();
  context.fill();
}

export function iacUnhightlightAll(model) {
  for (const spec of model.location_specs) {
    var fieldId = spec[4];

    // get the field descriptor
    var fd = model.fieldState[fieldId];
    if (fd.highlighted) {
      model.fieldState[fieldId].highlighted = false;
      iacRedrawField(model, spec, true);
    }
  }
}

export function iacDrawCheckbox(model, spec, field) {
  __iacDrawCheckbox(model, spec, field.checkbox_checked, true);
}

function __iacDrawCheckbox(model, spec, checked, overwrite) {
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");
  var fieldId = spec[4];

  if (checked == false && overwrite) {
    // untoggle by resetting the imagedata on the field
    context.putImageData(
      model.fieldState[fieldId].defaultImageData,
      spec[0] * model.viewport.width,
      spec[2] * model.viewport.height
    );
  } else if (checked == true) {
    let prevStrokeStyle = context.strokeStyle;
    if (
      model.operationMode == MODE_SETUP ||
      model.operationMode == MODE_LOCATION_SELECT
    ) {
      if (
        model.fieldState[fieldId].label_question != null &&
        model.fieldState[fieldId].label_question != "" &&
        model.fieldState[fieldId].label != null &&
        model.fieldState[fieldId].label != ""
      ) {
        context.strokeStyle = "rgba(0, 122, 0, 45%)";
      } else {
        context.strokeStyle = "black";
      }
    } else {
      context.strokeStyle = "red";
    }

    // toggle by drawing an X between the two opposing corners
    context.beginPath();

    // topleft to bottomright
    context.lineWidth = 6;
    context.moveTo(
      spec[0] * model.viewport.width + 3,
      spec[2] * model.viewport.height + 3
    );
    context.lineTo(
      spec[1] * model.viewport.width - 3,
      spec[3] * model.viewport.height - 3
    );
    context.stroke();

    // topright to bottomright
    context.moveTo(
      spec[1] * model.viewport.width - 3,
      spec[2] * model.viewport.height + 3
    );
    context.lineTo(
      spec[0] * model.viewport.width + 3,
      spec[3] * model.viewport.height - 3
    );
    context.stroke();

    context.strokeStyle = prevStrokeStyle;
  }
}

function iacDrawSignature(model, spec) {
  var fieldId = spec[4];
  var sigInfo = model.fieldState[fieldId].signature_info;
  var canvas = model.render.canvas;
  var context = canvas.getContext("2d");

  iacDebug(`drawSignature for ${fieldId}`);

  if (
    model.operationMode == MODE_SETUP ||
    model.operationMode == MODE_LOCATION_SELECT
  ) {
    // no need to do aynthing in setup mode
    return;
  }

  // draw sign here if the signature field wasn't filled yet
  if (sigInfo.filled == false && model.fieldState[fieldId].editable) {
    iacDebug(`iacDrawSignature: drawing SIGN HERE to ${fieldId}`);
    const fieldHeight = Math.abs(spec[3] - spec[2]) * model.viewport.height;
    const fieldWidth = Math.abs(spec[1] - spec[0]) * model.viewport.width;
    const marginPx = fieldHeight * 0.05;
    const fH = fieldHeight - 2 * marginPx;
    let tH = Math.floor(fieldHeight * 0.5);
    let signTM = context.measureText(" SIGN HERE");
    while (tH >= 16) {
      context.font = `${tH}px sans-serif`;
      signTM = context.measureText(" SIGN HERE");
      iacDebug(`signTM: width ${signTM.width} x height ${tH}`);
      if (signTM.width < fieldWidth && tH < fieldHeight) break;
      tH /= 2;
    }
    if (tH <= 16) tH = 16;
    iacDebug(
      `iacDrawSignature: measured w x h ${fieldWidth} x ${fieldHeight} => tH = ${tH}`
    );
    const startY =
      Math.min(spec[2], spec[3]) * model.viewport.height + marginPx;
    const p2Y = Math.floor(startY);

    /* draw background */
    let prevFillStyle = context.fillStyle;

    let lesserX = Math.min(spec[0], spec[1]) * model.viewport.width;
    let centerX = lesserX + (fieldWidth - signTM.width) / 2;

    // draw text
    context.strokeStyle = "black";
    context.fillStyle = "black";
    let tX = centerX,
      tY = Math.floor(p2Y + fH - tH / 2);
    context.fillText("SIGN HERE", tX, tY);

    // done, reset
    context.fillStyle = prevFillStyle;

    return;
  }

  var imageToDraw = new Image();
  imageToDraw.src = sigInfo.signatureData;
  imageToDraw.onload = function () {
    context.drawImage(
      imageToDraw,
      spec[0] * model.viewport.width,
      Math.min(spec[2], spec[3]) * model.viewport.height,
      Math.abs(spec[1] - spec[0]) * model.viewport.width,
      Math.abs(spec[3] - spec[2]) * model.viewport.height
    );
  };
}

function iacDrawTable(model, fd, locationSpec) {
  let fieldId = fd.id;
  let label = model.fieldState[fieldId].label;
  iacDebug(`[table/render] Rendering table field ${fieldId} label ${label}`);
  // table
  var textSize = Math.min(
    12 * model.viewport.scale,
    Math.floor(
      0.9 * Math.abs(locationSpec[3] - locationSpec[2]) * model.viewport.height
    )
  );
  var finalString = `Table (${label}) to be attached`;
  if (model.tables.empty.find((x) => x == label) != undefined) {
    finalString = `N/A`;
  }
  let tX = locationSpec[0] * model.viewport.width + 10;
  let tY = Math.max(locationSpec[3], locationSpec[2]) * model.viewport.height;
  let maxWidth =
    Math.abs(locationSpec[1] - locationSpec[0]) * model.viewport.width - 10;
  let canvas = model.render.canvas;
  let context = canvas.getContext("2d");
  context.font = `${textSize}px sans-serif`;
  context.textBaseline = "bottom";
  context.fillStyle = "black";
  context.fillText(finalString, tX, tY, maxWidth);
}

export function _iacAddCanvasHook(model, type, hook) {
  /* record, so we can delete later */
  model.render.eventHooks.push({ type: type, hook: hook });

  model.render.canvas.addEventListener(type, hook);
}

export function _iacAddWindowHook(model, type, hook) {
  /* record, so we can delete later */
  model.render.windowHooks.push({ type: type, hook: hook });

  function handleKeyDown(evt) {
    transformKeydownEvent(evt, hook);
  }

  function handleTransformInputEvent(evt) {
    transformInputEvent(evt, hook);
  }

  let androidWorkaroundEnabled = isAndroidMobile();
  /* XXX: Marshall the events */
  if (type == "keydown") {
    model.render.windowHooks.push({ type: "keydown", hook: handleKeyDown });

    window.addEventListener("keydown", handleKeyDown);

    if (androidWorkaroundEnabled) {
      console.log(
        "IAC: This is Android device, so adding an extra handler with marshalling"
      );
      model.render.windowHooks.push({
        type: "input",
        hook: handleTransformInputEvent,
      });
      window.addEventListener("input", handleTransformInputEvent);
    }
  } else {
    window.addEventListener(type, hook);
  }

  return () => {
    console.log("clouse");
  };
}

export function _iacResetCanvasHooks(model) {
  for (const o of model.render.eventHooks) {
    model.render.canvas.removeEventListener(o.type, o.hook);
  }

  for (const o of model.render.windowHooks) {
    window.removeEventListener(o.type, o.hook);
  }
}

export {
  iacRender,
  iacAddCanvasRenderHook,
  iacDrawFieldTypeInto,
  iacDrawBaseHighlight,
  iacHightlightField,
  iacInitFieldDescriptor,
  iacRedrawField,
  iacDrawBordersAroundFields,
  iacRenderLoadingScreen,
  iacDrawBaseBorderHighlight,
  iacDrawTable,
};
