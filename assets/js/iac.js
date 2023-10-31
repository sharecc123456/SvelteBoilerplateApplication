function iacDebug(txt) {
  if (window.bp_iac_debugEnabled) {
    console.log(txt);
  }
}

function iacAddCanvasRenderHook(id, f) {
  if (window.bp_iac_canvasRenderHooks == undefined) {
    iacDebug(`iacAddCanvasRenderHook: adding ${id}, resulted in hook structure being initialized`);
    window.bp_iac_canvasRenderHooks = [];
  }

  if (window.bp_iac_canvasRendered) {
    iacDebug(`iacAddCanvasRenderHook: adding ${id} failed, because canvas is up already`);
    f();
  } else {
    iacDebug(`iacAddCanvasRenderHook: added ${id} to hooks`);
    window.bp_iac_canvasRenderHooks.push({id: id, fu: f});
  }
}

function findGetParameter(parameterName) {
    var result = null,
        tmp = [];
    location.search
        .substr(1)
        .split("&")
        .forEach(function (item) {
          tmp = item.split("=");
          if (tmp[0] === parameterName) result = decodeURIComponent(tmp[1]);
        });
    return result;
}

function iacToggleTextMarker() {
  if (!window.bp_iac_marker.enabled || window.bp_iac_fill2_spec == null) {
    // textwrite is active or there is no focused field, bye.
    return;
  }

  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');

  // variables that we need
  var fieldId = window.bp_iac_fill2_spec[4];
  var fieldHeight = Math.floor(0.9 * (window.bp_iac_fill2_spec[3] - window.bp_iac_fill2_spec[2]) * window.bp_iac_viewportHeight);

  if (window.bp_iac_marker.visible == false) {
    // draw
    var currentTextInField = window.bp_iac_fill2_txts[fieldId].charStack.join("");
    context.font = `${fieldHeight}px sans-serif`;
    var widthOfText = Math.floor(context.measureText(currentTextInField).width);
    var targetWidth = Math.floor(context.measureText("|").width);

    // Figure out where to draw
    var baseX = window.bp_iac_fill2_spec[0] * window.bp_iac_viewportWidth + widthOfText + targetWidth;
    var baseY = window.bp_iac_fill2_spec[2] * window.bp_iac_viewportHeight + Math.floor(fieldHeight * 0.1);
    var finalY = window.bp_iac_fill2_spec[3] * window.bp_iac_viewportHeight - Math.floor(fieldHeight * 0.1);
    //console.log(`MARKER: ON @ ${baseX},${baseY}`);

    // save the data under
    window.bp_iac_marker.prevImageData
      = context.getImageData(baseX - Math.ceil(targetWidth / 2), baseY, targetWidth * 2, finalY - baseY);

    // draw the line
    context.beginPath();
    context.moveTo(baseX, baseY);
    context.lineTo(baseX, finalY);
    context.stroke();
    
    window.bp_iac_marker.visible = true;
  } else {
    // hide
    var currentTextInField = window.bp_iac_fill2_txts[fieldId].charStack.join("");
    context.font = `${fieldHeight}px sans-serif`;
    var widthOfText = Math.floor(context.measureText(currentTextInField).width);
    var targetWidth = Math.floor(context.measureText("|").width);
    var baseX = window.bp_iac_fill2_spec[0] * window.bp_iac_viewportWidth + widthOfText + targetWidth;
    var baseY = window.bp_iac_fill2_spec[2] * window.bp_iac_viewportHeight + Math.floor(fieldHeight * 0.1);
    context.putImageData(window.bp_iac_marker.prevImageData,
      baseX - Math.ceil(targetWidth / 2), baseY);

    //console.log(`MARKER: OFF @ ${baseX},${baseY}`);
    window.bp_iac_marker.prevImageData = null;
    window.bp_iac_marker.visible = false;
  }
}

function iacSendConsent(val) {
  // Send the approval to the server
  var formData = new FormData();
  formData.append('approval', val);
  formData.append('rid', document.getElementById('iac-fill-recipient-id').value);

  fetch('/iac/consent', {
    method: 'POST',
    credentials: 'include',
    headers: {
      'x-csrf-token': document.getElementById("iac-fill-csrf_token").value,
    },
    body: formData
  })
  .then(() => {
    // save locally
    document.getElementById("user_esigned").value = `${val}`;

    // redo the click
    if (val) {
      iacDispatchSignature(window.bp_iac_postConsent);
    }
  });
}

function iacEsignInit() {
  document.querySelector('[data-action=bp-esign-ok]').addEventListener('click', () => {
    iacSendConsent(true);
  });
  document.querySelector('[data-action=bp-esign-no]').addEventListener('click', () => {
    iacSendConsent(false);
  });
}

function iacInitSignaturePad() {
  var saveButton = document.querySelector("[data-action=bp-sig-save]");
  saveButton.addEventListener("click", function (event) {
    // common signature pad init is done in app.js
    var signaturePad = window.bp_iac_signaturePad;

    if (signaturePad.isEmpty()) {
      alert("Please provide a signature first.");
    } else {
      // save the form before submitting the signature
      iacSaveForm().then(() => {
        var dataURL = signaturePad.toDataURL();
        var formData = new FormData();
        var tid = document.getElementById("bp-internal-rdid").value;
        var fid = window.bp_iac_activeSignatureFieldId;
        var csrf_token = document.getElementById("iac-fill-csrf_token").value;
        let isRequestor = false;
        if (window.bp_iac_requestorMode) {
          isRequestor = true;
        }
        formData.append("requestor", isRequestor);
        formData.append("signature_dataurl", dataURL);
        fetch(`/iac/${tid}/${fid}/signature?np=${window.bp_iac_multipageIAC.currentPage}`, {
          method: 'POST',
          credentials: 'include',
          headers: {
            'x-csrf-token': csrf_token
          },
          body: formData
        }).then(response => response.text())
          .then(txt => {
            iacDebug(txt)
            var rid = document.getElementById('iac-fill-recipient-id').value;
            var aid;
            var endURL;
            if (window.bp_iac_requestorMode) {
              aid = document.getElementById('iac-fill-contents-id').value;
              endURL = "rfill";
            } else {
              aid = document.getElementById('iac-fill-assignment-id').value;
              endURL = "fill";
            }
            var tid = document.getElementById('bp-internal-rdid').value;
            window.location = `/iac/${rid}/${aid}/${tid}/${endURL}?np=${window.bp_iac_multipageIAC.currentPage}`;
        });
      });
    }
  });
}

function iacGetSignatureEditable(elem) {
  if (elem.children.length == 0) {
    iacDebug("iacGetSignatureEditable: elem = ${elem} => true, because no children");
    return true;
  } else if (window.bp_iac_setupMode) {
    iacDebug("iacGetSignatureEditable: elem = ${elem} => true, because setupMode");
    return true;
  } else {
    var iacSig = elem.children[0];

    iacDebug(`iacGetSignatureEditable: elem = ${elem}, iacSig = ${iacSig}, tagName: ${iacSig.tagName}, editable: ${iacSig.dataset["editable"]}`);
    return iacSig.tagName == "IMG" && iacSig.dataset["editable"] == "true";
  }
}

