// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.scss"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
// import socket from "./socket"

// Add support for modals
import modals from "./modals"
document.addEventListener('DOMContentLoaded', modals.init);

// Navbar burgers
import burgers from "./burgers"
document.addEventListener('DOMContentLoaded', burgers.init);

// tab links
import tablinks from "./tablinks"
document.addEventListener('DOMContentLoaded', tablinks.init);

// pdf rendering
import pdfrenderer from "./pdfrenderer"
document.addEventListener('DOMContentLoaded', pdfrenderer.init);

// dashboard hacks
import dashboardhacks from "./dashboardhacks"
document.addEventListener('DOMContentLoaded', dashboardhacks.init);

// notification stuff
import notifications from "./notifications"
document.addEventListener('DOMContentLoaded', notifications.init);

// stripe stuff
import bpstripe from "./bpstripe"
document.addEventListener('DOMContentLoaded', bpstripe.init);

// IAC stuff
import iac from "./iac"
document.addEventListener('DOMContentLoaded', iac.init);

import JSZip from "../node_modules/jszip";
import { saveAs } from '../node_modules/file-saver';

// dropdowns
var dropdownTriggers = document.querySelectorAll('.dropdown-trigger');
dropdownTriggers.forEach(($trigger) => {
  $trigger.addEventListener('click', (e) => {
    $trigger.parentNode.classList.toggle('is-active');

    dropdownTriggers.forEach(($t) => {
      if ($t != $trigger) {
        $t.parentNode.classList.remove('is-active');
      }
    });

    e.stopPropagation();
  });
});

if (dropdownTriggers.length > 0) {
  document.addEventListener('click', function(e) {
    dropdownTriggers.forEach(el => {
      el.parentNode.classList.remove('is-active');
    });
  });
}

// bp-rr-shortcut
var rrshortcuts = document.querySelectorAll('.bp-rr-shortcut');
rrshortcuts.forEach(($rr) => {
  $rr.addEventListener('click', () => {
    var form = document.getElementById('bp-review-return-form');
    var did = document.getElementById('bp-db-rr-did');
    var typename = document.getElementById('bp-db-rr-typename');
    var textarea = document.getElementById('bp-db-rr-text');

    var md = $rr;
    do {
      md = md.nextElementSibling;
    } while (md != null && !md.classList.contains('modal-button'));

    did.value = md.dataset.auxa;
    typename.value = md.dataset.auxc;
    textarea.value = $rr.innerHTML;
    textarea.innerHTML = $rr.innerHTML;

    form.submit();
  });
});

document.addEventListener('DOMContentLoaded', () => {
  const $packageDocs = document.querySelectorAll('.bp-package-doc');
  const $packageId = document.getElementById('bp-current-package-id');

  if ($packageId != null) {
    var pid = $packageId.value;
    $packageDocs.forEach(($pd) => {
      $pd.addEventListener('click', () => {
        fetch('/package/' + pid + '/toggle/document/' + $pd.dataset.target);
      });
    });
  }
});

document.addEventListener('DOMContentLoaded', () => {
  const $packageDocs = document.querySelectorAll('.bp-contents-doc');
  const $contentsId = document.getElementById('bp-current-contents-id');

  if ($contentsId != null) {
    var cid = $contentsId.value;
    $packageDocs.forEach(($pd) => {
      $pd.addEventListener('click', () => {
        fetch('/package/contents/' + cid + '/toggle/document/' + $pd.dataset.target).then((response) => {
          if ($pd.dataset.rsd == "true") {
            if ($pd.checked == true) {
              window.location.href = window.location.href.split('?')[0] + '?tab=rsds';
            } else {
              window.location.href = window.location.href.split('?')[0] + '?tab=contents';
            }
          } else if ($pd.dataset.rsd == "extra") {
            window.location.href = window.location.href.split('?')[0] + '?tab=contents';
          }
        });
      });
    });
  }
});

var theupload = document.querySelectorAll('.bp-rsd-upload-button');
theupload.forEach(($el) => {
  $el.addEventListener('change', () => {
    var rsdid = $el.dataset.target;
    document.getElementById('bp-the-upload-form-'+rsdid).submit();
  });
});

// customize_package
var xyz  = document.getElementById('bp-customize-due_date-checkbox');
if (xyz != null) {
  xyz.addEventListener('click', () => {
    if (xyz.checked) {
      document.getElementById('bp-customize-hidden-form-enforce-due-date').value = "true";
      document.getElementById('bp-customize-due_date-div').classList.remove('is-hidden');
    } else {
      document.getElementById('bp-customize-hidden-form-enforce-due-date').value = "false";
      document.getElementById('bp-customize-due_date-div').classList.add('is-hidden');
    }
  });
}

document.querySelectorAll('.bp-customize-send').forEach(($e) => {
  $e.addEventListener('click', () => {
    document.getElementById('bp-customize-hidden-form').submit();
  });
});

