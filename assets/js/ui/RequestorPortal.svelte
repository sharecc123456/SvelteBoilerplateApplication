<script>
  import { onMount, onDestroy } from "svelte";
  import { getUnreadNotificationCount } from "BoilerplateAPI/notifications";
  import "../../css/styles.css";
  import Dashboard from "./pages/requestor_portal/Dashboard.svelte";
  import UserPreferences from "./pages/requestor_portal/UserPreferences.svelte";
  import ChangePassword from "./pages/ChangePassword.svelte";
  import Recipients from "./pages/requestor_portal/Recipients.svelte";
  import RecipientDetails from "./pages/requestor_portal/RecipientDetails";
  import RecipientAssign from "./pages/requestor_portal/RecipientAssign.svelte";
  import UserGuide from "./pages/requestor_portal/UserGuide.svelte";
  import FAQ from "./pages/requestor_portal/FAQ.svelte";
  import RequestorMenu from "./components/RequestorMenu.svelte";
  import BottomNavigationBar from "./components/BottomNavigationBar.svelte";
  import HeaderMenu from "./components/HeaderMenu.svelte";
  import ConfirmationDialog from "./components/ConfirmationDialog.svelte";
  import Checklists from "./pages/requestor_portal/Checklists.svelte";
  import Templates from "./pages/requestor_portal/Templates.svelte";
  import TemplateDetails from "./pages/requestor_portal/TemplateDetails.svelte";
  import ChecklistNew from "./pages/requestor_portal/ChecklistNew.svelte";
  import Review from "./pages/requestor_portal/Review.svelte";
  import Notifications from "./pages/requestor_portal/Notifications.svelte";
  import ReviewDetails from "./pages/requestor_portal/ReviewDetails.svelte";
  import ReviewOne from "./pages/requestor_portal/ReviewOne.svelte";
  import InternalStuff from "./pages/requestor_portal/InternalStuff.svelte";
  import IacSetup from "./iac/IacSetup.svelte";
  import IacFill from "./iac/IacFill.svelte";
  import IacReview from "./iac/IacReview.svelte";
  import SubmissionView from "./pages/recipient_portal/SubmissionView.svelte";
  import Footer from "./util/Footer.svelte";
  import { initializePaperCups } from "../paperCups";
  import { searchParamObject } from "../helpers/util";
  import AutoLogout from "../helpers/autologout";
  import FormFill from "./components/Form/FormFill.svelte";
  import {
    has_unread_notification,
    count_unread_notification,
  } from "./../store";

  let hyperLinks = [
    { title: "Track and manage requests", url: "dashboard", icon: "tasks" },
    { title: "Send files and requests", url: "directsend", icon: "plane" },
    { title: "Manage contacts", url: "recipients", icon: "address-book" },
    { title: "Review submissions", url: "reviews", icon: "glasses" },
  ];
  let checkGuideDialogStatus = JSON.parse(
    localStorage.getItem("dontShowGuideDialog")
  );
  // let initialGuideDialogStatus = localStorage.getItem("temp_guide_dialouge");
  import { mfaPopupNeeded } from "Helpers/Features";
  import AutologoutModal from "./components/AutologoutModal.svelte";

  // deprecated: use searchParamObject function from utils.js
  function getSearchParams() {
    if (location.hash.includes("?")) {
      const result = location.hash
        .split("?")[1]
        .split("&")
        .map((item) => {
          const tmp = item.split("=");
          let dict_ = {};
          dict_[tmp[0]] = tmp[1];
          return dict_;
        });
      return result;
    }
    return [];
  }

  function getHash() {
    var theHash = window.location.hash;
    if (theHash.length == 0) {
      theHash = "#directsend";
    }
    return theHash;
  }

  var mfaMandatePopup = false;
  onMount(async () => {
    mfaMandatePopup = await mfaPopupNeeded();
    let notificationResponse = await getUnreadNotificationCount();

    if (notificationResponse.unread) {
      $count_unread_notification = notificationResponse.count;
      $has_unread_notification = true;
    }
  });

  var hash = getHash();
  var component = Dashboard;
  var showMenu = true;
  var props = {};
  var oldURL;
  function doRouting() {
    oldURL = window.location.href;
    hash = getHash();
    showMenu = true;
    props = {};

    if (hash == "#dashboard") {
      component = Dashboard;
    } else if (hash == "#directsend") {
      component = UserGuide;
    } else if (hash == "#faq") {
      component = FAQ;
    } else if (hash == "#internal") {
      component = InternalStuff;
    } else if (hash.startsWith("#admin")) {
      component = UserPreferences;
    } else if (hash == "#changePassword") {
      component = ChangePassword;
      showMenu = false;
    } else if (hash == "#reviews") {
      component = Review;
    } else if (hash == "#notifications") {
      component = Notifications;
    } else if (hash.match(/\#review\/(\d+)\/document\/(\d+)\/edit/)) {
      let tag = hash.match(/\#review\/(\d+)\/document\/(\d+)\/edit/);
      component = IacReview;
      showMenu = false;
      props = {
        reviewType: "document",
        checklistId: tag[1],
        itemId: tag[2],
      };
    } else if (hash.match(/\#review\/(\d+)\/document\/(\d+)/)) {
      let tag = hash.match(/\#review\/(\d+)\/document\/(\d+)/);
      component = ReviewOne;
      showMenu = false;
      props = {
        reviewType: "document",
        checklistId: tag[1],
        itemId: tag[2],
      };
    } else if (hash.match(/\#review\/(\d+)\/request\/(\d+)/)) {
      let tag = hash.match(/\#review\/(\d+)\/request\/(\d+)/);
      component = ReviewOne;
      showMenu = false;
      props = {
        reviewType: "request",
        checklistId: tag[1],
        itemId: tag[2],
      };
    } else if (hash.match(/\#review\/(\d+)\/form\/(\d+)/)) {
      let tag = hash.match(/\#review\/(\d+)\/form\/(\d+)/);
      component = ReviewOne;
      showMenu = false;
      props = {
        reviewType: "form",
        checklistId: tag[1],
        itemId: tag[2],
      };
    } else if (hash.startsWith("#review/")) {
      component = ReviewDetails;
      let target = parseInt(hash.substr("#review/".length));
      showMenu = false;
      props = {
        checklistId: target,
      };
    } else if (hash == "#recipients") {
      component = Recipients;
    } else if (hash.match(/\#recipient\/(\d+)\/assign\/(\d+)/)) {
      let tag = hash.match(/\#recipient\/(\d+)\/assign\/(\d+)/);
      component = RecipientAssign;
      showMenu = false;
      props = {
        recipientId: tag[1],
        checklistId: tag[2],
      };
    } else if (hash.startsWith("#recipient/")) {
      component = RecipientDetails;
      let target = parseInt(hash.substr("#recipient/".length));
      showMenu = false;
      props = {
        recipientId: target,
      };
    } else if (hash == "#checklists") {
      component = Checklists;
    } else if (hash.match(/\#checklists\/new\/(\d+)/)) {
      let tag = hash.match(/\#checklists\/new\/(\d+)/);
      const checklistId = tag[1];
      component = ChecklistNew;
      showMenu = false;
      props = {
        newChecklist: true,
        isDraftChecklist: true,
        checklistId: checklistId,
      };
    } else if (hash.startsWith("#checklists/new")) {
      component = ChecklistNew;
      props = {
        newChecklist: true,
      };
      showMenu = false;
    } else if (hash.startsWith("#checklist/")) {
      component = ChecklistNew;
      let target = parseInt(hash.substr("#checklist/".length));
      showMenu = false;
      props = {
        newChecklist: false,
        checklistId: target,
      };
    } else if (hash == "#templates") {
      component = Templates;
    } else if (
      hash.startsWith("#template/new/") ||
      hash.includes("newTemplate")
    ) {
      component = TemplateDetails;
      let target = hash.startsWith("#template/new/")
        ? parseInt(hash.substr("#template/new/".length))
        : parseInt(hash.substr("#template/".length));
      showMenu = false;
      props = {
        makeNewTemplate: true,
        templateId: target,
      };
    } else if (hash.startsWith("#template/")) {
      component = TemplateDetails;
      let target = parseInt(hash.substr("#template/".length));
      showMenu = false;
      props = {
        makeNewTemplate: false,
        templateId: target,
      };
    } else if (hash.match(/\#iac\/setup\/(.+)\/(\d+)/)) {
      let tag = hash.match(/\#iac\/setup\/(.+)\/(\d+)/);
      const requestParams = searchParamObject();
      const isDirectSend =
        requestParams?.directSend === "true" ? true : false || false;
      const isPrefill =
        requestParams?.prefill === "true" ? true : false || isDirectSend;
      component = IacSetup;
      showMenu = false;
      props = {
        documentType: tag[1],
        documentId: tag[2],
        isPrefill: isPrefill,
        isDirectSend,
      };
    } else if (hash.match(/\#iac\/fill\/(\d+)\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#iac\/fill\/(\d+)\/(\d+)\/(\d+)/);
      component = IacFill;
      showMenu = false;
      const requestParams = searchParamObject();
      const aId = requestParams.assigneeId;
      const isDirectSend =
        requestParams?.directSend === "true" ? true : false || false;
      const fromSetup =
        requestParams?.onSetup === "true" ? true : false || false;
      const sesMode = requestParams?.sesMode === "true" ? true : false || false;
      const editMode =
        requestParams?.editMode === "true" ? true : false || false;
      const tcId = requestParams?.tc || 0;
      props = {
        iacDocId: tag[1],
        fillType: "requestor",
        contentsId: tag[2],
        recipientId: tag[3],
        assignmentId: 0,
        assigneeId: aId || -1,
        isDirectSend,
        fromSetup,
        sesMode,
        editMode,
        tcId,
      };
    } else if (hash.match(/\#submission\/view\/(\d+)\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#submission\/view\/(\d+)\/(\d+)\/(\d+)/);
      component = SubmissionView;
      showMenu = false;
      props = {
        specialId: parseInt(tag[1], 10),
        assignmentId: parseInt(tag[2], 10),
        documentId: parseInt(tag[3], 10),
        fillType: "requestor",
      };
    } else if (hash.match(/\#view\/template\/(\d+)/)) {
      let tag = hash.match(/\#view\/template\/(\d+)/);
      const requestParams = getSearchParams();
      const { filePreview: isPreview } =
        requestParams.find((param) => param.filePreview) || {};
      component = SubmissionView;
      showMenu = false;
      props = {
        specialId: 5,
        assignmentId: 0,
        documentId: parseInt(tag[1], 10),
        isPreview: isPreview || false,
        fillType: "requestor",
      };
    } else if (hash.match(/\#preview\/form\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#preview\/form\/(\d+)\/(\d+)/);
      component = SubmissionView;
      showMenu = false;
      props = {
        specialId: 8,
        assignmentId: parseInt(tag[1], 10),
        documentId: parseInt(tag[2], 10),
        isPreview: true,
        fillType: "requestor",
      };
    } else if (hash.match(/\#preview\/form\/(\d+)\/index\/(\d+)/)) {
      let tag = hash.match(/\#preview\/form\/(\d+)\/index\/(\d+)/);
      component = SubmissionView;
      showMenu = false;
      props = {
        specialId: 8,
        assignmentId: parseInt(tag[1], 10),
        documentIndex: parseInt(tag[2], 10) + 1, // adding padding to index, we have to minus this value during reading
        isPreview: true,
        fillType: "requestor",
      };
    } else if (hash.match(/\#view\/form\/(\d+)\/(\d+)/)) {
      let tag = hash.match(/\#view\/form\/(\d+)\/(\d+)/);
      const requestParams = getSearchParams();
      const formName = requestParams?.name || "";
      const editableForm = requestParams?.edit || false;
      component = FormFill;

      props = {
        formId: tag[1],
        assignmentId: tag[2],
        fillType: "requestor",
        formName: formName ? decodeURIComponent(formName) : "",
        editableForm,
      };
    } else if (hash.match(/\#prefill\/form\/(\d+)\/index\/(\d+)/)) {
      let tag = hash.match(/\#prefill\/form\/(\d+)\/index\/(\d+)/);
      component = SubmissionView;
      showMenu = false;
      props = {
        specialId: 8,
        assignmentId: parseInt(tag[1], 10),
        documentIndex: parseInt(tag[2], 10) + 1, // adding padding to index, we have to minus this value during reading
        isPrefill: true,
        fillType: "requestor",
      };
    }
  }

  const getUsersInfo = async () => {
    let request = await fetch("/n/api/v1/user/me?type=requestor");
    let user = await request.json();

    return {
      email: user.email,
      phone: user.phone,
      name: user.name,
    };
  };

  let guideDialog = false;
  let showOnceGuideDialog = JSON.parse(
    window.sessionStorage?.getItem("showOnceGuideDialog")
  );
  if (!showOnceGuideDialog && window.innerWidth < 768) {
    showOnceGuideDialog = true;
    window.sessionStorage.setItem("showOnceGuideDialog", true);
  }
  let autoLogout;
  let showLogoutWarning = false;

  const handleLogoutWarning = () => {
    showLogoutWarning = true;
  };

  const setLogoutWarning = (val) => {
    showLogoutWarning = val;
  };
  const handleLogout = () => {
    window.location = "/logout";
    window.sessionStorage.removeItem("showOnceGuideDialog");
  };

  onMount(async () => {
    window.__boilerplate_user_type = "requestor";
    autoLogout = new AutoLogout(handleLogoutWarning, handleLogout);
    getUsersInfo().then((user) => {
      initializePaperCups(user);
    });
    doRouting();
    guideDialog = true;
  });

  onDestroy(() => {
    autoLogout.destroy();
  });
  let hoverParent;
</script>

<svelte:head>
  <link
    href="https://fonts.googleapis.com/css?family=Nunito"
    rel="stylesheet"
  />

  <meta
    name="viewport"
    content="width=device-width, initial-scale=1, maximum-scale=1,user-scalable=0"
  />
</svelte:head>
{#if hash == "#directsend"}
  {#if guideDialog}
    {#if checkGuideDialogStatus !== true}
      {#if showOnceGuideDialog !== true}
        <ConfirmationDialog
          title={"Welcome! What would you like to do?"}
          hideText="Close"
          hideColor="white"
          {hyperLinks}
          hyperLinksColor="black"
          checkBoxEnable={"enable"}
          checkBoxText={"Don't ask me this again"}
          on:close={(event) => {
            if (event?.detail) {
              localStorage.setItem("dontShowGuideDialog", event?.detail);
            } else {
              localStorage.setItem("dontShowGuideDialog", false);
            }
            guideDialog = false;
            window.sessionStorage.setItem("showOnceGuideDialog", true);
          }}
          on:yes={""}
          on:hide={(event) => {
            if (event?.detail === true) {
              localStorage.setItem("dontShowGuideDialog", event?.detail);
            } else {
              localStorage.setItem("dontShowGuideDialog", false);
            }
            if (
              event?.detail != false &&
              event?.detail != true &&
              event?.detail != null &&
              oldURL.split("#")[1] != event?.detail
            ) {
              showMenu = false;
              setTimeout(() => {
                showMenu = true;
              }, 10);
            }
            guideDialog = false;
            window.sessionStorage.setItem("showOnceGuideDialog", true);
          }}
        />
      {/if}
    {/if}
  {/if}
{/if}

<svelte:window on:hashchange={doRouting} />
<HeaderMenu {hash} />
{#if showMenu}
  <RequestorMenu {hash} bind:hover={hoverParent} />
{/if}

{#if mfaMandatePopup}
  <ConfirmationDialog
    title="Multi-Factor Authentication"
    yesText="Set It Up"
    noText="Later"
    yesColor="primary"
    noColor="danger-white"
    details="Your organization has mandated that all administrators enable Multi-Factor Authentication. Please go to your Preferences to set it up."
    on:yes={() => {
      window.location.hash = "#admin?mfa=true";
      mfaMandatePopup = false;
    }}
    on:close={() => {
      mfaMandatePopup = false;
    }}
  />
{/if}

{#if showLogoutWarning}
  <AutologoutModal {handleLogout} {setLogoutWarning} />
{/if}

<div class="container" class:padded={showMenu} class:padded-hover={hoverParent}>
  <svelte:component this={component} {...props} />
</div>
<div class="footer-container" class:padded={showMenu}>
  <Footer />
</div>
{#if showMenu}
  <BottomNavigationBar {hash} />
{/if}

<style>
  .container {
    background: #fcfdff;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    min-height: calc(100vh - 45px);
  }

  .footer-container {
    height: 14px;
  }

  .padded {
    padding-left: 45px;
    padding-right: 5px;
  }

  @media screen and (min-width: 1024px) {
    .padded {
      padding-right: 10px;
    }
    .padded-hover {
      padding-left: 215px;
    }
  }

  @media (max-width: 767px) {
    .container {
      padding: 70px 10px 10px;
      background: #f8fafd;
    }
    .footer-container {
      padding-bottom: 6rem;
    }
  }
</style>