function iacGetSignatureInfo(elem, fieldId) {
  // if the signature field has a signature already in it, then
  // it's a HTMLImageElement that's a direct child of `elem`.

  if (elem.children.length == 0) {
    return {
      filled: false,
      audit_start: null,
      audit_end: null,
      signatureData: null,
    };
  } else {
    var iacSig = elem.children[0];
    iacDebug("Found a valid signature");

    return {
      filled: true,
      audit_start: null,
      audit_end: null,
      signatureData: iacSig.src,
    };
  }
}

function iacCreateLocationSpecs() {
  return Array.from(document.querySelectorAll('[data-iac-location]'))
    .map(($elem) => $elem.dataset['iacLocation'])
    .filter(($s) => $s.startsWith("1"))
    .map(($s) => {
      var x = $s.split(" ");
      var lv1 = parseFloat(x[1]);
      var lv2 = parseFloat(x[2]);
      var lv3 = parseFloat(x[3]);
      var lv4 = parseFloat(x[4]);
      var page_no = parseFloat(x[6]);
      var lv5 = parseInt(x[7]);
      var lv6 = parseInt(x[8]);
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
      return [bX, fX, bY, fY, lv5, lv6, page_no];
    });
}

function iacDrawBordersAroundFields() {
  /* Draw green borders around every existing field to highlight their existence */
  window.bp_iac_locationSpecs.forEach(($spec) => {
    if (window.bp_iac_multipageIAC.enabled &&
          window.bp_iac_multipageIAC.currentPage != $spec[6]) {
      return;
    }
    var canvas = document.getElementById('bp-iac-canvas');
    var context = canvas.getContext('2d');
    var prevStrokeStyle = context.strokeStyle;
    var prevLineWidth = context.lineWidth;
    var startX = $spec[0] * window.bp_iac_viewportWidth;
    var startY = $spec[2] * window.bp_iac_viewportHeight;
    var endX = $spec[1] * window.bp_iac_viewportWidth;
    var endY = $spec[3] * window.bp_iac_viewportHeight;
    var width = Math.abs(endX - startX);
    var height = Math.abs(endY - startY);

    context.strokeStyle = "rgba(115, 171, 133, 100%)";
    context.lineWidth = 5;
    context.strokeRect(startX, startY, width, height);
    context.strokeStyle = prevStrokeStyle;
    context.lineWidth = prevLineWidth;
  });
}

function iacSetupSwitchViews() {
  var divFields = document.getElementById("bp-iac-field-column");
  var divCanvas = document.getElementById("bp-iac-canvas-column");

  var txtFields = document.getElementById("bp-iac-field-text");
  var txtCanvas = document.getElementById("bp-iac-canvas-text");

  /* Figure what the current view is */
  var viewIsCanvas = divFields.classList.contains("is-hidden");

  if (viewIsCanvas) {
    /* Hide the canvas and show the fields view */
    divCanvas.classList.add("is-hidden");
    divFields.classList.remove("is-hidden");
    txtCanvas.classList.add("is-hidden");
    txtFields.classList.remove("is-hidden");
  } else {
    /* Hide the fields and show the canvas view */
    divFields.classList.add("is-hidden");
    divCanvas.classList.remove("is-hidden");
    txtFields.classList.add("is-hidden");
    txtCanvas.classList.remove("is-hidden");
  }
}

// derp. transplant from modals.js
//
// plsfix urgently XXX
function __iac__internal__openModal(modal, target) {
  var rootEl = document.documentElement;
  var $target = document.getElementById(modal);
  if (target != "null") {
    var $m = document.getElementById(target);
    $m.style.display = 'block';
  }
  rootEl.classList.add('is-clipped');
  $target.classList.add('is-active');
}

function iacDispatchSignature(spec) {
  var fieldId = spec[4];
  var eSignConsent = document.getElementById('user_esigned').value == "true";

  // save the fieldId, so the save button can work.
  window.bp_iac_activeSignatureFieldId = fieldId;

  if (!eSignConsent) {
    // alert("Do you consent to signing this document using an electronic signature? pls fix this. Bla bla - automatically assuming yes for now");
    window.bp_iac_postConsent = spec;
    __iac__internal__openModal("bp-iac-modal", "iac_esign_consent");
  } else {
    if (window.bp_iac_signaturePad == null) {
      alert("FATAL: secure signature link failed to establish");
      return;
    }

    // make sure the field is fully initialized before touching it
    if (window.bp_iac_fill2_txts[fieldId].full_init_done == false) {
      iacInitFieldDescriptor(spec, fieldId);
    }

    // setup an exithook, so we can save the signature data
    window.bp_modal_exitHook = function () {
      // when the modal is closed, save the information about the signature
      if (window.bp_iac_signaturePad.isEmpty() || window.bp_modal_closeReason == "cancel") {
        window.bp_iac_signaturePad.clear();
        window.bp_modal_closeReason = undefined;
        // do nothing, the user didn't provide a signature
        return;
      }

      // there is a signature in the pad, retrieve its dataURL
      var sigDataURL = window.bp_iac_signaturePad.toDataURL();
      // TODO audit_start, audit_end
      window.bp_iac_fill2_txts[fieldId].signature_info.audit_start = Date.now();
      window.bp_iac_fill2_txts[fieldId].signature_info.audit_end   = Date.now();
      window.bp_iac_fill2_txts[fieldId].signature_info.signatureData = sigDataURL;
      window.bp_iac_fill2_txts[fieldId].signature_info.filled = true;

      // refresh the field
      iacRefreshText(spec, false);
    };

    // open the modal
    __iac__internal__openModal("bp-iac-modal", "iac_requestor_sign");
  }
}

function iacDrawFieldTypeInto(spec) {
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');
  let fieldId = spec[4];
  let fieldType = spec[5];
  iacDebug(`iacDrawFieldTypeInto: fieldId = ${fieldId}`);
  const fieldHeight = Math.abs(spec[3] - spec[2]) * window.bp_iac_viewportHeight;
  const fieldWidth  = Math.abs(spec[1] - spec[0]) * window.bp_iac_viewportWidth - 4*context.lineWidth;
  const fontSize = Math.floor(fieldHeight * 0.60);
  let bX = spec[0] * window.bp_iac_viewportWidth, bY = Math.min(spec[2], spec[3]) * window.bp_iac_viewportHeight;

  if (window.bp_iac_multipageIAC.enabled &&
      window.bp_iac_multipageIAC.currentPage != spec[6]) {
    return;
  }

  let typeText;
  if (fieldType == 1) {
    typeText = "TEXT";
  } else if (fieldType == 2) {
    // don't write on checkboxes
    return;
  } else if (fieldType == 3) {
    typeText = "SIGNATURE";
  } else {
    typeText = "UNKNOWN";
    iacDebug(`!!! Found unknown type during iacDrawFieldTypeInto: spec ${spec}`);
  }

  // measure the text
  context.font = `${fontSize}px sans-serif`;
  context.fillStyle = "rgba(0, 0, 0, 20%)";
  let tM = context.measureText(typeText);

  // draw the text
  context.fillText(typeText, bX + (fieldWidth / 2) - (tM.width / 2),
    bY + fieldHeight / 2 + fontSize / 2);
}