$( function() {
  $( "#bp-customize-due_date-date" ).datepicker({ dateFormat: 'yy-mm-dd', onClose: (dt, inst) => {
      document.getElementById('bp-customize-hidden-form-due-date').value = dt;
  }});
} );

document.querySelectorAll('.bp-submit-on-enter').forEach(($e) => {
  $e.addEventListener('keydown', (ev) => {
    if (ev.keyCode == 13) {
      $e.form.submit();
      return false;
    }
  });
});

/*
document.querySelectorAll('.bp-download-all').forEach(($downloadAllBtn) => {
  $downloadAllBtn.addEventListener('click', () => {
    var zip = new JSZip();
    var domain = "";
    document.querySelectorAll('.bp-internal-document-download').forEach(($link) => {
      var initParms = {  
        method: "GET",
        credentials: 'include'
      };
      console.log($link.href);
      fetch(domain + $link.href, initParms).then(response => {
        if (response.ok) {
          response.headers.forEach(function(val, key) { console.log(key + ' -> ' + val); });
          var filename = "file-01.pdf";
          return [response.blob(), filename];
        }

        throw new Error("failed GET");
      }).then(inp => {
        var blob = inp[0];
        var filename = inp[1];

        zip.file(filename, blob, {binary:true});
      });
    });

    zip.generateAsync({ type: "blob" }).then(function(content) {
      saveAs(content, "boilerplate-export.zip");
    });
  });
});
*/

var passwordFields = document.querySelectorAll('.bp-password-input');
if (passwordFields.length > 0) {
  var submitField = document.querySelectorAll('.bp-password-submit')[0];
  submitField.disabled = true;
  submitField.title = "Your password must meet the minimum requirements of being at least 8 characters long.";

  passwordFields.forEach(($passwordField) => {
    $passwordField.addEventListener('keyup', () => {
      $passwordField.classList.remove('has-text-success');
      $passwordField.classList.remove('has-text-danger');
      if ($passwordField.value.length >= 8) {
        $passwordField.classList.add('has-text-success');
        submitField.disabled = false;
        submitField.title = "";
      } else {
        $passwordField.classList.add('has-text-danger');
        submitField.title = "Your password must meet the minimum requirements of being at least 8 characters long.";
        submitField.disabled = true;
      }
    });

    $passwordField.addEventListener('focus', () => {
      $passwordField.classList.remove('has-text-success');
      $passwordField.classList.remove('has-text-danger');
      if ($passwordField.value.length >= 8) {
        $passwordField.classList.add('has-text-success');
      } else {
        $passwordField.classList.add('has-text-danger');
      }
    });

    $passwordField.addEventListener('blur', () => {
      $passwordField.classList.remove('has-text-success');
      $passwordField.classList.remove('has-text-danger');
    });
  });
}


// Signatures

document.querySelectorAll('.bp-signature-pad').forEach(($pad) => {
  $pad.width = 600;
  $pad.height = 150;
  var signaturePad = new SignaturePad($pad, {
    backgroundColor: 'rgba(255, 255, 255, 0)',
    penColor: "rgba(0, 0, 0, 100)"
  });
  window.bp_iac_signaturePad = signaturePad;
  var clearButton = document.querySelector("[data-action=bp-sig-clear]");
  clearButton.addEventListener("click", function (event) {
    signaturePad.clear();
  });

  var undoButton = document.querySelector("[data-action=bp-sig-undo]");
  undoButton.addEventListener("click", function (event) {
    var data = signaturePad.toData();

    if (data) {
      data.pop(); // remove the last dot or line
      signaturePad.fromData(data);
    }
  });

  var saveButton = document.querySelector("[data-action=bp-sig-save]");
  saveButton.addEventListener("click", function (event) {
    if (window.bp_iac_fill_version == 2) {
      // unused in ipf/v2fill
      return;
    }
    

    if (signaturePad.isEmpty()) {
      alert("Please provide a signature first.");
    } else {
      var dataURL = signaturePad.toDataURL();
      var formData = new FormData();
      var tid = window.bp_raw_document_id;
      var fid = window.bp_field_id;
      let isRequestor = false;
      if (window.bp_iac_requestorMode) {
        isRequestor = true;
      }
      var csrf_token = window.bp_csrf_token;
      formData.append("signature_dataurl", dataURL);
      formData.append("requestor", isRequestor);
      fetch('/iac/' + tid + '/' + fid + '/signature', {
        method: 'POST',
        credentials: 'include',
        headers: {
          'x-csrf-token': csrf_token
        },
        body: formData
      }).then(response => response.text())
        .then(txt => {
          console.log(txt)
          window.location.reload();
        });
    }
  });
});

// IAC
document.querySelectorAll('#iac-edit-type-select').forEach(($v) => {
  $v.addEventListener('change', () => {
    modals.reset_iac_edit($v.value);
  });
});
