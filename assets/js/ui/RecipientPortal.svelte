<script>
  import Dashboard from "./pages/recipient_portal/Dashboard.svelte";
  import "../../css/styles.css";
  import AssignmentView from "./pages/recipient_portal/AssignmentView.svelte";
  import SubmissionView from "./pages/recipient_portal/SubmissionView.svelte";
  import IacFill from "./iac/IacFill.svelte";
  import FormFill from "./components/Form/FormFill.svelte";
  import { onMount, onDestroy } from "svelte";
  import { getAssignments } from "BoilerplateAPI/Assignment";
  import Footer from "./util/Footer.svelte";
  import { initializePaperCups } from "../paperCups";
  import { searchParamObject, isMobile } from "../helpers/util";
  import AutoLogout from "../helpers/autologout";
  import ConfirmationDialog from "./components/ConfirmationDialog.svelte";
  import {
    sessionStorageGet,
    sessionStorageHas,
    sessionStorageSave,
  } from "../helpers/sessionStorageHelper";

  function getHash() {
    var theHash = window.location.hash;
    if (theHash.length == 0) {
      theHash = "#dashboard";
    }
    return theHash;
  }

  var hash = getHash();
  var component;
  var props;
  var show_footer = true;
  function doRouting(rid) {
    hash = getHash();

    if (hash.startsWith("#assignment/")) {
      let targetAssignment = parseInt(hash.substr("#assignment/".length));
      component = AssignmentView;
      props = {
        avatarInitials: avatarInitials,
        assignmentId: targetAssignment,
        assignment: getAssignments().then(
          (b) => Array.from(b).filter((a) => a.id == targetAssignment)[0]
        ),
      };
    } else if (hash.match(/\#iac\/fill\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#iac\/fill\/(\d+)\/(\d+)/);
      component = IacFill;
      const requestParams = searchParamObject();
      const checklistName = requestParams?.name || "";
      const editableDoc = requestParams?.edit || false;
      const ref = requestParams.ref || "";
      const iacDocId = tag[1];

      props = {
        iacDocId: iacDocId,
        fillType: "recipient",
        recipientId: rid,
        assignmentId: parseInt(tag[2], 10),
        checklistName: checklistName ? decodeURIComponent(checklistName) : "",
        reference: ref ? "(" + decodeURIComponent(ref) + ")" : "",
        editableDoc,
      };
    } else if (hash.match(/\#submission\/view\/(\d+)\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#submission\/view\/(\d+)\/(\d+)\/(\d+)/);
      component = SubmissionView;
      const requestParams = searchParamObject();
      props = {
        specialId: parseInt(tag[1], 10),
        assignmentId: parseInt(tag[2], 10),
        documentId: parseInt(tag[3], 10),
        fillType: "recipient",
      };
    } else if (hash.match(/\#view\/(\d+)\/(\d+)/)) {
      component = SubmissionView;
      let tag = hash.match(/\#view\/(\d+)\/(\d+)/);
      props = {
        specialId: 4,
        documentId: parseInt(tag[2], 10),
        assignmentId: parseInt(tag[1], 10),
        fillType: "recipient",
      };
    } else if (hash.match(/\#form\/fill\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#form\/fill\/(\d+)\/(\d+)/);
      component = FormFill;

      props = {
        assignmentId: tag[2],
        formId: tag[1],
        fillType: "recipient",
        avatarInitials: avatarInitials,
        recipientId: rid,
        editableForm: true,
      };
    } else if (hash.match(/\#form\/view\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#form\/view\/(\d+)\/(\d+)/);
      component = FormFill;

      props = {
        assignmentId: tag[2],
        formId: tag[1],
        fillType: "recipient",
        recipientId: rid,
        editableForm: false,
      };
    } else {
      component = Dashboard;
      props = {
        avatarInitials: avatarInitials,
        assignments: getAssignments(),
      };
    }
  }

  async function getInitials() {
    let user_struct = {};
    if (sessionStorageHas("recipient_info")) {
      user_struct = sessionStorageGet("recipient_info");
    } else {
      let request = await fetch("/n/api/v1/user/me?type=recipient");
      user_struct = await request.json();
      sessionStorageSave("recipient_info", user_struct);
    }

    let name = user_struct.name;
    return name
      .match(/(\b\S)?/g)
      .join("")
      .match(/(^\S|\S$)?/g)
      .join("")
      .toUpperCase();
  }

  async function getRecipientInfo() {
    let user_struct = {};

    if (sessionStorageHas("recipient_info")) {
      user_struct = sessionStorageGet("recipient_info");
    } else {
      let request = await fetch("/n/api/v1/user/me?type=recipient");
      user_struct = await request.json();
    }

    return user_struct;
  }

  const avatarInitials = getInitials();
  let autoLogout;
  let showLogoutWarning = false;

  const handleLogoutWarning = () => {
    showLogoutWarning = true;
  };

  const handleLogout = () => {
    window.location = "/logout";
  };

  onMount(() => {
    window.__boilerplate_user_type = "recipient";
    autoLogout = new AutoLogout(handleLogoutWarning, handleLogout);
    getRecipientInfo().then((user) => {
      initializePaperCups(user);
      doRouting(user.id);
    });
  });

  onDestroy(() => {
    autoLogout.destroy();
  });

  $: {
    if (
      isMobile() &&
      (hash.startsWith("#iac/fill") || hash.startsWith("#submission/view"))
    ) {
      show_footer = false;
    }
  }

  function doFirstRouting() {
    getRecipientInfo().then((user) => {
      initializePaperCups(user);
      doRouting(user.id);
    });
  }
</script>

<svelte:head>
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1, maximum-scale=1,user-scalable=0"
  />
</svelte:head>

<svelte:window on:hashchange={doFirstRouting} />
<!-- <p>{hash}</p> -->
<div class="container">
  <svelte:component this={component} {...props} />
</div>
{#if show_footer}
  <div class="footer-container">
    <Footer />
  </div>
{/if}

{#if showLogoutWarning}
  <ConfirmationDialog
    title="Warning! Due to inactivity, you will be logged out in 1 min"
    yesText="Logout"
    noText="Keep me logged in"
    yesColor="primary"
    noColor="danger-white"
    on:yes={() => {
      showLogoutWarning = false;
      handleLogout();
    }}
    on:close={() => {
      showLogoutWarning = false;
    }}
  />
{/if}

<style>
  .container {
    min-height: calc(100vh - 40px);
  }
</style>