function iacDrawSignature(spec) {
  var fieldId = spec[4];
  var sigInfo = window.bp_iac_fill2_txts[fieldId].signature_info;
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');

  if (window.bp_iac_setupMode) {
    // no need to do aynthing in setup mode
    return;
  }

  // draw sign here if the signature field wasn't filled yet
  if (sigInfo.filled == false) {
    iacDebug(`iacDrawSignature: drawing SIGN HERE to ${fieldId}`);
    const fieldHeight = Math.abs(spec[3] - spec[2]) * window.bp_iac_viewportHeight;
    const fieldWidth  = Math.abs(spec[1] - spec[0]) * window.bp_iac_viewportWidth - 4*context.lineWidth;
    const marginPx = fieldHeight * 0.05;
    const fH = fieldHeight - 2 * marginPx;
    let tH = Math.floor(fieldHeight * 0.50);
    context.font = `${tH}px sans-serif`;
    let signTM = context.measureText("SIGN HERE");
    const fW = Math.floor(signTM.width * 1.5);
    const fO = Math.floor((fieldWidth - (fH / 2)) - fW);
    const startX = fO + spec[0] * window.bp_iac_viewportWidth + marginPx;
    const startY = Math.min(spec[2], spec[3]) * window.bp_iac_viewportHeight + marginPx;

    const p1X = Math.floor(startX),          p1Y = Math.floor(startY + fH / 2);
    const p2X = Math.floor(startX + fH / 2), p2Y = Math.floor(startY);
    const p3X = Math.floor(startX + fH / 2), p3Y = Math.floor(startY + fH);
    const p5X = Math.floor(startX + fW - (fH / 2)), p5Y = Math.floor(startY + fH);

    /* draw background */
    let prevFillStyle = context.fillStyle;
    context.fillStyle = "rgba(255, 128, 128, 100%)";

    // draw triangle
    context.beginPath();
    context.moveTo(p1X, p1Y);
    context.lineTo(p2X, p2Y);
    context.lineTo(p3X, p3Y);
    context.lineTo(p1X, p1Y);
    context.closePath();
    context.fill();

    // draw rectangle
    context.fillRect(p2X, p2Y, fW, fH);

    // draw text
    context.strokeStyle = 'black';
    context.fillStyle = 'black';
    //let tX = p2X + fW - signTM.width, tY = Math.floor(startY + (fH - signTM.height) / 2);
    let tX = p2X + fW - signTM.width * 1.10, tY = Math.floor(p2Y + fH - (tH / 2));
    context.fillText("SIGN HERE", tX, tY);
    
    // done, reset
    context.fillStyle = prevFillStyle;

    return;
  }

  var imageToDraw = new Image();
  imageToDraw.src = sigInfo.signatureData;
  imageToDraw.onload = function() {
    context.drawImage(imageToDraw, spec[0] * window.bp_iac_viewportWidth,
      Math.min(spec[2], spec[3]) * window.bp_iac_viewportHeight,
      Math.abs(spec[1] - spec[0]) * window.bp_iac_viewportWidth,
      Math.abs(spec[3] - spec[2]) * window.bp_iac_viewportHeight);
  };
}

function iacToggleCheckbox(spec) {
  // given a spec, toggle the checkbox status
  var fieldId = spec[4];

  if (window.bp_iac_fill2_txts[fieldId].full_init_done == false) {
    // if it didn't have its full init yet, initialize the field
    iacInitFieldDescriptor(spec, fieldId);
  }

  if (window.bp_iac_fill2_txts[fieldId].checkbox_checked) {
    window.bp_iac_fill2_txts[fieldId].checkbox_checked = false;
  } else {
    window.bp_iac_fill2_txts[fieldId].checkbox_checked = true;
  }

  iacDrawCheckbox(spec);
}

function iacDrawCheckbox(spec) {
  var fieldId = spec[4];

  __iacDrawCheckbox(spec,
    window.bp_iac_fill2_txts[fieldId].checkbox_checked, true);
}

function __iacDrawCheckbox(spec, checked, overwrite) {
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');
  var fieldId = spec[4];

  if (checked == false && overwrite) {
    // untoggle by resetting the imagedata on the field
    context.putImageData(window.bp_iac_fill2_txts[fieldId].defaultImageData,
      spec[0] * window.bp_iac_viewportWidth, spec[2] * window.bp_iac_viewportHeight);
  } else if (checked == true) {
    // toggle by drawing an X between the two opposing corners
    context.beginPath();

    // topleft to bottomright
    context.moveTo(spec[0] * window.bp_iac_viewportWidth, spec[2] * window.bp_iac_viewportHeight);
    context.lineTo(spec[1] * window.bp_iac_viewportWidth, spec[3] * window.bp_iac_viewportHeight);
    context.stroke();

    // topright to bottomright
    context.moveTo(spec[1] * window.bp_iac_viewportWidth, spec[2] * window.bp_iac_viewportHeight);
    context.lineTo(spec[0] * window.bp_iac_viewportWidth, spec[3] * window.bp_iac_viewportHeight);
    context.stroke();
  }
}

function iacRefreshText(locationSpec, clean) {
  var fieldId = locationSpec[4];
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');
  var fieldType = locationSpec[5];

  if (window.bp_iac_fill2_txts[fieldId] == null) {
    return;
  }

  if (window.bp_iac_multipageIAC.enabled &&
        window.bp_iac_multipageIAC.currentPage != locationSpec[6]) {
    // This spec is not on the current page, refuse to update it.
    return;
  }

  /* now update text by first clearing it, then overwriting it */
  if (clean) {
    context.putImageData(window.bp_iac_fill2_txts[fieldId].defaultImageData,
      locationSpec[0] * window.bp_iac_viewportWidth, locationSpec[2] * window.bp_iac_viewportHeight);
  }

  if (clean && window.bp_iac_fill2_txts[fieldId].highlighted) {
    iacHightlightField(locationSpec, true);
  }

  if (fieldType == 1) {
    /* now draw the text */
    var finalString = window.bp_iac_fill2_txts[fieldId].charStack.join("");

    /* figure out a proper text size in pixels */
    var textSize = Math.floor(0.9 * Math.abs(locationSpec[3] - locationSpec[2]) * window.bp_iac_viewportHeight);

    // Text positioning
    let tX = locationSpec[0] * window.bp_iac_viewportWidth + 10;
    let tY = Math.max(locationSpec[3], locationSpec[2]) * window.bp_iac_viewportHeight;
    let maxWidth = Math.abs(locationSpec[1] - locationSpec[0]) * window.bp_iac_viewportWidth - 10;
    let fieldHeight = Math.abs(locationSpec[2] - locationSpec[3]) * window.bp_iac_viewportHeight;

    tY += Math.floor((fieldHeight - textSize) / 2);

    context.font = `${textSize}px sans-serif`;
    context.textBaseline = 'bottom';
    context.fillText(finalString, tX, tY, maxWidth);
  } else if (fieldType == 2) {
    __iacDrawCheckbox(locationSpec,
      window.bp_iac_fill2_txts[fieldId].checkbox_checked, false);
  } else if (fieldType == 3) {
    iacDrawSignature(locationSpec);
  }
}

function iacInitFieldDescriptor(locationSpec, fieldId) {
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');

  var rX = locationSpec[0] * window.bp_iac_viewportWidth;
  var rY = locationSpec[2] * window.bp_iac_viewportHeight;
  var rW = Math.abs(locationSpec[1] - locationSpec[0]) * window.bp_iac_viewportWidth;
  var rH = Math.abs(locationSpec[3] - locationSpec[2]) * window.bp_iac_viewportHeight;
  var dfID = context.getImageData(rX, rY, rW, rH + 5);

  window.bp_iac_fill2_txts[fieldId].defaultImageData = dfID;
  window.bp_iac_fill2_txts[fieldId].full_init_done = true;
}

