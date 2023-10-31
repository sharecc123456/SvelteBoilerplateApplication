/*
 * JavaScript for managing modals on all screens
 *
 * data-modal is the base modal's id
 * data-target is the modal-multi-content div inside the data-modal that will
 *   be shown when a modal-button is clicked
 */

var global_modal_aux_a = null;
var global_modal_aux_b = null;
var global_modal_setglobal = null;

function reset_iac_edit_field(type) {
  // Show settable stuff based on the type
  document.getElementById("iac-edit-default-value").classList.add("is-hidden");
  document.getElementById("iac-edit-allow-completion-by-recipient").classList.add("is-hidden");
  document.getElementById("iac-edit-selection-group").classList.add("is-hidden");
  document.getElementById("iac-edit-select-location").classList.add("is-hidden");
  document.getElementById("iac-edit-name").classList.add("is-hidden");
  if (type == "text") {
    document.getElementById("iac-edit-default-value").classList.remove("is-hidden");
    document.getElementById("iac-edit-allow-completion-by-recipient").classList.remove("is-hidden");
  } else if (type == "selection") {
    document.getElementById("iac-edit-default-value").classList.remove("is-hidden");
    document.getElementById("iac-edit-allow-completion-by-recipient").classList.remove("is-hidden");
    document.getElementById("iac-edit-selection-group").classList.remove("is-hidden");
  } else if (type == "signature") {
    document.getElementById("iac-edit-allow-completion-by-recipient").classList.remove("is-hidden");
    document.getElementById("iac-edit-select-location").classList.remove("is-hidden");
  }

  document.getElementById("iac-edit-select-location").classList.remove("is-hidden");

  if (type != "horizontal_line") {
    document.getElementById("iac-edit-name").classList.remove("is-hidden");
  }
}

function do_custom_assign_package(uid, currently_assigned_pid) {
  document.getElementById('bp-company-dash-assign_package-uid').value = uid;

  document.querySelectorAll('.bp-company-dash-assign-radio').forEach((el) => {
    if (el.value == currently_assigned_pid) {
      el.checked = true;
    } else {
      el.checked = false;
    }
  });
}

function do_custom_documentupload(ignore_doc, docid) {
  document.getElementById("bp-documentupload-assignid").value = ignore_doc;
  document.getElementById("bp-documentupload-docid").value = docid;
}

function do_custom_requestupload(ignore_doc, docid, reset) {
  document.getElementById("bp-requestupload-assignid").value = ignore_doc;
  document.getElementById("bp-requestupload-docid").value = docid;
  document.getElementById("bp-requestupload-reset").value = reset;
}

function do_custom_requestfillin(ignore_doc, docid, reset, name) {
  document.getElementById("bp-requestfillin-assignid").value = ignore_doc;
  document.getElementById("bp-requestfillin-docid").value = docid;
  document.getElementById("bp-requestfillin-reset").value = reset;
  document.getElementById("bp-requestfillin-name").innerHTML = "Please enter \"" + name + "\"";
  document.getElementById("bp-requestfillin-name2").placeholder = name;
}

function do_custom_reviewrequest(docid, docname, typename) {
  document.getElementById("bp-db-rr-did").value = docid;
  document.getElementById("bp-db-rr-docname").innerHTML = docname;
  document.getElementById("bp-db-rr-typename").value  = typename;
}

function do_custom_confirm_delete(name, id) {
  document.getElementById("bp-user-cd-name").innerHTML = name;
  document.getElementById("bp-user-cd-delete").href = "/user/" + id + "/delete";
}

function do_custom_confirm_delete_request(uid, aid) {
  document.getElementById("bp-user-cd2-delete").href = "/assignment/" + uid + "/" + aid + "/delete";
}

function do_custom_upload_manual(id, txt, recpid, assignid, type) {
  document.getElementById("bp-db-um-text").innerHTML = "Please select " + txt + " and press <strong>Upload</strong>.";
  document.getElementById("bp-db-um-did").value = id;
  document.getElementById("bp-db-um-uid").value = recpid;
  document.getElementById("bp-db-um-aid").value = assignid;
  document.getElementById("bp-db-um-type").value = type;
}

function do_custom_remind_now(pid, rid) {
  document.getElementById("bp-package-remind-rid").value = rid;
  document.getElementById("bp-package-remind-pid").value = pid;
  document.getElementById("bp-package-remind-msg").value = "";
}

