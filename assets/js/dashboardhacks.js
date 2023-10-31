function dh_getAll(selector) {
  return Array.prototype.slice.call(document.querySelectorAll(selector), 0);
}

function add_clickies() {
  var $clickies = dh_getAll(".bp-bc-clicky");
  $clickies.forEach(($c) => {
    $c.addEventListener("click", () => {
      dh_getAll(".bp-bc-clicky").forEach(($cc) => {
        $cc.parentNode.classList.remove("is-active");
      });

      $c.parentNode.classList.add("is-active");

      dh_getAll(".bp-bc-clicky-d").forEach(($cc) => {
        $cc.classList.add("is-hidden");
      });

      const target = $c.dataset.target;
      var $target =
        $c.parentNode.parentNode.parentNode.parentNode.querySelector(
          "#" + target
        );
      $target.classList.remove("is-hidden");
    });
  });
}

function init() {
  var $buts = dh_getAll(".bp-dash-but");
  if ($buts.length != 0) {
    $buts.forEach(($b) => {
      const isn = $b.dataset.pkg == 0;
      if (isn == false) {
        $b.addEventListener("click", () => {
          const target = $b.dataset.target;
          var $target = document.getElementById(target);
          var $place = document.getElementById("bp-dash-message");

          $place.innerHTML = $target.innerHTML;
          add_clickies();
        });
      } else {
        $b.disabled = true;
      }
    });
  }

  var $bdhdd = dh_getAll(".bp-db-has-dash-document");
  var $bdhdp = dh_getAll(".bp-db-has-dash-package");
  var $bdd = dh_getAll(".bp-dash-document");
  var $bdp = dh_getAll(".bp-db-tbody");
  var $cis = dh_getAll(".bp-changing-icon");
  $bdhdd.forEach(($b) => {
    const rid = $b.dataset.target;
    const pid = $b.dataset.package;
    const matching_rids = $bdd.filter(
      (x) =>
        x.getAttribute("foruser") == rid && x.getAttribute("forpackage") == pid
    );
    $b.addEventListener("click", () => {
      var iconele = $b.getElementsByClassName("icon")[0].childNodes[0];
      var curr = iconele.dataset.icon;
      if (curr.trim() == "plus") {
        iconele.dataset.icon = "minus";
      } else {
        iconele.dataset.icon = "plus";
      }
      $b.parentNode.classList.toggle("has-background-light");
      matching_rids.forEach(($c) => {
        $c.classList.toggle("is-hidden");
      });
    });
  });

  $bdhdp.forEach(($b) => {
    const rid = $b.dataset.target;
    const matching_rids = $bdp.filter((x) => x.dataset.target == rid);
    $b.addEventListener("click", () => {
      matching_rids.forEach(($c) => {
        $c.classList.toggle("is-hidden");
      });
    });
  });
}

var dashboardhacks = {
  init: () => {
    init();
  },
};

export default dashboardhacks;