function iacPushChar(locationSpec, c) {
  var fieldId = locationSpec[4];
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');
  // if (rX >= spec[0] && rX <= spec[1] && rY >= spec[2] && rY <= spec[3]) {

  if (window.bp_iac_fill2_txts == null) {
    window.bp_iac_fill2_txts = {};
  }

  if (window.bp_iac_fill2_txts[fieldId].full_init_done == false) {
    iacInitFieldDescriptor(locationSpec, fieldId);
  }

  if (c == "Enter" || c == "Escape") {
    // these shouldn't do anything
    return;
  }

  /* append the character */
  if (c == "Backspace") {
    window.bp_iac_fill2_txts[fieldId].charStack.pop();
  } else {
    window.bp_iac_fill2_txts[fieldId].charStack.push(c);
  }

  iacRefreshText(locationSpec, true);
}

function iacUnhightlightAll() {
  for (const spec of window.bp_iac_locationSpecs) {
    var fieldId = spec[4];

    // get the field descriptor
    var fd = window.bp_iac_fill2_txts[fieldId];
    if (fd.highlighted) {
      window.bp_iac_fill2_txts[fieldId].highlighted = false;
      iacRefreshText(spec, true);
    }
  }
}

function iacHightlightField(spec, force) {
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');
  var startX = spec[0] * window.bp_iac_viewportWidth;
  var startY = spec[2] * window.bp_iac_viewportHeight;
  var endX = spec[1] * window.bp_iac_viewportWidth;
  var endY = spec[3] * window.bp_iac_viewportHeight;
  var fieldId = spec[4];
  var width = Math.abs(endX - startX);
  var height = Math.abs(endY - startY);

  if (!window.bp_iac_fill2_txts[fieldId].highlighted || force) {
    if (! window.bp_iac_fill2_txts[fieldId].editable) {
      return;
    }
    /* check for full init */
    if (window.bp_iac_fill2_txts[fieldId].full_init_done == false) {
      iacInitFieldDescriptor(spec, fieldId);
    }
    /* draw the highlight */
    var prevFillStyle = context.fillStyle;
    context.fillStyle = "rgba(86, 174, 211, 20%)";
    context.fillRect(startX, startY, width, height);
    context.fillStyle = prevFillStyle;

    /* refresh the text on top */
    if (!force) {
      iacRefreshText(spec, false);
    }

    /* mark as highlighted */
    window.bp_iac_fill2_txts[fieldId].highlighted = true;
  }
}

function iacFindFieldByLocation(rX, rY) {
  for (const spec of window.bp_iac_locationSpecs) {
    if (rX >= spec[0] && rX <= spec[1] && rY >= spec[2] && rY <= spec[3]) {
      // found the field that we clicked on
      // spec[4] has the field id, so we use that to find the field to focus

      if (window.bp_iac_multipageIAC.enabled &&
            window.bp_iac_multipageIAC.currentPage == spec[6]) {
        return spec;
      }
    }
  }

  return null;
}

/* draw the txt at locationSpec onto the IAC PDF canvas */
function iacDrawText(locationSpec, txt) {
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');

  context.strokeStyle = "red";
  context.fillText(txt, locationSpec[0] * window.bp_iac_viewportWidth, locationSpec[3] * window.bp_iac_viewportHeight);
}

/* during iac setup */
function setup_init() {
  window.bp_iac_fillAllowed = false;
  window.bp_iac_setupMode = true;

  /* Initialize the model */
  iac_model_init();

  /* Initialize setup-specific stuff that's not model related */
  document.querySelectorAll("[data-action=bp-iac-switch-views]").forEach(($el) => {
    $el.addEventListener('click', () => {
      iacSetupSwitchViews();
    });
  });

  iacAddCanvasRenderHook("setup/borders", () => {
    iacDrawBordersAroundFields();
  });

  /* Add a click listener to all rows, which:
   *
   * (1) Switches views to the Preview screen;
   * (2) Highlights the field pertaining to the row;
   * and, (3) scrolls into view
   */
  document.querySelectorAll("[data-iac-action=show-field]").forEach(($row) => {
    var fieldId = $row.dataset["iacFieldId"];
    var spec = window.bp_iac_fill2_txts[fieldId].location_spec;

    $row.addEventListener('click', () => {
      var canvas = document.getElementById('bp-iac-canvas');
      var context = canvas.getContext('2d');
      var pageNo = spec[6];
      var startX = spec[0] * window.bp_iac_viewportWidth;
      var startY = spec[2] * window.bp_iac_viewportHeight;
      var endX = spec[1] * window.bp_iac_viewportWidth;
      var endY = spec[3] * window.bp_iac_viewportHeight;
      var width = Math.abs(endX - startX);
      var height = Math.abs(endY - startY);

      if (window.bp_iac_setupLastShown != null) {
        /* Unhide the previous */
        iacRefreshText(window.bp_iac_fill2_txts[window.bp_iac_setupLastShown].location_spec, true);
        window.bp_iac_setupLastShown = null;
      }

      /* switch to the correct page */
      iacDebug(`Switching to page ${pageNo} to handle click`);
      iacSwitchPage(pageNo);

      if (! window.bp_iac_fill2_txts[fieldId].full_init_done) {
        iacInitFieldDescriptor(spec, fieldId);
      }

      /* Draw */
      context.fillStyle = "rgba(86, 174, 211, 20%)";
      context.fillRect(startX, startY, width, height);
      window.bp_iac_setupLastShown = fieldId;

      /* Switch views */
      iacSetupSwitchViews();

      /* Scroll into view */
      var rect = canvas.getBoundingClientRect();
      var scrollTarget = rect.top + rect.height * spec[2];
      iacDebug(`scrolling to ${scrollTarget}`);
      window.scrollTo(0, scrollTarget);
    });
  });

  /* Switch to field view if p=1 GET param is set */
  var pValue = findGetParameter("p");
  if (pValue == "1") {
    iacSetupSwitchViews();
  }
}

function iacSwitchPage(pageNo) {
  if (window.bp_iac_multipageIAC.enabled == false) {
    return;
  }

  if (window.bp_iac_multipageIAC.currentPage == pageNo) {
    return;
  }

  window.bp_iac_multipageIAC.currentPage = pageNo;
  document.getElementById('bp-iac-pagenumber').innerHTML = `Page ${window.bp_iac_multipageIAC.currentPage + 1} / ${window.bp_iac_multipageIAC.pageCount}`;
  iacFullRerender();
}

function iacFullRerender() {
  var pdfjsLib = window['pdfjs-dist/build/pdf'];
  pdfjsLib.GlobalWorkerOptions.workerSrc = '//mozilla.github.io/pdf.js/build/pdf.worker.js';
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');
  var pdf = window.bp_iac_multipageIAC.pdfObject;

  window.bp_iac_canvasRendered = false;
  window.bp_iac_canvasHooksDone = false;
  pdf.getPage(window.bp_iac_multipageIAC.currentPage + 1).then(function(page) {
    var scale = 5;
    var viewport = page.getViewport({ scale: scale, });

    canvas.height = viewport.height;
    canvas.width = viewport.width;
    window.bp_iac_viewportWidth = viewport.width;
    window.bp_iac_viewportHeight = viewport.height;
    canvas.style.width = "100%";

    var renderContext = {
      canvasContext: context,
      viewport: viewport
    };
    page.render(renderContext).promise.then(() => {
      iacDebug("IAC Canvas finished rendering");
      window.bp_iac_canvasRendered = true;
      if (window.bp_iac_canvasRenderHooks != undefined) {
        for (let f of window.bp_iac_canvasRenderHooks) {
          iacDebug(`iacFullRerender: executing hook ${f.id}`);
          f.fu();
          iacDebug(`iacFullRerender: done executing hook ${f.id}`);
        }
      }

      /* refresh all fields */
      if (window.bp_iac_fillAllowed) {
        for (const spec of window.bp_iac_locationSpecs) {
          iacRefreshText(spec, false);
        }
      }

      /* reset the marker */
      window.bp_iac_canvasHooksDone = true;
      window.bp_iac_pdfData = context.getImageData(0, 0, window.bp_iac_viewportWidth, window.bp_iac_viewportHeight);
    });
  });
}

