<script>
  import { featureEnabled } from "Helpers/Features";
  import { getCompanyInfo } from "BoilerplateAPI/Features";
  import { uploadWhiteLabel } from "BoilerplateAPI/Company";
  import { getWhitelabeling } from "BoilerplateAPI/RecipientPortal";
  import { onMount } from "svelte";
  import { reportCrash } from "BoilerplateAPI/CrashReporter";
  import FileUploadModal from "../../modals/RecipientUploadFileModal.svelte";
  import Selector from "Components/Selector.svelte";
  import TextField from "Components/TextField.svelte";
  import TextBuilder from "Components/TextBuilder.svelte";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";
  import Loader from "Components/Loader.svelte";
  import PhoneNumberInput from "Components/PhoneNumberInput.svelte";
  import Button from "Atomic/Button.svelte";
  import GoogleLoginButton from "Atomic/GoogleLoginButton.svelte";
  import LoadingButton from "Atomic/LoadingButton.svelte";
  import Modal from "Components/Modal.svelte";
  import FAIcon from "Atomic/FAIcon.svelte";
  import Checkbox from "Components/Checkbox.svelte";
  import BackgroundPageHeader from "../../components/BackgroundPageHeader.svelte";
  import {
    userUpdateProfile,
    userMfaUpdate,
    toggleAdminNotifications,
    toggleWeeklyDigest,
  } from "BoilerplateAPI/User";
  import { showErrorMessage } from "Helpers/Error";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import BillingMetrics from "./BillingMetrics.svelte";
  import LogoPreview from "Components/Requestor/LogoPreview.svelte";
  import { todayDate } from "../../../helpers/dateUtils";
  import Switch from "Components/Switch.svelte";
  import { debounce } from "Helpers/util";
  import TabBar from "../../components/TabBar.svelte";
  import { getRecipients } from "BoilerplateAPI/Recipient";
  import { convertTime } from "Helpers/util";
  import QrCode from "svelte-qrcode";
  import { getQueryParams } from "../../../helpers/getQueryParams";
  import Accordion from "../../components/Accordion.svelte";

  let recipient_email,
    recipient_name,
    recipient_company,
    recipient_phone,
    recipient_uid,
    recipient_start_date;
  let mfa_state;
  let resend_button_color = "white";
  let mfa_verification_code = "";
  let verification_in_progress = false;
  let showMFAModal = false;
  let showMFADisableConfirmation = false;
  let mfa_current_tab = 0;
  let mfa_secret_data = "";
  let showMFAMandateDisable = false;
  let isAppLoaded = false;
  let company_id = undefined;
  let metricsLoading = true;
  let members = [];
  let today;
  let current_tab = 0;
  let tabs = [
    { name: "Details", icon: "info-circle" },
    { name: "Personalization", icon: "pen-to-square" },
    { name: "Usage Metrics", icon: "chart-bar" },
    { name: "Security & Privacy", icon: "shield" },
    { name: "Integrations", icon: "plug" },
    { name: "Team Members", icon: "users" },
  ];
  const handleOnClickTab = (tabIndex) => {
    return (current_tab = tabIndex);
  };

  let requestor = undefined;

  const { CONTACTS_GOOGLE, GOOGLE_DRIVE, GOOGLE_SIGN_ON, BOX } = {
    GOOGLE_SIGN_ON: { internal: "google", display: "Sign On With Google" },
    CONTACTS_GOOGLE: {
      internal: "contacts_google",
      display: "Google Contacts Import",
    },
    GOOGLE_DRIVE: { internal: "gdrive", display: "Export to Google Drive" },
    BOX: { internal: "box", display: "Export to Box" },
  };
  let showDisableIntegration = false;
  let currentIntegration = "";
  let isActiveGoogleContacts = false;
  let isActiveGoogleDrives = false;
  let isActiveBox = false;
  let isActiveGoogleSignOn = false;
  let googleDriveSPPT = ""; // storage provider path template
  let boxSPPT = ""; // storage provider path template
  let open_accordion = "";
  let spptVariables = [
    { display: "Full Name", internal: "$FULLNAME" },
    { display: "Checklist Name", internal: "$CHECKLIST" },
    { display: "Year", internal: "$YEAR" },
    { display: "Month", internal: "$MONTH" },
    { display: "Day", internal: "$DAY" },
  ];
  const hasIntegration = (integrations, type) =>
    integrations.some((integration) => integration.type === type);

  const disableIntegration = async (integration_type) => {
    return await fetch(`/n/api/v1/deauth/${integration_type}`, {
      method: "POST",
      credentials: "include",
      body: "",
    });
  };

  const updatePathTemplate = async (pt) => {
    return await fetch(`/n/api/v1/company/storageprovider`, {
      method: "PUT",
      headers: {
        "content-type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify({
        type: "permanent",
        path_template: pt,
      }),
    });
  };

  // Make sure that the users can see an example of the path the integrations
  // will put files to. Before adding new ones here, please add them to the
  // @valid_path_variables module attribute in storage_provider.ex
  const spptExamplify = (sppt) => {
    return sppt
      .replaceAll("$FULLNAME", "John Doe")
      .replaceAll("$YEAR", "2023")
      .replaceAll("$MONTH", "01")
      .replaceAll("$DAY", "01")
      .replaceAll("$CHECKLIST", "Onboarding");
  };

  onMount(async () => {
    today = todayDate();
    members = await getCompanyInfo();
    let request = await fetch("/n/api/v1/user/me?type=requestor");
    requestor = await request.json();
    console.log({ members });

    if (request) {
      isActiveGoogleSignOn = hasIntegration(
        requestor.single_sign_on,
        GOOGLE_SIGN_ON.internal
      );
    }

    isActiveGoogleContacts = hasIntegration(
      members.integrations,
      CONTACTS_GOOGLE.internal
    );
    isActiveGoogleDrives =
      members.storage_providers.permanent.type == GOOGLE_DRIVE.internal;
    isActiveBox = members.storage_providers.permanent.type == BOX.internal;
    googleDriveSPPT = isActiveGoogleDrives
      ? members.storage_providers.permanent.path_template
      : "";
    boxSPPT = isActiveBox
      ? members.storage_providers.permanent.path_template
      : "";
    members = members?.requestors;
    try {
      const c_data = await fetch(
        `/n/api/v1/company/${company_id}/billing/metrics`
      );
      if (c_data.ok) {
        let reply = await c_data.json();
        fileRetentionPeriod = reply.file_retention_period;
        defaultOptionIndex = fileRetentionOptions.findIndex(
          (option) => option.value === fileRetentionPeriod
        );
        fileRetentionDropdownValue = fileRetentionPeriod;
        const isFRPTesting = await featureEnabled("retention_testing");
        if (isFRPTesting) {
          fileRetentionOptions = [
            { text: "5 mins(Only in testing)", value: 500 },
            ...fileRetentionOptions,
          ];
        }
      }
    } catch (err) {
      console.error(err);
    }
  });

  async function getBillingMetrics() {
    const data = await fetch(`/n/api/v1/company/${company_id}/billing/metrics`);
    if (data.ok) {
      let reply = await data.json();
      metricsLoading = false;
      return reply;
    }
  }
  let setWeeklyDigest = false;
  let setAdminNotification = false;
  const toggle_notify_admin_option = async (notiFlag) => {
    const reply = await toggleAdminNotifications(recipient_uid, notiFlag);
    if (reply.ok) {
      showToast(`Successfully completed the operation`, 1500, "default", "MM");
    } else {
      showToast(
        `Sorry! Something went wrong. Please try again later`,
        1500,
        "error",
        "MM"
      );
    }
  };

  const toggle_weekly_digest = async (notiFlag) => {
    const reply = await toggleWeeklyDigest(recipient_uid, notiFlag);
    if (reply.ok) {
      showToast(`Successfully completed the operation`, 1500, "default", "MM");
    } else {
      showToast(
        `Sorry! Something went wrong. Please try again later`,
        1500,
        "error",
        "MM"
      );
    }
  };

  const handleDebounce = () => {
    debounce(() => toggle_notify_admin_option(setAdminNotification), 2000)();
  };

  const handleDebounceWeeklyDigest = () => {
    debounce(() => toggle_weekly_digest(setWeeklyDigest), 2000)();
  };

  let recipientPromise = fetch("/n/api/v1/user/me?type=requestor")
    .then((x) => x.json())
    .then(async (x) => {
      // console.log(x);
      recipient_email = x.email;
      recipient_company = x.organization;
      recipient_name = x.name;
      recipient_phone = x.phone;
      recipient_start_date = x.start_date;
      recipient_uid = x.user_id;
      mfa_state = x.two_factor_state;
      company_id = x.company_id;
      isAppLoaded = true;
      setAdminNotification = x.is_notify_admin;
      setWeeklyDigest = x.is_weekly_digest;
      return {
        user_id: x.user_id,
        email: x.email,
        phone: x.phone,
        name: x.name,
        mfa_state: x.two_factor_state,
      };
    });
  let showEdit = false;
  let commitChanges = (r) => {
    userUpdateProfile(r.user_id, {
      phone: recipient_phone,
      // organization: recipient_company,
    });
  };
  const toggleShowEdit = () => {
    showEdit = !showEdit;
  };

  let fileRetentionOptions = [
    { text: "7 days", value: 604800 },
    { text: "15 days", value: 1296000 },
    { text: "30 days", value: 2592000 },
    { text: "60 days", value: 5184000 },
    { text: "90 days", value: 7776000 },
    { text: "180 days", value: 15552000 },
    { text: "1 year", value: 31557600 },
    { text: "2 years", value: 63115200 },
    { text: "3 years", value: 94672800 },
    { text: "4 years", value: 126230400 },
    { text: "5 years", value: 157788000 },
    { text: "6 years", value: 189345600 },
    { text: "7 years", value: 220903200 },
    { text: "Indefinite", value: -1 },
  ];

  let defaultOptionIndex = 4;
  let fileRetentionPeriod = -1;
  let fileRetentionDropdownValue = -1;
  let showSaveFileRetentionError = false;
  // let disabledFileRetentionSave = false;
  let showRetentionConfirmation = false;

  const handleFileRetentionChange = (newValue) => {
    console.log({
      msg: "onValueChange",
      fileRetentionPeriod,
      fileRetentionDropdownValue,
    });
    if (fileRetentionPeriod !== fileRetentionDropdownValue) {
      showRetentionConfirmation = true;
    }
  };

  const resetRetentionValues = () => {
    showRetentionConfirmation = false;
    // window.location.reload();
  };

  const handleSaveFileRetention = async () => {
    // if (disabledFileRetentionSave) return;
    showSaveFileRetentionError = false;
    const body = JSON.stringify({
      company_id,
      file_retention_period: fileRetentionDropdownValue,
    });

    try {
      const res = await fetch(`/n/api/v1/company/set-file-retention`, {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body,
      });
      const data = await res.json();
      console.log(data);
      fileRetentionPeriod = fileRetentionDropdownValue;
      defaultOptionIndex = fileRetentionOptions.findIndex(
        (option) => option.value === fileRetentionDropdownValue
      );
      showToast("Retention Changes Saved", 1000, "default", "MM");
    } catch (err) {
      console.error(err);
      showSaveFileRetentionError = true;
      defaultOptionIndex = fileRetentionOptions.findIndex(
        (option) => option.value === fileRetentionPeriod
      );
    }
    showRetentionConfirmation = false;
    // disabledFileRetentionSave = false;
  };

  $: handleFileRetentionChange(fileRetentionDropdownValue);

  let showUsageMetric = false;
  $: showUsageMetric = isAppLoaded;
  let scrollY;

  let showFileUploadModal = false;
  const handleCompanyLogoUpload = async (evt) => {
    let detail = evt.detail;
    let reply = {};
    try {
      reply = await uploadWhiteLabel(company_id, detail.file);
      if (reply.msg == "OK") {
        // showToast(
        //   `Congrats! Company Logo successfully added.`,
        //   1000,
        //   "white",
        //   "MM"
        // );
        showFileUploadModal = false;
        newLogo = reply.logo;
        showLogoPreview = true;
        /* setTimeout(() => { */
        /*   window.location.reload(); */
        /* }, 1000); */
      } else {
        showToast(
          `Sorry! Could not upload the company logo.`,
          1500,
          "error",
          "MM"
        );
        reportCrash("handleCompanyLogoUpload", {
          reply_ok: reply.ok,
          reply_url: reply.url,
          reply_status: reply.status,
          detail: evt.detail,
        });
      }
    } catch (err) {
      console.error(err);
      showToast(
        `Sorry! Could not upload the company logo.`,
        1500,
        "error",
        "MM"
      );
      reportCrash("handleCompanyLogoUpload", {
        reply_ok: reply.ok,
        reply_url: reply.url,
        reply_status: reply.status,
        detail: evt.detail,
      });
    }
  };
  let dropDownvalues = [];
  let isPromiseResolved;
  getRecipients().then((recp) => {
    dropDownvalues = [...new Set(recp.map((r) => r.company))];
    isPromiseResolved = true;
  });

  $: dropDownvalues = isPromiseResolved ? dropDownvalues : [];

  let logo = null;
  let logoLoading = true;
  let showLogoPreview = false;
  let newLogo = null;

  onMount(async () => {
    const params = getQueryParams();
    if (params?.mfa == "true") {
      current_tab = 2;
      showMFAModal = true;
    }
    if (params?.integrations == "true") {
      current_tab = 4;
      open_accordion = params?.type;
      if (params?.success == "true") {
        showToast("Success! Integration was enabled. Please check if you have additional options to change.", 2000, "white", "MM");
      }
    }
    const whiteLabel = await getWhitelabeling("requestor");
    if (whiteLabel.enabled) {
      logo = whiteLabel.logo_url;
    }
    logoLoading = false;
  });

  window.unloadJWT = (token) => {
    var base64Url = token.split(".")[1];
    var base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
    var jsonPayload = decodeURIComponent(
      window
        .atob(base64)
        .split("")
        .map(function (c) {
          return "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2);
        })
        .join("")
    );

    return JSON.parse(jsonPayload);
  };

  window.handleGoogleSignin = async (event) => {
    let credential = event.credential;
    let reply = await fetch("/n/api/v1/auth/sso", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        credential: credential,
        type: "google",
      }),
    });
    let jwt = unloadJWT(event.credential);

    console.log({ jwt });
    if (reply.ok) {
      window.location.reload();
    } else {
      let t = await reply.text();
      alert("failed to use Google SSO: " + t);
    }
  };
