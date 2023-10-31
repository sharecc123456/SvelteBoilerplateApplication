function getAll(selector) {
  return Array.prototype.slice.call(document.querySelectorAll(selector), 0);
}

function hideTabLink(link) {
  const $target = link.dataset.target;
  var target = document.getElementById($target);
  target.classList.add('is-hidden');

  /* remove is-active */
  link.parentElement.classList.remove('is-active');
}

function getTabTarget() {
  if (window.location.pathname.includes("admin")) {
    var $tabTargetObj = document.getElementById('bp-admin-tab_target')
    if ($tabTargetObj != null) {
      const $tabTarget = $tabTargetObj.value;
      return "bp-admin-" + $tabTarget;
    } else {
      return "bp-admin-details";
    }
  } else if (window.location.pathname.includes("assign") || window.location.pathname.includes("customize")) {
    var $tabTargetObj = document.getElementById('bp-customize-tab_target')
    if ($tabTargetObj != null) {
      const $tabTarget = $tabTargetObj.value;
      return "bp-customize-" + $tabTarget;
    } else {
      return "bp-customize-rsds";
    }
  } else {
    var $tabTargetObj = document.getElementById('bp-dashboard-tab-target')
    if ($tabTargetObj != null) {
      const $tabTarget = $tabTargetObj.value;
      return "bp-dash-" + $tabTarget;
    } else {
      return "bp-dash-overview";
    }
  }
}

function init() {
  const $tabLinks = getAll('.bp-tab-link');
  if ($tabLinks.length == 0) {
    return;
  }
  var actualTarget = getTabTarget();

  /* add event listeners */
  $tabLinks.forEach((link) => {
    link.addEventListener('click', () => {
      const $target = link.dataset.target;
      var target = document.getElementById($target);

      window.analytics.page("Tab " + $target);

      /* hide everything */
      $tabLinks.forEach((l) => hideTabLink(l));

      /* show the one we are interested in */
      target.classList.remove('is-hidden');

      /* dismiss all notifications */
      (document.querySelectorAll('.notification .delete') || []).forEach(($delete) => {
        const $notification = $delete.parentNode;
        $notification.parentNode.removeChild($notification);
      });

      /* migrate a.is-active */
      link.parentElement.classList.add('is-active');
    });
  });

  /* show the one that is marked is-active */
  getAll(".bp-tab-li.is-active").forEach((link) => {
    const $target = link.children[0].dataset.target;
    var target = document.getElementById($target);

    target.classList.remove('is-hidden');
  });

  /* switch to the one in the target */
  $tabLinks.forEach((l) => {
    hideTabLink(l);
    if (l.dataset.target == actualTarget) {
      l.parentElement.classList.add('is-active');
      window.analytics.page("Tab " + actualTarget);
    }
  });

  if (getTabTarget() != null) {
    const $theTabTarget = document.getElementById(actualTarget);
    $theTabTarget.classList.remove('is-hidden');
    /* dismiss all notifications */
    //(document.querySelectorAll('.notification .delete') || []).forEach(($delete) => {
      //const $notification = $delete.parentNode;
      //$notification.parentNode.removeChild($notification);
    //});
  }
}

var tablinks = {
  init: () => {
    try {
      init();
    } catch (e) {
      alert("error tablinks: " + e.message);
    }
  },
}

export default tablinks;