function iac_model_init() {
  var pdfjsLib = window['pdfjs-dist/build/pdf'];
  pdfjsLib.GlobalWorkerOptions.workerSrc = '//mozilla.github.io/pdf.js/build/pdf.worker.js';
  var did = document.getElementById('bp-internal-rdid').value;
  var url = '/iac/' + did + '/download';
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');

  window.bp_iac_canvasRendered = false;
  window.bp_iac_canvasHooksDone = false;
  var loadingTask = pdfjsLib.getDocument(url);
  loadingTask.promise.then(function(pdf) {
    if (window.bp_iac_multipageIAC.enabled) {
      // get the number of pages
      window.bp_iac_multipageIAC.pageCount = pdf.numPages;
      window.bp_iac_multipageIAC.pdfObject = pdf;
    }
    pdf.getPage(window.bp_iac_multipageIAC.currentPage + 1).then(function(page) {
      var scale = 5;
      var viewport = page.getViewport({ scale: scale, });

      canvas.height = viewport.height;
      canvas.width = viewport.width;
      window.bp_iac_viewportWidth = viewport.width;
      window.bp_iac_viewportHeight = viewport.height;
      canvas.style.width = "100%";

      var renderContext = {
        canvasContext: context,
        viewport: viewport
      };
      page.render(renderContext).promise.then(() => {
        iacDebug("IAC Canvas finished rendering");
        window.bp_iac_canvasRendered = true;
        if (window.bp_iac_canvasRenderHooks != undefined) {
          for (let f of window.bp_iac_canvasRenderHooks) {
            iacDebug(`iac_model_init: executing hook ${f.id}`);
            f.fu();
            iacDebug(`iac_model_init: done executing hook ${f.id}`);
          }
        }
        window.bp_iac_canvasHooksDone = true;
      });
    })
    .then(() => {
    });
  }, function (reason) {
    // PDF loading error
    console.error(reason);
    var hashThis = reason.message.split("").reduce(function(a,b){a=((a<<5)-a)+b.charCodeAt(0);return a&a},0);
    context.fillText("PDF loading failed: " + hashThis, 0, window.bp_iac_viewportHeight/2);
  });

  /* find the location specs that matter */
  var locationSpecs = iacCreateLocationSpecs();
  window.bp_iac_locationSpecs = locationSpecs;

  /* create the txts array */
  window.bp_iac_fill2_txts = {};

  for (const spec of locationSpecs) {
    // get the set_value
    var qString = '[data-iac-field-id="' + spec[4] + '"]';
    var elem = document.querySelector(qString);
    var sv = "";
    var dv = "";
    var ft = spec[5];
    if (window.bp_iac_fillAllowed) {
      sv = elem.dataset["iacSetValue"];
      dv = elem.dataset["iacDefaultValue"];
    }
    var charStack = [];

    if (ft == 1) {
      for (var i = 0; i < sv.length; i++) {
        charStack.push(sv.charAt(i));
      }
    }

    window.bp_iac_fill2_txts[spec[4]] = {
      defaultImageData: null,
      charStack: charStack,
      full_init_done: false,
      checkbox_checked: (ft == 2 && sv == "true") ? true : false,
      location_spec: spec,
      set_value: sv,
      editable: ft != 3 ? (dv == "" || window.bp_iac_requestorMode)
        : iacGetSignatureEditable(elem),
      field_type: ft,
      signature_info: ft != 3 ? {
        filled: false,
        audit_start: null,
        audit_end: null,
        signatureData: null,
      } : iacGetSignatureInfo(elem, spec[4]),
      highlighted: false
    };
  }

  iacAddCanvasRenderHook("model/defaultValue", () => {
    for (const spec of window.bp_iac_locationSpecs) {
      var fieldId = spec[4];
      var fd = window.bp_iac_fill2_txts[fieldId];

      if (window.bp_iac_setupMode) {
        iacDrawFieldTypeInto(spec);
      }

      if (fd.checkbox_checked == true ||
        (fd.set_value != null && fd.set_value != "") ||
        fd.field_type == 3) {

        // trigger a redraw
        if (window.bp_iac_fill2_txts[fieldId].full_init_done == false) {
          iacInitFieldDescriptor(spec, fieldId);
        }

        iacRefreshText(spec, true);
      }
    }
  });

  /* 
   * add a click listener to the PDF, so that we can
   * focus the field that is clicked
   */
  canvas.addEventListener('click', ($ev) => {
    var rect = canvas.getBoundingClientRect(),
        scaleX = canvas.width / rect.width,    // relationship bitmap vs. element for X
        scaleY = canvas.height / rect.height; 

    /* calculate the relative coordinates */
    var rX = (($ev.clientX - rect.left) * scaleX) / window.bp_iac_viewportWidth;
    var rY = (($ev.clientY - rect.top) * scaleY) / window.bp_iac_viewportHeight;

    iacDebug(`iac pdf click @ ${rX}/${rY} RAW ${$ev.clientX}/${$ev.clientY} RECT ${rect.left}/${rect.top} MAX ${window.bp_iac_viewportWidth}/${window.bp_iac_viewportHeight}`);

    var spec = iacFindFieldByLocation(rX, rY);

    if (spec != null) {
      // found the field that we clicked on
      // spec[4] has the field id, so we use that to find the field to focus
      iacDebug("found match: " + spec);
      var qString = '[data-iac-field-id="' + spec[4] + '"]';
      iacDebug(qString);

      var fieldType = spec[5];
      var fieldId = spec[4];

      var elem = document.querySelector(qString);
      if (elem == null) {
        alert("Fatal: Didn't find the field, but found a match?");
      } else {
        if (window.bp_iac_fillAllowed) {
          if (window.bp_iac_fill_version == 1) {
            if (elem.tagName == "TBODY") {
              elem.scrollIntoViewIfNeeded();
              elem.dispatchEvent(new Event('mouseenter'));
            } else {
              elem.focus();
            }
          } else if (window.bp_iac_fill_version == 2) {
            if (!window.bp_iac_fill2_txts[fieldId].editable) {
              return;
            }
            /* in place fill enabled */
            if (fieldType == 1) {
              // text field, so set this as the current
              window.bp_iac_fill2_spec = spec;
              iacTabUpdate(spec, true);
            } else if (fieldType == 2) {
              // selection
              iacToggleCheckbox(spec);
              iacTabUpdate(spec, false);
            } else if (fieldType == 3) {
              // signature
              iacDispatchSignature(spec);
              iacTabUpdate(spec, false);
            }
          } else {
            alert("FATAL: broken IAC fill version, applying failsafe as v1");
            window.bp_iac_fill_version = 1;
          }
        }
      }
    }
  });

  /* add the event listener for keypresses */
  window.addEventListener('keypress', (ev) => {
    if (window.bp_iac_fill_version != 2 || window.bp_iac_fillAllowed == false) {
      return;
    }

    /* check if a field has been correctly selected */
    if (window.bp_iac_fill2_spec != null) {
      /* log for debugging TODO */
      iacDebug(ev);

      /* append the character to the text */
      iacPushChar(window.bp_iac_fill2_spec, ev.key);

      /* stop the event propagation so it does not scroll the view */
      ev.stopPropagation();
      ev.preventDefault();
    }
  });

  /* focused text marker */
  window.bp_iac_marker = {
    enabled: true,
    visible: false,
    prevImageData: null,
  };
  window.setInterval(() => {
    iacToggleTextMarker();
  }, 500);

  canvas.addEventListener('mousemove', ($e) => {
    var rect = canvas.getBoundingClientRect();
    var mousex = parseInt($e.clientX - rect.left);
    var mousey = parseInt($e.clientY - rect.top);
    var scaleX = canvas.width / rect.width,    // relationship bitmap vs. element for X
        scaleY = canvas.height / rect.height; 
    var spec = iacFindFieldByLocation((mousex * scaleX) / window.bp_iac_viewportWidth, (mousey * scaleY) / window.bp_iac_viewportHeight);

    if (spec != null) {
      // the mouse is currently over a valid field
      iacHightlightField(spec, false);
      //alert(`entered ${spec[4]}`);
    }

    if (spec == null) {
      iacUnhightlightAll();
    }
  });
}