function do_custom_edit_field(value, type, id, dv, sg) {
  var subt = document.getElementById("iac-modal-subtitle")

  // Reset form
  document.getElementById("iac-default-value").value = "";
  document.getElementById("iac-selection-group").value = "";
  document.getElementById("iac-completion-yes").checked = true;
  document.getElementById("iac-completion-no").checked = false;

  // Setup the prompt
  subt.innerHTML = "Field \"" + value + "\" of type " + type;
  document.getElementById("iac-name").value = value;
  document.getElementById("iac-field-id").value = id;
  document.getElementById("iac-default-value").value = dv;
  document.getElementById("iac-edit-type-select").value = type;
  document.getElementById("iac-selection-group").value = sg;

  var rdid = document.getElementById("bp-internal-rdid").value;
  reset_iac_edit_field(type);
  document.getElementById("iac-edit-selection-location-button").href = "/iac/" + rdid + "/" + id + "/signature";
}

function do_custom_iac_setup_edit_field(fieldid, fieldname)
{
  document.getElementById("iac-modal-subtitle").innerHTML = `Editing the field named \"${fieldname}\"`;
  document.getElementById("iac-field-id").value = fieldid;
  document.getElementById("iac-name").value = fieldname;
}

function do_custom_iac_requestor_sign(fid, tid, csrf) {
  window.bp_field_id = fid;
  window.bp_raw_document_id = tid;
  window.bp_csrf_token = csrf;
}

function do_custom(target, auxa, auxb, auxc, auxd, auxe) {
  if (target == "assign_package") {
    do_custom_assign_package(auxa, auxb);
  } else if (target == "documentupload") {
    do_custom_documentupload(auxa, auxb);
  } else if (target == "requestupload") {
    do_custom_requestupload(auxa, auxb, auxc);
  } else if (target == "requestfillin") {
    do_custom_requestfillin(auxa, auxb, auxc, auxd);
  } else if (target == "review_return") {
    do_custom_reviewrequest(auxa, auxb, auxc);
  } else if (target == "confirm_delete") {
    do_custom_confirm_delete(auxa, auxb);
  } else if (target == "confirm_delete_request") {
    do_custom_confirm_delete_request(auxa, auxb);
  } else if (target == "upload_manual") {
    do_custom_upload_manual(auxa, auxb, auxc, auxd, auxe);
  } else if (target == "confirm_remind_request") {
    do_custom_remind_now(auxb, auxa);
  } else if (target == "edit_field") {
    do_custom_edit_field(auxa, auxb, auxc, auxd, auxe);
  } else if (target == "iac_setup_edit_field") {
    do_custom_iac_setup_edit_field(auxa, auxb);
  } else if (target == "iac_requestor_sign" || target == "iac_recipient_sign") {
    do_custom_iac_requestor_sign(auxa, auxb, auxc);
  }
}

/* initialize event listeners */
function init() {
    var rootEl = document.documentElement;
    var $modals = getAll('.modal');
    var $modalButtons = getAll('.modal-button');
    var $modalCloses = getAll('.modal-background, .modal-close, .modal-closer, .modal-card-head .delete, .modal-card-foot .button');

    if ($modalButtons.length > 0) {
      $modalButtons.forEach(function ($el) {
        $el.addEventListener('click', function () {
          var target = $el.dataset.target;
          var modal = $el.dataset.modal;
          if ($el.dataset.custom == "true") {
            do_custom(target, $el.dataset.auxa, $el.dataset.auxb, $el.dataset.auxc, $el.dataset.auxd, $el.dataset.auxe);
          }
          closeModals();
          openModal(modal, target);
        });
      });
    }

    if ($modalCloses.length > 0) {
      $modalCloses.forEach(function ($el) {
        $el.addEventListener('click', function () {
          window.bp_modal_closeReason = $el.dataset["closeReason"];
          closeModals();
        });
      });
    }

    // transplant to iac.js if changed!
    // Not too happy about the need to transplant but we don't have the time
    // right now to fix this debt
    function openModal(modal, target) {
      var $target = document.getElementById(modal);
      if (target != "null") {
        var $m = document.getElementById(target);
        $m.style.display = 'block';
      }
      rootEl.classList.add('is-clipped');
      $target.classList.add('is-active');
    }

    function getAll(selector) {
      return Array.prototype.slice.call(document.querySelectorAll(selector), 0);
    }

    function closeModals() {
      rootEl.classList.remove('is-clipped');
      $modals.forEach(function ($el) {
        $el.classList.remove('is-active');
      });
      getAll('.modal-multi-content').forEach(el => {
        el.style.display = 'none';
      });

      if (window.bp_modal_exitHook) {
        window.bp_modal_exitHook();

        window.bp_modal_exitHook = null;
      }
    }

    document.addEventListener('keydown', function (event) {
      var e = event || window.event;
      if (e.keyCode === 27) {
        closeModals();
      }
    });
}


/* Export ourselves */
var modals = {
  init: () => {
    init();
  },
  reset_iac_edit: (type) => {
    reset_iac_edit_field(type);
  },
}

export default modals;