</script>

<svelte:window bind:scrollY />
<svelte:head>
  <script src="https://accounts.google.com/gsi/client"></script>
</svelte:head>

<BackgroundPageHeader {scrollY} />

<div class="page-header">
  <RequestorHeaderNew
    title="Admin Preferences"
    icon="user-cog"
    enable_search_bar={false}
  />
</div>

<div class="container">
  <section class="content">
    {#await recipientPromise}
      <Loader loading />
    {:then recipient}
      <TabBar
        container_classes="tab-container-center-mobile sticky sticky-admin"
        {tabs}
        {current_tab}
        on:changeTab={({ detail: { tab_index } }) =>
          handleOnClickTab(tab_index)}
      />
      {#if current_tab == 0}
        <div class="container">
          <div class="card">
            <div class="edit-button" on:click={toggleShowEdit}>
              <div>
                {#if showEdit}
                  <FAIcon icon="times" iconSize="small" />
                {:else}
                  <FAIcon icon="pencil-alt" iconSize="small" />
                {/if}
              </div>
            </div>
            <div class="row">
              <div class="label">Email</div>
              <div class="value">{recipient_email}</div>
            </div>
            <div class="row">
              <div class="label">Name</div>
              <div class="value">{recipient_name}</div>
            </div>
            <div class="row">
              <div class="label">Phone Number</div>
              {#if showEdit}
                <!-- TextField bind:value={recipient_phone} /> -->
                <PhoneNumberInput bind:value={recipient_phone} />
              {:else}
                <div class="value">{recipient_phone}</div>
              {/if}
            </div>
            <div class="row">
              <div class="label">Company</div>
              <!-- {#if showEdit}
                <TextField
                  width="35%"
                  bind:value={recipient_company}
                  text={"Company"}
                  datalistId="companies"
                  dropdownEnabled={true}
                  dropDownContents={dropDownvalues}
                />
              {:else} -->
              <div class="value">{recipient_company}</div>
              <!-- {/if} -->
            </div>
            <div class="row">
              <div class="label">Start Date</div>
              {#if showEdit}
                <input
                  style="width: 35%;
                  padding: 8px;
                  border: 1px solid #b3c1d0;
                  border-radius: 5px;"
                  type="date"
                  maxlength="4"
                  pattern="[1-9][0-9]{3}"
                  max={"9999-12-31"}
                  bind:value={recipient_start_date}
                />
              {:else}
                <div class="value">
                  {recipient_start_date ? recipient_start_date : ""}
                </div>
              {/if}
            </div>
          </div>
          {#if showEdit}
            <div class="details-edit">
              <div
                on:click={() => {
                  showEdit = false;
                  commitChanges(recipient);
                }}
              >
                <Button color="primary" icon="save" text="Save Changes" />
              </div>
            </div>
          {/if}
        </div>
      {:else if current_tab == 1}
        {#if logoLoading}
          <Loader loading />
        {:else}
          <div class="container">
            <div class="card">
              <div class="row">
                <div class="label">
                  {logo ? "Company Logo" : "Add Company Logo"}
                </div>
                {#if logo}
                  <span class="sublabel"
                    >This will appear at the top of Client Portal</span
                  >
                  <img class="logo" src={logo} alt="logo" />
                {/if}
                <div style="max-width: fit-content; padding-top: 0.25rem;">
                  <span
                    on:click={() => {
                      showFileUploadModal = true;
                    }}
                  >
                    <Button text={logo ? "Change" : "Upload"} />
                  </span>
                </div>
              </div>
              <div class="row">
                <div class="label-action">
                  <div class="label">Weekly Email Usage Digest</div>
                  <span
                    style="max-width: fit-content; align-self: center; margin-left: 2rem"
                    on:click={handleDebounceWeeklyDigest}
                  >
                    <Switch
                      marginBottom={false}
                      bind:checked={setWeeklyDigest}
                      text={""}
                    />
                  </span>
                </div>
                <div class="sublabel">
                  Once enabled, you'll get a weekly email summarizing your
                  Boilerplate activity.
                </div>
              </div>
            </div>
          </div>
        {/if}
      {:else if current_tab == 4}
        <div class="container">
          <div class="wrapper">
            <div class="integration-text">
              <p>
                Integrations let you import contacts and export completed files
                and documents.
              </p>
              <p>Follow the steps below to set up.</p>
            </div>

            <Accordion
              open={open_accordion == "box"}
              title={isActiveBox ? "Box (Enabled)" : "Box"}
            >
              <div class="row">
                <div class="label">Export to Box</div>
                <span class="sublabel">
                  Put your finalized documents on Box.
                  {#if !isActiveBox}
                    (Note: Enabling this will disable other export integrations)
                  {/if}
                </span>
                <div
                  style="display: flex; flex-flow: row nowrap; column-gap: 1rem; align-items: center; max-width: fit-content; padding-top: 0.5rem;"
                >
                  {#if isActiveBox}
                    <span style="padding-left: 1rem; color: green;">
                      <FAIcon icon="check-circle" /><span
                        style="padding-left: 0.25rem;">Connected</span
                      >
                    </span>
                  {:else}
                    <span style="padding-left: 1rem;">
                      <FAIcon icon="times-circle" /><span
                        style="padding-left: 0.25rem;">Not Enabled</span
                      >
                    </span>
                  {/if}
                  <span
                    on:click={() => {
                      if (isActiveBox) {
                        currentIntegration = BOX;
                        showDisableIntegration = true;
                        return;
                      }
                      window.location.href = "/n/auth/box";
                    }}
                  >
                    <Button
                      color={isActiveBox ? "white" : "secondary"}
                      text={isActiveBox ? "Manage Connection" : "Setup"}
                    />
                  </span>
                </div>
                {#if isActiveBox}
                  <span class="sublabel">
                    Define your path template so that the integration knows
                    where to put your files.
                    <br />
                    Example Path: {spptExamplify(boxSPPT)}
                  </span>
                  <div style="max-width: 70%">
                    <TextBuilder
                      placeholder={"Type here (and press Enter) to add custom path segments"}
                      bind:value={boxSPPT}
                      tags={spptVariables}
                    />
                  </div>
                  <div style="width: fit-content;">
                    <span
                      on:click={() => {
                        if (boxSPPT.trim() == "") {
                          alert("Cannot set to empty.");
                          return;
                        }
                        updatePathTemplate(boxSPPT).then((e) => {
                          if (e.ok) {
                            alert("Updated template!");
                          } else {
                            console.log(e);
                            alert("Failed to update template.");
                          }
                        });
                      }}
                    >
                      <Button color={"primary"} text={"Save Path Template"} />
                    </span>
                  </div>
                {/if}
              </div>
            </Accordion>

            {#if featureEnabled("integration_google")}
            <Accordion
              open={open_accordion == "google"}
              title={isActiveGoogleDrives ||
              isActiveGoogleContacts ||
              isActiveGoogleSignOn
                ? "Google (Enabled)"
                : "Google"}
            >
              <div class="row">
                <div class="label">Export to Google Drive</div>
                <span class="sublabel">
                  Put your finalized documents on Google Drive.
                  {#if !isActiveGoogleDrives}
                    (Note: Enabling this will disable other export integrations){/if}
                </span>
                <div
                  style="display: flex; flex-flow: row nowrap; column-gap: 1rem; align-items: center; max-width: fit-content; padding-top: 0.5rem;"
                >
                  {#if isActiveGoogleDrives}
                    <span style="padding-left: 1rem; color: green;">
                      <FAIcon icon="check-circle" /><span
                        style="padding-left: 0.25rem;">Connected</span
                      >
                    </span>
                  {:else}
                    <span style="padding-left: 1rem;">
                      <FAIcon icon="times-circle" /><span
                        style="padding-left: 0.25rem;">Not Enabled</span
                      >
                    </span>
                  {/if}
                  <span
                    on:click={() => {
                      if (isActiveGoogleDrives) {
                        currentIntegration = GOOGLE_DRIVE;
                        showDisableIntegration = true;
                        return;
                      }
                      window.location.href = "/n/auth/google";
                    }}
                  >
                    <Button
                      color={isActiveGoogleDrives ? "white" : "secondary"}
                      text={isActiveGoogleDrives
                        ? "Manage Connection"
                        : "Setup"}
                    />
                  </span>
                </div>
                {#if isActiveGoogleDrives}
                  <span class="sublabel">
                    Define your path template so that the integration knows
                    where to put your files.
                    <br />
                    Example Path: {spptExamplify(googleDriveSPPT)}
                  </span>
                  <div style="max-width: 70%">
                    <TextBuilder
                      placeholder={"Type here (and press Enter) to add custom path segments"}
                      bind:value={googleDriveSPPT}
                      tags={spptVariables}
                    />
                  </div>
                  <div style="width: fit-content;">
                    <span
                      on:click={() => {
                        if (googleDriveSPPT.trim() == "") {
                          alert("Cannot set to empty.");
                          return;
                        }
                        updatePathTemplate(googleDriveSPPT).then((e) => {
                          if (e.ok) {
                            alert("Updated template!");
                          } else {
                            console.log(e);
                            alert("Failed to update template.");
                          }
                        });
                      }}
                    >
                      <Button color={"primary"} text={"Save Path Template"} />
                    </span>
                  </div>
                {/if}
              </div>
              <div class="row">
                <div class="label">Google Sign-On</div>
                <span class="sublabel">
                  Allow the usage of a Google account to login instead of
                  username/password pair.
                </span>
                <div
                  style="display: flex; flex-flow: row nowrap; column-gap: 1rem; align-items: center; fit-content; padding-top: 0.5rem;"
                >
                  {#if isActiveGoogleSignOn}
                    <span style="padding-left: 1rem; color: green;">
                      <FAIcon icon="check-circle" /><span
                        style="padding-left: 0.25rem;">Connected</span
                      >
                    </span>
                    <span
                      on:click={() => {
                        currentIntegration = GOOGLE_SIGN_ON;
                        showDisableIntegration = true;
                        return;
                      }}
                    >
                      <Button color={"white"} text={"Manage Connection"} />
                    </span>
                  {:else}
                    <span style="padding-left: 1rem;">
                      <FAIcon icon="times-circle" /><span
                        style="padding-left: 0.25rem;">Not Enabled</span
                      >
                    </span>
                    <GoogleLoginButton />
                  {/if}
                </div>
              </div>
              <div class="row">
                <div class="label">Google Contacts Import</div>
                <span class="sublabel">
                  Ability to import contacts from Google Contacts
                </span>
                <div
                  style="display: flex; flex-flow: row nowrap; column-gap: 1rem; align-items: center; max-width: fit-content; padding-top: 0.5rem;"
                >
                  {#if isActiveGoogleContacts}
                    <span style="padding-left: 1rem; color: green;">
                      <FAIcon icon="check-circle" /><span
                        style="padding-left: 0.25rem;">Connected</span
                      >
                    </span>
                  {:else}
                    <span style="padding-left: 1rem;">
                      <FAIcon icon="times-circle" /><span
                        style="padding-left: 0.25rem;">Not Enabled</span
                      >
                    </span>
                  {/if}
                  <span
                    on:click={() => {
                      if (isActiveGoogleContacts) {
                        currentIntegration = CONTACTS_GOOGLE;
                        showDisableIntegration = true;
                        return;
                      }
                      window.location.href = "/n/auth/google_contacts";
                    }}
                  >
                    <Button
                      color={isActiveGoogleContacts ? "white" : "secondary"}
                      text={isActiveGoogleContacts
                        ? "Manage Connection"
                        : "Setup"}
                    />
                  </span>
                </div>
              </div>
            </Accordion>
            {/if}
          </div>
        </div>
      {:else if current_tab == 3}
        <div class="container">
          <div class="card">
            <div class="row">
              <div class="label-action">
                <div class="label">
                  Send submission notifications to all admins
                </div>
                <div
                  style="max-width: fit-content; margin-left: 2rem"
                  on:click={handleDebounce}
                >
                  <Switch bind:checked={setAdminNotification} text={""} />
                </div>
              </div>
              <div class="sublabel">
                This allows Submission notifications to go to all admins on an
                account, not just the requester.
              </div>
            </div>
            <div class="row">
              <div class="label-action">
                <div class="label">File Retention Time</div>
                <div style="max-width: fit-content; margin-left: 2rem">
                  <Selector
                    classes="ck-requestor-dropdown-content"
                    bind:value={fileRetentionDropdownValue}
                    options={fileRetentionOptions}
                  />
                </div>
              </div>
              {#if showSaveFileRetentionError}
                <div style="color: red;margin-bottom: 1rem;">
                  <FAIcon icon="times-circle" />
                  <span style="padding-left: 0.25rem;"
                    >Error Occurred, Please Try Again</span
                  >
                </div>
              {/if}
              <div class="sublabel">
                This sets time (in days) for auto deletion of file uploads of a
                checklist after completion. For e.g, if time is 5 days, file
                uploads for a checklist will be deleted automatically after 5
                days of its completion
              </div>
            </div>
            <div class="row">
              <div class="label">Password</div>
              <div style="max-width: fit-content; padding-top: 0.5rem;">
                <a href="#changePassword">
                  <Button text="Change Password" />
                </a>
              </div>
            </div>
            <div class="row">
              <div class="label">
                Multi-Factor Authentication
                {#if mfa_state == 0 || mfa_state == 1}
                  <span style="padding-left: 1rem; color: red;">
                    <FAIcon icon="times-circle" /><span
                      style="padding-left: 0.25rem;">Not Enabled</span
                    >
                  </span>
                {/if}
                {#if mfa_state == 2 || mfa_state == 4}
                  <span style="padding-left: 1rem; color: green;">
                    <FAIcon icon="check-circle" /><span
                      style="padding-left: 0.25rem;">Enabled</span
                    >
                  </span>
                {/if}
              </div>
              <div class="sublabel">
                Multi-Factor Authentication is an enhanced security mode for
                Boilerplate. Instead of granting you access to your account
                solely based on your Password when logging in from unfamiliar
                locations, we will ask for a verification code via your phone,
                or via an authenticator app.
              </div>
              {#if mfa_state == 2 || mfa_state == 4}
                <Checkbox
                  text={`Enable Multi-Factor Authentication via ${
                    mfa_state == 2 ? "SMS text message" : "Authenticator App"
                  }`}
                  on:changed={(evt) => {
                    if (window.__boilerplate_mfa_mandate) {
                      showErrorMessage("userErrors", "mfa_mandate");
                    } else {
                      showMFADisableConfirmation = true;
                    }
                  }}
                  changeInternally={false}
                  isChecked={mfa_state == 1 || mfa_state == 2 || mfa_state == 4}
                />
              {/if}
              {#if mfa_state == 1 || mfa_state == 0}
                <div
                  style="max-width: fit-content; padding-top: 0.25rem;"
                  on:click={() => {
                    showMFAModal = true;
                  }}
                >
                  <Button text="Enable Multi-Factor Authentication" />
                </div>
              {/if}
              {#if mfa_state == 1}
                <!-- Pending First Verification -->
              {/if}
            </div>
          </div>
        </div>
      {:else if current_tab == 2}
        {#if showUsageMetric}
          <div class="container">
            {#await getBillingMetrics() then metrics}
              <div class="card">
                <BillingMetrics tableData={metrics} />
              </div>
            {/await}
          </div>
        {/if}
      {:else if current_tab == 5}
        {#if members != []}
          <div class="tr th">
            <div class="td name alignment">
              <div>Name</div>
            </div>
            <div class="td email alignment">
              <div>Email</div>
            </div>
            <div class="td DateAdded alignment">
              <div>Date Added</div>
            </div>
            <div class="td LastLogin alignment">
              <div>Last Login</div>
            </div>
            <!-- <div class="td Actions alignment">
              <div>Actions</div>
            </div> -->
          </div>
          {#each members as member}
            <div class="tr outer-border">
              <div class="td name alignment">
                {member.name}
              </div>
              <div class="td email alignment">
                {member.email}
              </div>
              <div class="td DateAdded alignment">
                {member.inserted_at.split("T")[0]}
                <br />
                {convertTime(
                  member.inserted_at.split("T")[0],
                  member.inserted_at.split("T")[1]
                )}
              </div>
              <div class="td LastLogin alignment">
                {member.last_login.split("T")[0]}
                <br />
                {convertTime(
                  member.last_login.split("T")[0],
                  member.last_login.split("T")[1]
                )}
              </div>
              <!-- <div class="td Actions alignment">
                <span>
                  <Button text="Revoke" />
                </span>
              </div> -->
            </div>
          {/each}
        {/if}
      {/if}
    {/await}
  </section>
</div>

{#if showDisableIntegration}
  <ConfirmationDialog
    question={`Are you sure you want to disable the ${currentIntegration.display} integration?`}
    yesText="Yes, Disable"
    noText="No, Keep Enabled"
    yesColor="danger"
    noColor="primary"
    on:yes={() => {
      disableIntegration(currentIntegration.internal).then(() => {
        showDisableIntegration = false;
        window.location.reload();
      });
    }}
    on:close={() => {
      showDisableIntegration = false;
    }}
  />
{/if}

{#if showMFADisableConfirmation}
  <ConfirmationDialog
    question="Are you sure you want to disable Multi-Factor Authentication?"
    yesText="Yes, Disable"
    noText="No, Keep Enabled"
    yesColor="danger"
    noColor="primary"
    on:yes={() => {
      userMfaUpdate(recipient_uid, 0);
      mfa_state = 0;
      showMFADisableConfirmation = false;
    }}
    on:close={() => {
      mfa_state = 2;
      showMFADisableConfirmation = false;
    }}
  />
{/if}

{#if showMFAModal}
  <Modal
    on:close={() => {
      showMFAModal = false;
    }}
  >
    <div slot="header">Multi-Factor Authentication</div>

    <TabBar
      bind:current_tab={mfa_current_tab}
      on:changeTab={async (evt) => {
        mfa_current_tab = evt.detail.tab_index;
        if (mfa_current_tab == 1) {
          let f = await userMfaUpdate(recipient_uid, 12);
          let d = await f.json();
          mfa_secret_data = d.uri;
        }
      }}
      tabs={[
        { name: "Text (SMS) message", icon: "phone" },
        { name: "Authenticator App", icon: "computer-classic" },
      ]}
    />

    {#if mfa_current_tab == 0}
      <div class="mfa-modal">
        {#if mfa_state == 0}
          <!-- Setup -->
          <p>
            To setup multi-factor authentication, we need to verify your phone
            number. Please enter it below. Note that depending on your cellular
            plan, carrier charges may apply to receving SMS (text) messages.
          </p>
          <div style="padding-bottom: 1rem;">
            <PhoneNumberInput bind:value={recipient_phone} />
          </div>
          <span
            on:click={() => {
              userUpdateProfile(recipient_uid, {
                phone: recipient_phone,
              }).then(() => {
                userMfaUpdate(recipient_uid, 1);
                mfa_state = 1;
              });
            }}
          >
            <Button text="Agree & Send" />
          </span>
        {/if}
        {#if mfa_state == 1}
          <div class="info">
            <p>
              We've sent you a text message to verify your phone number. Please
              enter the number you received here.
            </p>
            <div class="mfa-verification">
              <span style="grid-area: code; margin-bottom: 20px">
                <TextField
                  bind:value={mfa_verification_code}
                  text="Verification Code"
                />
              </span>
              <span
                style="grid-area: ok;"
                on:click={() => {
                  userMfaUpdate(recipient_uid, 2, {
                    code: mfa_verification_code,
                  }).then((x) => {
                    if (x.ok) {
                      mfa_state = 2;
                      showToast(
                        "Success! Multi-factor authentication was enabled.",
                        2000,
                        "white",
                        "MM"
                      );
                      showMFAModal = false;
                    } else {
                      showToast(
                        `Failure! Multi-factor authentication was not enabled, press Resend to send a code again.`,
                        2000,
                        "error",
                        "MM"
                      );
                    }
                    verification_in_progress = false;
                  });
                }}
              >
                <LoadingButton
                  color="primary"
                  icon="check"
                  fullWidth={true}
                  bind:pressed={verification_in_progress}
                  text="Verify"
                />
              </span>
              <span
                style="grid-area: resend;"
                on:click={() => {
                  userMfaUpdate(recipient_uid, 10);
                  resend_button_color = "white";
                }}
              >
                <Button
                  color={resend_button_color}
                  icon="share"
                  text="Resend Code"
                />
              </span>
              <span
                style="grid-area: cancel;"
                on:click={() => {
                  userMfaUpdate(recipient_uid, 0);
                  mfa_state = 0;
                  showMFAModal = false;
                }}
              >
                <Button color="gray" icon="times-circle" text="Cancel Setup" />
              </span>
            </div>
          </div>
        {/if}
      </div>
    {:else if mfa_current_tab == 1}
      <div class="mfa-modal">
        {#if mfa_state == 0}
          <p>
            To setup multi-factor authentication using an authenticator app,
            please scan the below QR code into your authenticator app on your
            phone. After scanning it, your app should display a 6-digit code.
            Enter it in the text field below the QR code and your authenticator
            will be confirmed.
          </p>
          <div
            style="display: flex; flex-flow: row nowrap; justify-content: space-around;"
          >
            <QrCode value={mfa_secret_data} />
          </div>
          <div
            style="margin-top: 2rem; display: flex; flex-flow: row nowrap; justify-content: space-around;"
          >
            <TextField
              bind:value={mfa_verification_code}
              text="Verification Code"
            />
          </div>
          <div
            style="margin-top: 1rem; display: flex; flex-flow: row nowrap; justify-content: space-between;"
          >
            <span
              style="width: 100%;"
              on:click={() => {
                userMfaUpdate(recipient_uid, 13, {
                  code: mfa_verification_code,
                }).then((x) => {
                  if (x.ok) {
                    mfa_state = 4;
                    showToast(
                      "Success! Multi-factor authentication was enabled.",
                      2000,
                      "white",
                      "MM"
                    );
                    showMFAModal = false;
                  } else {
                    showToast(
                      `Failure! Multi-factor authentication was not enabled, press Resend to send a code again.`,
                      2000,
                      "error",
                      "MM"
                    );
                  }
                  verification_in_progress = false;
                });
              }}
            >
              <LoadingButton
                color="primary"
                icon="check"
                bind:pressed={verification_in_progress}
                fullWidth={true}
                text="Verify"
              />
            </span>
          </div>
        {/if}
      </div>
    {/if}
  </Modal>
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showFileUploadModal}
  <FileUploadModal
    requireIACwarning={false}
    multiple={false}
    on:close={() => {
      showFileUploadModal = false;
    }}
    on:done={handleCompanyLogoUpload}
    specialText="Recommended filetype is .png and dimensions are 400x100 (4:1 Aspect Ratio)"
    uploadHeaderText="Upload an Image"
    requiredFileFormats=".png, .svg, .jpg, .jpeg"
    conditionalFileUploadAllowed=""
    checkForCustomFiletype={true}
  />
{/if}

{#if showLogoPreview}
  <LogoPreview
    {company_id}
    logo={newLogo}
    closeModal={() => {
      showLogoPreview = false;
    }}
  />
{/if}

{#if showRetentionConfirmation}
  <ConfirmationDialog
    title="Warning!"
    question="Shortening retention settings may cause some older files to be deleted. Lengthening retention may impact your billing."
    yesText="Save"
    noText="Cancel"
    yesColor="danger"
    noColor="primary"
    on:yes={handleSaveFileRetention}
    on:close={resetRetentionValues}
  />
{/if}

<style>
  .integration-text {
    line-height: 14px;
    padding: 5px;
    margin-left: 5px;
  }
  .logo {
    max-width: 400px;
    height: auto;
    display: block;
    margin: 1rem 0;
  }
  * {
    box-sizing: border-box;
  }

  .label-action {
    display: flex;
    align-items: center;
    margin-bottom: 0.5rem;
  }

  .page-header {
    position: sticky;
    top: 10px;
    z-index: 10;
  }

  .mfa-verification {
    max-width: 100%;
    display: grid;
    grid-template-areas: "code code code" "ok resend cancel";
    grid-template-columns: 1fr 1fr 1fr;
    grid-template-rows: 1fr 1fr;
    grid-gap: 0.25rem;
    row-gap: 1rem;
    padding-top: 0.5rem;
  }

  .container {
    color: #76808b;
    /* margin: 2em auto;
    padding: 0 1em; */
    color: #76808b;
  }

  .card {
    padding: 2em;
    box-shadow: rgba(0, 0, 0, 0.1) 0px 4px 12px;
    border-radius: 15px;
    position: relative;
  }

  .edit-button {
    position: absolute;
    top: 1em;
    right: 1em;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    cursor: pointer;
  }

  .edit-button:hover {
    box-shadow: rgba(0, 0, 0, 0.1) 0px 4px 12px;
  }

  .row {
    margin-bottom: 1rem;
    border-bottom: 0.5px solid #e0e2e3;
    padding-bottom: 0.5rem;
  }

  .row:last-child {
    margin-bottom: 0;
  }

  .row .label {
    font-weight: bold;
  }
  .row .sublabel {
    font-weight: 100;
    font-size: 14px;
    color: #505253;
    padding-bottom: 1rem;
    padding-top: 0.25rem;
    max-width: 500px;
  }

  .wrapper {
    max-width: 850px;
  }
  .details-edit {
    margin: 0 auto;
    margin-top: 1rem;
    display: grid;
    place-items: center;
  }

  @media only screen and (max-width: 640px) {
    .mfa-verification {
      align-items: center;
      display: block;
    }
    .mfa-verification span {
      display: block;
    }

    .mfa-verification span:not(:first-child) {
      margin-bottom: 5px;
    }
  }
  @media only screen and (max-width: 767px) {
    .card {
      padding: 1rem;
    }

    .label-action {
      align-items: center;
      justify-content: space-between;
    }
  }

  .tr {
    width: 100%;
    display: grid;
    justify-items: center;
    align-items: center;
    grid-template-columns: repeat(4, 1fr);
    padding: 0.5rem;
    padding-left: 20px;
    row-gap: 0.3rem;
    grid-template-areas: "a b c d";
  }
  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .tr:not(.th) {
    padding-top: 1rem;
    padding-bottom: 1rem;
  }

  .td.alignment {
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
    flex-grow: 2;
    justify-content: left;
    justify-self: left;
  }

  .td.name {
    grid-area: a;
  }
  .td.email {
    grid-area: b;
  }

  .td.DateAdded {
    grid-area: c;
  }

  .td.LastLogin {
    grid-area: d;
  }

  /* .td.Actions {
    grid-area: e;
    justify-content: center;
    justify-self: center;
  } */

  .outer-border {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    margin-bottom: 1em;
  }
  @media only screen and (max-width: 767px) {
    .tr {
      grid-template-columns: repeat(2, 1fr);
      grid-template-areas:
        "a b"
        "c d";
    }
    .td.alignment {
      justify-content: center;
      justify-self: center;
    }
  }
</style>