/* GET /verify/signature */
function sig_verify_init() {
  var submitBtn = document.querySelector('[data-action=iac-submit-for-verification]');
  var vsigTxt = document.getElementById('iac-vsig-txt');

  submitBtn.addEventListener('click', () => {
    document.location = document.location.href.replace(document.location.pathname,
      '/verify/signature/' + vsigTxt.value);
  });
}

/* initialize the canvas for rendering the PDF */
function location_select_init() {
  var pdfjsLib = window['pdfjs-dist/build/pdf'];
  pdfjsLib.GlobalWorkerOptions.workerSrc = '//mozilla.github.io/pdf.js/build/pdf.worker.js';
  var did = document.getElementById('bp-iac-raw-document-id').value;
  var fieldid = document.getElementById('bp-iac-field-id').value;
  var url = '/iac/' + did + '/download';
  var canvas = document.getElementById('bp-iac-canvas');
  var context = canvas.getContext('2d');

  window.bp_sig_location_stage = 0;
  window.bp_sig_location_1x = 0;
  window.bp_sig_location_1y = 0;
  window.bp_sig_location_2x = 0;
  window.bp_sig_location_2y = 0;

  var loadingTask = pdfjsLib.getDocument(url);
  loadingTask.promise.then(function(pdf) {
    if (window.bp_iac_multipageIAC.enabled) {
      // get the number of pages
      window.bp_iac_multipageIAC.pageCount = pdf.numPages;
      window.bp_iac_multipageIAC.pdfObject = pdf;
    }
    pdf.getPage(window.bp_iac_multipageIAC.currentPage + 1).then(function(page) {
      var scale = 5;
      var viewport = page.getViewport({ scale: scale, });

      canvas.height = viewport.height;
      canvas.width = viewport.width;
      window.bp_iac_viewportWidth = viewport.width;
      window.bp_iac_viewportHeight = viewport.height;
      canvas.style.width = "100%";

      var renderContext = {
        canvasContext: context,
        viewport: viewport
      };
      page.render(renderContext).promise.then(function() {
        var $locationField = document.getElementById("bp-iac-location-spec");
        var locationData = $locationField.value.split(" ");
        var locationType = parseInt(locationData[0]);
        var locationValue1 = parseFloat(locationData[1]);
        var locationValue2 = parseFloat(locationData[2]);
        var locationValue3 = parseFloat(locationData[3]);
        var locationValue4 = parseFloat(locationData[4]);
        // var locationValue5 = parseFloat(locationData[5]);
        // var locationValue6 = parseFloat(locationData[6]);

        /* now render the previous location */
        var sX = locationValue2 * window.bp_iac_viewportWidth;
        var sY = locationValue1 * window.bp_iac_viewportHeight;
        var sW = locationValue3 * window.bp_iac_viewportWidth;
        var sH = locationValue4 * window.bp_iac_viewportHeight;
        context.strokeStyle = "rgba(46, 134, 171, 50)";
        context.strokeRect(sX, sY, sW, sH);

        window.bp_iac_canvasRendered = true;
        if (window.bp_iac_canvasRenderHooks != undefined) {
          for (let f of window.bp_iac_canvasRenderHooks) {
            iacDebug(`location_select_init: executing hook ${f.id}`);
            f.fu();
            iacDebug(`location_select_init: done executing hook ${f.id}`);
          }
        }

        window.bp_iac_canvasHooksDone = true;
        window.bp_iac_pdfData = context.getImageData(0, 0, window.bp_iac_viewportWidth, window.bp_iac_viewportHeight);
      });
    });
  }).then(() => {
  });

  iacAddCanvasRenderHook("locationSelect/borders", () => {
    window.bp_iac_locationSpecs = iacCreateLocationSpecs();
    iacDrawBordersAroundFields();
    for (const spec of window.bp_iac_locationSpecs) {
      iacDrawFieldTypeInto(spec);
    }
  });

  /* setup the canvas so that clicks are registered */
  var oldMethod = false;
  if (oldMethod) {
    canvas.addEventListener('click', ($ev) => {
      var rect = canvas.getBoundingClientRect();
      var scaleX = canvas.width / rect.width,    // relationship bitmap vs. element for X
          scaleY = canvas.height / rect.height;
      var xVal = ($ev.clientX - rect.left) * scaleX;
      var yVal = ($ev.clientY - rect.top) * scaleY;
      alert("xVal:" + xVal + " (max: " + window.bp_iac_viewportWidth + "), yVal: " + yVal + " (max: " + window.bp_iac_viewportHeight + ")");
      if (window.bp_sig_location_stage == 0) {
        window.bp_sig_location_1x = xVal;
        window.bp_sig_location_1y = yVal;
        window.bp_sig_location_stage = 1;
      } else if (window.bp_sig_location_stage == 1) {
        window.bp_sig_location_2x = xVal;
        window.bp_sig_location_2y = yVal;

        /* submit the rectangle selection */
        alert("submitting the data....");
        var formData = new FormData();
        var csrf_token = document.getElementById('iac-sig-csrf_token').value;
        formData.append("x1", window.bp_sig_location_1x);
        formData.append("y1", window.bp_sig_location_1y);
        formData.append("x2", window.bp_sig_location_2x);
        formData.append("y2", window.bp_sig_location_2y);
        formData.append("width", window.bp_iac_viewportWidth);
        formData.append("height", window.bp_iac_viewportHeight);
        fetch('/iac/' + did + '/' + fieldid + '/signature_location', {
          method: 'POST',
          credentials: 'include',
          headers: {
            'x-csrf-token': csrf_token
          },
          body: formData
        }).then(response => response.text())
          .then(txt => {
            if (txt != "OK") {
              iacDebug(txt);
            } else {
              document.location = document.location.href.replace(document.location.pathname,
                '/iac/' + did + '/setup');
            }
          });
        window.bp_sig_location_stage = 0;
      }
    });
  } else {
    /* new method */
    canvas.addEventListener('mousedown', ($e) => {
      var rect = canvas.getBoundingClientRect();
      var scaleX = canvas.width / rect.width,    // relationship bitmap vs. element for X
          scaleY = canvas.height / rect.height;
      window.bp_iac_last_mousex = parseInt(($e.clientX - rect.left) * scaleX);
      window.bp_iac_last_mousey = parseInt(($e.clientY - rect.top) * scaleY);
      window.bp_iac_mousedown = true;
      window.bp_iac_final_mousex = null;
      window.bp_iac_final_mousey = null;
    });
    canvas.addEventListener('mouseup', ($e) => {
      window.bp_iac_mousedown = false;
      var rect = canvas.getBoundingClientRect();
      var scaleX = canvas.width / rect.width,    // relationship bitmap vs. element for X
          scaleY = canvas.height / rect.height;

      // save to the window
      window.bp_iac_final_mousex = parseInt(($e.clientX - rect.left) * scaleX);
      window.bp_iac_final_mousey = parseInt(($e.clientY - rect.top) * scaleY);
    });
    canvas.addEventListener('mousemove', ($e) => {
      var rect = canvas.getBoundingClientRect();
      var scaleX = canvas.width / rect.width,    // relationship bitmap vs. element for X
          scaleY = canvas.height / rect.height; 
      var mousex = parseInt(($e.clientX - canvas.getBoundingClientRect().left) * scaleX);
      var mousey = parseInt(($e.clientY - canvas.getBoundingClientRect().top) * scaleY);
      if (window.bp_iac_mousedown) {
        context.putImageData(window.bp_iac_pdfData, 0, 0);
        context.beginPath();
        var pWidth = mousex - window.bp_iac_last_mousex;
        var pHeight = mousey - window.bp_iac_last_mousey;
        context.rect(window.bp_iac_last_mousex, window.bp_iac_last_mousey, pWidth, pHeight);
        context.strokeStyle = 'red';
        context.lineWidth = 5;
        context.stroke();
      }
    });

    document.querySelector("[data-action=savelocation]").addEventListener('click', (e) => {
      var formData = new FormData();
      var csrf_token = document.getElementById('iac-sig-csrf_token').value;
      if (window.bp_iac_last_mousex != null) {
        formData.append("x1", Math.min(window.bp_iac_last_mousex, window.bp_iac_final_mousex));
        formData.append("y1", Math.max(window.bp_iac_last_mousey, window.bp_iac_final_mousey));
        formData.append("x2", Math.max(window.bp_iac_last_mousex, window.bp_iac_final_mousex));
        formData.append("y2", Math.min(window.bp_iac_last_mousey, window.bp_iac_final_mousey));
        formData.append("page", window.bp_iac_multipageIAC.currentPage);
        formData.append("width", window.bp_iac_viewportWidth);
        formData.append("height", window.bp_iac_viewportHeight);
        fetch('/iac/' + did + '/' + fieldid + '/signature_location', {
          method: 'POST',
          credentials: 'include',
          headers: {
            'x-csrf-token': csrf_token
          },
          body: formData
        }).then(response => response.text())
          .then(txt => {
            if (txt != "OK") {
              iacDebug(txt);
            } else {
              document.location = document.location.href.replace(document.location.pathname,
                `/iac/${did}/setup?np=${window.bp_iac_multipageIAC.currentPage}`);
            }
          });
      } else {
        alert("Please choose a location for the field before trying to save it.");
      }
    });
  }

}

/* Submits  the _current_ state of the form.
 *
 * Does NOT save.
 *
 * ONLY CALLED IN RECIPIENT MODE.
 */
function iacSubmitForm() {
  iacDebug("Submitting form...");
  if (window.bp_iac_requestorMode) {
    alert("iacSubmitForm must not be called in requestorMode, results undefined.");
  }
  var rid = document.getElementById('iac-fill-recipient-id').value;
  var aid = document.getElementById('iac-fill-assignment-id').value;
  var tid = document.getElementById('bp-internal-rdid').value;

  window.location = '/iac/' + rid + '/' + aid + '/' + tid + '/submit';
}

function iacSaveForm() {
  var formData = new FormData();
  var rid = document.getElementById('iac-fill-recipient-id').value;
  var aid;
  if (window.bp_iac_requestorMode) {
    aid = document.getElementById('iac-fill-contents-id').value;
  } else {
    aid = document.getElementById('iac-fill-assignment-id').value;
  }
  var tid = document.getElementById('bp-internal-rdid').value;
  var csrf_token = document.getElementById('iac-fill-csrf_token').value;

  for (const spec of window.bp_iac_locationSpecs) {
    var fieldId = spec[4];

    var fd = window.bp_iac_fill2_txts[fieldId];
    if (!fd.full_init_done) {
      continue;
    }

    if (`${fd.field_type}` == "1") {
      formData.append(`iac-text-field-${fieldId}`, fd.charStack.join(""));
    }
    if (`${fd.field_type}` == "2") {
      formData.append(`iac-radio-field-${fieldId}`, fd.checkbox_checked ? "true" : "false");
    }
  }

  // iacRadioInputs.forEach(($f) => {
    // if ($f.checked) {
      // formData.append("iac-radio-field-" + $f.dataset['iac-field-id'], "true");
    // } else {
      // formData.append("iac-radio-field-" + $f.dataset['iac-field-id'], "false");
    // }
  // });
  var base_url;
  if (window.bp_iac_requestorMode) {
    base_url = '/iac/' + rid + '/' + aid + '/' + tid + '/rfill';
  } else {
    base_url = '/iac/' + rid + '/' + aid + '/' + tid + '/fill';
  }
  return fetch(base_url, {
    method: 'POST',
    credentials: 'include',
    headers: {
      'x-csrf-token': csrf_token
    },
    body: formData
  });
}

function iacTabUpdate(spec, update) {
  // find the spec in the ordered list and update the currentIndex
  for (let i = 0; i < window.bp_iac_tabState.orderedSpecs.length; i ++) {
    if (window.bp_iac_tabState.orderedSpecs[i] == spec) {
      __iacTabUpdate(spec, i, update);
      return;
    }
  }

  alert("Critical: Clicked on a field that isn't ordered?");
}

function __iacTabUpdate(spec, idx, update) {
  iacUnhightlightAll();
  var fieldId = spec[4];
  if (update && window.bp_iac_fill2_txts[fieldId].editable) {
    iacHightlightField(spec, false);
    window.bp_iac_fill2_spec = spec;
  } else {
    window.bp_iac_fill2_spec = null;
  }
  window.bp_iac_tabState.currentIndex = idx;
}

function iacTabHandlerInit() {
  // initialize the ordering
  let orderedSpecs = window.bp_iac_locationSpecs;
  orderedSpecs = orderedSpecs
    .sort((f, s) => {
      // sort by page
      if (f[6] < s[6]) { return -1; }
      if (f[6] > s[6]) { return 1; }
      if (f[6] == s[6]) {
        // sort by baseY's 10%
        let fY = Math.floor(f[2] * 100);
        let sY = Math.floor(s[2] * 100);
        if (fY < sY) { return -1; }
        if (fY > sY) { return 1; }
        if (fY == sY) { 
          // sort by baseX's 10%
          let fX = Math.floor(f[0] * 100);
          let sX = Math.floor(s[0] * 100);
          if (fX < sX) { return -1; }
          if (fX > sX) { return 1; }
          if (fX == sX) { return 0; }
        }
      }
    })
  window.bp_iac_tabState.orderedSpecs = orderedSpecs;
  window.bp_iac_tabState.enabled = true;
  window.bp_iac_tabState.currentIndex = -1;

  document.addEventListener('keydown', ($ev) => {
    if ($ev.key === 'Tab' || $ev.key === 'Enter') {
      // Filter down to the current page so that we don't switch pages while Tabbing
      let currentPage = window.bp_iac_multipageIAC.currentPage;
      let thisPageSpecs = Array.from(window.bp_iac_tabState.orderedSpecs)
        .filter((e) => { return e[6] == currentPage });
      let numItems = thisPageSpecs.length;

      let offset = 1;
      if ($ev.shiftKey) {
        offset = -1;
      }
      let nextIndex = window.bp_iac_tabState.currentIndex + offset;
      let effectiveIndex = ((nextIndex % numItems) + numItems) % numItems;
      let nextSpec = thisPageSpecs[effectiveIndex];

      __iacTabUpdate(nextSpec, effectiveIndex, nextSpec[5] == 1);

      // Don't let the browser fallback to normal handling
      $ev.preventDefault();
    }
  });
} 

/* initialize for the recipient */
function recipient_init() {
  /* find the save button first */
  var saveBtns = document.querySelectorAll("[data-action=iac-save-form]");

  /* find the s&s button */
  var submitBtn = document.querySelector("[data-action=iac-submit-form]");

  /* Setup the model */
  window.bp_iac_fillAllowed = true;
  iac_model_init();

  /* initialize signature support */
  iacInitSignaturePad();

  /* initialize eSign-consent support */
  iacEsignInit();

  /* initialize the tab handling */
  iacTabHandlerInit();

  /*
   * Add a click listener to the button to post form via fetch()
   *
   * Since it's a form, we'd need a CSRF token for each save.
   * For the first version of IAC, we opt out of this and just redirect.
   * the user to the plz_sign page. This is less than ideal so a follow-up
   * ticket has been filled: #1356
   */
  saveBtns.forEach(($btn) => { $btn.addEventListener('click', () => {
    if (window.bp_iac_requestorMode) {
      iacSaveForm().then(() => {
        let contentsId = document.getElementById('iac-fill-contents-id').value;
        let recipientId = document.getElementById('iac-fill-recipient-id').value;
        window.location = `/package/${contentsId}/${recipientId}/customize`;
      });
    } else {
      iacSaveForm().then(() => {
        window.location = `/user`;
      });
    }
  });
  });

  if (submitBtn != null) {
    submitBtn.addEventListener('click', () => {
      /* save the form first */
      iacSaveForm().then(iacSubmitForm);
    });
  }

  /* 
   * Ok, we've finished setting up the save button, let's setup the preview
   * button. Its task is to create the PDF *temporarily*.
   */
  var previewBtn = document.querySelector("[data-action=iac-preview-form]");
  if (previewBtn != null) {
    previewBtn.addEventListener('click', () => {
      iacSaveForm().then(() => {
        if (window.bp_iac_requestorMode) {
          alert("previewBtn must only be clicked in RECIPIETN MODE, this is undefined behavior");
        }
        var rid = document.getElementById('iac-fill-recipient-id').value;
        var aid = document.getElementById('iac-fill-assignment-id').value;
        var tid = document.getElementById('bp-internal-rdid').value;
        document.location = document.location.href.replace(document.location.pathname,
          "/iac/" + rid + "/" + aid + "/" + tid + "/preview");
      });
    });
  }
}

/* Called during package customization */
function customize_init() {
  document.querySelectorAll('[data-role=bp-iac-requestor-fill]').forEach(($el) => {
    $el.addEventListener('click', () => {
      let rsdId = $el.dataset["rsdid"];
      let contentsId = $el.dataset["contentsid"];
      let recipientId = $el.dataset["recipientid"];

      window.location = `/iac/${recipientId}/${contentsId}/${rsdId}/rfill`;
    });
  });
}

function iacMultipageInit() {
  document.getElementById('bp-iac-pagenumber').innerHTML = `Page ${window.bp_iac_multipageIAC.currentPage + 1} / ${window.bp_iac_multipageIAC.pageCount}`;

  if (window.bp_iac_multipageIAC.initDone) {
    // refuse to readd the listeners.
    return;
  }

  /* initialize multipage specific stuff */
  document.querySelectorAll('[data-action=bp-iac-prevpage]').forEach(($e) => { $e.addEventListener('click', () => {
    let nextPage = window.bp_iac_multipageIAC.currentPage - 1;
    if (nextPage < 0) {
      nextPage = 0;
    }
    iacSwitchPage(nextPage);
  })});

  document.querySelectorAll('[data-action=bp-iac-nextpage]').forEach(($e) => { $e.addEventListener('click', () => {
    let nextPage = window.bp_iac_multipageIAC.currentPage + 1;
    if (nextPage > window.bp_iac_multipageIAC.pageCount - 1) {
      nextPage = window.bp_iac_multipageIAC.pageCount - 1;
    }
    iacSwitchPage(nextPage);
  })});

  window.bp_iac_multipageIAC.initDone = true;
}

/* Main module entry point - runs on DOMContentLoaded */
function init() {
  let isIac = false;
  /* Check if this is an IAC page */
  if (window.location.pathname.includes('/fill') || window.location.pathname.includes('/rfill')) {
    /* Recipient-side */
    window.bp_iac_requestorMode = document.getElementById('iac-fill-ptype').value == "true";
    recipient_init();
    isIac = true;
  } else if (window.location.pathname.includes('/signature') && !window.location.pathname.includes('verify')) {
    /* location select on the requestor side */
    location_select_init();
    isIac = true;
  } else if (document.querySelector('[data-action=iac-submit-for-verification]') != undefined) {
    /* signature verification */
    sig_verify_init();
    isIac = false;
  } else if (document.querySelector('[data-iac-page-role=setup]') != undefined) {
    /* IAC setup */
    setup_init();
    isIac = true;
  } else if (document.querySelector('[data-iac-page-role=customize]') != undefined) {
    /* package customization screen with active IAC RSD */
    customize_init();
    isIac = false;
  }

  if (isIac && window.bp_iac_multipageIAC.enabled) {
    iacAddCanvasRenderHook("multipage/init", iacMultipageInit);
  }

  /* Not an IAC page - do nothing. */
}

/* Export ourselves */
var iac = {
  init: () => {
    window.bp_iac_fill_version = 2;
    window.bp_iac_fill2_spec = null;
    window.bp_iac_debugEnabled = findGetParameter("dbg") == "true";
    window.bp_iac_setupMode = false;
    let mpbp = document.getElementById('iac-multipage-basepage');
    if (mpbp != undefined) {
      mpbp = parseInt(mpbp.value);
    } else {
      mpbp = 0;
    }
    window.bp_iac_multipageIAC = {
      enabled: true,
      pageCount: 0,
      currentPage: mpbp,
      initDone: false,
      pdfObject: null,
    }
    window.bp_iac_tabState = {
      enabled: false,
      active: false,
      currentIndex: 0,
      orderedSpecs: [],
    };
    init();
  }
}

export default iac;
