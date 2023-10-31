<script>
  import File from "../../atomic/File.svelte";
  import Button from "../../atomic/Button.svelte";
  import NavBar from "../../components/NavBar.svelte";
  import Selector from "../../components/Selector.svelte";
  import TextField from "../../components/TextField.svelte";
  import BottomBar from "../../components/BottomBar.svelte";
  import NavHeader from "../../components/Requestor/NavHeader.svelte";
  import Radio from "../../components/Radio.svelte";
  import Switch from "../../components/Switch.svelte";
  import Checkbox from "../../components/Checkbox.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import { isNullOrUndefined, searchParamObject } from "../../../helpers/util";
  import {
    getTemplate,
    updateTemplate,
    replaceActiveTemplateUpload,
  } from "BoilerplateAPI/Template";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import DocumentTag from "./DocumentTag.svelte";
  import { resetTemplate } from "../../../api/Template";
  import Loader from "../../components/Loader.svelte";

  export let templateId;
  export let makeNewTemplate = false;
  let showUploadModal = false;
  let changes_saved = false;
  let isNewTemplate = false;
  let fromUserGuide = false;
  const searchParams = searchParamObject();
  isNewTemplate =
    (searchParams.type && searchParams.type == "newTemplate") || false;
  fromUserGuide = searchParams.userGuide === "true" ? true : false;
  let disableTemplateTypeChange = !(isNewTemplate || makeNewTemplate); // disable change template type on template edit
  let disabledTextMessage =
    "Disabled! To change the type, create a new template.";

  let requestParams = searchParamObject();
  const isDup = requestParams.dup === "true" ? true : false;
  async function loadTemplate(templateId) {
    return getTemplate(templateId, "requestor").then((result) => {
      template_name = result.name;
      template_description = result.description;
      template_type = result.is_rspec ? 1 : result.is_info ? 2 : 0;
      template_file_name = result.file_name;
      template_allow_edits = result.allow_edits;
      // Non IAC files like xls, xlsx defaults to generic file type
      if (makeNewTemplate && result.type === 0 && !isDup) {
        template_type = 3;
      }
      docTags = [...result.tags?.values];

      return Promise.resolve(result);
    });
  }
  let template = loadTemplate(templateId);
  let track_document_expiration = false;
  let showTemplateResetConfirmationBox = false;
  let showLoadingIcon = false;

  let template_name = "",
    template_description = "",
    template_file_name = "",
    template_type = 3,
    template_allow_edits = false,
    docTags = [];
  let current_tab = 0;
  let min_tab = 0,
    max_tab = 1;

  // added for future use
  let fileRetentionPeriod = null;
  /* Send a PUT request to update the API */
  async function saveChanges() {
    let raw = {
      id: templateId,
      name: template_name,
      description: template_description,
      is_rspec: template_type == 1,
      is_info: template_type == 2,
      allow_edits: template_allow_edits,
      file_retention_period: fileRetentionPeriod,
      tags: [...new Set(docTags.map((x) => x.id))],
    };

    let reply = await updateTemplate(templateId, raw);
    if (reply.ok) {
      return true;
    } else {
      alert("Something went wrong while updating the template.");
    }
  }

  let showReplaceFileConfirmationBox = false;

  /* The document is being replaced */
  async function processReplacement(evt) {
    let detail = evt.detail;
    let id = await replaceActiveTemplateUpload(templateId, detail.file);

    showUploadModal = false;

    /* Replacing the file should also save the pending changes */
    saveChanges();

    if (id !== undefined) {
      showToast(`Success! File Replaced.`, 1000, "default", "MM");
      const newHash = window.location.hash.replace(templateId, id);
      window.location.hash = newHash;
      window.location.reload();
    } else {
      alert("Failed to replace this file");
    }
  }

  /* The document file is reset */
  async function processTemplateReset(id, flag) {
    console.log(id, flag);
    let newTemplateId = await resetTemplate(id, flag);
    showLoadingIcon = false;
    if (newTemplateId !== undefined) {
      window.location.hash = `#template/new/${newTemplateId}?redirect=#templates&dup=true`;
      window.location.reload();
    } else {
      alert("Failed to replace this file");
    }
  }

  function doBack() {
    if (current_tab == min_tab) {
      saveChanges().then(() => {
        window.history.back(-1);
      });
    } else {
      current_tab--;
    }
  }

  function doNext() {
    if (current_tab == max_tab) {
      // do nothing
    } else if (current_tab == 0 && template_type == 3) {
      // alert("Select a Template Type")
      showToast(`Error! Select Template Type.`, 2000, "error", "MM");
    } else {
      current_tab++;
    }
  }
  let templateFlag;
  function templateTypeToFlagMapper(value) {
    switch (value) {
      case 0:
        return 0;
      case 1:
        return 2;
      case 2:
        return 8;
      default:
        return 0;
    }
  }

  $: if (current_tab == 1) {
    current_tab = 0;
    if (template_type === 3) {
      showToast(`Error! Select Template Type.`, 2000, "error", "MM");
    } else {
      saveChanges().then(() => {
        if (
          template_type != 2 &&
          template_file_name.toLowerCase().endsWith(".pdf")
        ) {
          if (fromUserGuide) {
            window.location.hash = `#iac/setup/template/${templateId}`;
          } else {
            window.location.hash = `#iac/setup/template/${templateId}?redirectTo=#templates`;
          }
        } else if (isNewTemplate) {
          window.history.go(-1);
        } else {
          window.location.hash = `#templates`;
        }
      });
    }
  }

  const switchActionTemplateAllowEdit = (checked) => {
    template_allow_edits = checked;
  };

  function goBack() {
    console.log(requestParams);
    if (isNullOrUndefined(requestParams.redirect)) {
      return "javascript:window.history.back(-1)";
    }
    return requestParams.redirect;
  }
</script>

<div class="desktop-only">
  <NavBar
    navbar_spacer_classes="navbar_spacer_pb1"
    backLink="  "
    backLinkHref={goBack()}
    backLinkAction={() => {
      saveChanges().then(() => {
        showToast(`Template changes saved.`, 2000, "default", "MM");
      });
    }}
    middleText={`Setup: ${template_name}`}
    middleSubText={template_description}
  />
</div>

<div class="mobile-only">
  <NavBar
    backLink="  "
    backLinkHref={goBack()}
    backLinkAction={() => {
      saveChanges().then(() => {
        showToast(`Template changes saved.`, 2000, "default", "MM");
      });
    }}
    showCompanyLogo={false}
    middleText={`Setup: ${template_name}`}
    middleSubText={template_description}
  />
</div>

<section class="container tmpl-container" class:disableEvents={showLoadingIcon}>
  {#await template}
    <p>Loading template....</p>
  {:then tmpl}
    <section class="preamble">
      <div class="tabbar">
        {#if showLoadingIcon}
          <Loader loading={showLoadingIcon} absoluteLoader={true} />
        {/if}
        <span
          class="tab"
          class:is-active={current_tab == 0}
          on:click={() => (current_tab = 0)}>Description</span
        >
        {#if template_type != 2 && template_type != 3 && tmpl.file_name
            .toLowerCase()
            .endsWith(".pdf")}
          <span
            class="tab"
            class:is-active={current_tab == 1}
            on:click={() => (current_tab = 1)}>Form & Signature Setup</span
          >
        {/if}
      </div>
    </section>
    <section class="content">
      <section class="main-content">
        {#if current_tab == 0}
          <p class="heading">TEMPLATE INFO</p>
          <div class="field">
            <p>Template file name</p>
            <div class="template-file ">
              <File name={tmpl.file_name.toLowerCase()} showDelete={false} />
              <div class="actions">
                {#if !makeNewTemplate}
                  <span
                    on:click={() => {
                      templateFlag = templateTypeToFlagMapper();
                      showTemplateResetConfirmationBox = true;
                    }}
                  >
                    <Button color="white" text="Change Template type" />
                  </span>
                {/if}

                <a
                  href={`#view/template/${templateId}?newTab=true&filePreview=true`}
                  target="_blank"
                  style="text-decoration: none;"
                >
                  <Button color="white" text="Preview" />
                </a>
                <span
                  on:click={() => {
                    showReplaceFileConfirmationBox = true;
                  }}
                >
                  <Button color="white" text="Replace file" />
                </span>
              </div>
            </div>
          </div>
          <div class="field">
            <p>Template Display Name <span class="required">*</span></p>
            <span>
              <TextField
                bind:value={template_name}
                maxlength={"61"}
                text="name"
              />
              {#if template_name.length > 60}
                <div class="errormessage" id="name">
                  {"Character limit (60) reached."}
                </div>
              {/if}
              {#if template_name.replace(/\s/g, "").length < 1 && template_name.length >= 1}
                <div class="errormessage" id="name">
                  {"All Whitespaces are not allowed."}
                </div>
              {/if}
            </span>
          </div>
          <div class="field">
            <p>Description</p>
            <span>
              <TextField
                bind:value={template_description}
                maxlength={"61"}
                text="description"
              />
              {#if template_description.length > 60}
                <div class="errormessage" id="name">
                  {"Character limit (60) reached."}
                </div>
              {/if}
            </span>
          </div>
          <div class="field">
            <p>Tags</p>
            <DocumentTag
              companyID={tmpl.company_id}
              templateTagIds={tmpl.tags?.id}
              bind:tagsSelected={docTags}
            />
          </div>
          <div class="field">
            <p>Template Type <span class="required">*</span></p>
            <span>
              <Radio
                disable={disableTemplateTypeChange}
                disableReason={""}
                elements={{
                  "Generic (Send as is). The document will send exactly the same to every recipient with no chance to customize in our system before sending": 0,
                  "Contact-specific (customize before sending). Before sending to another person, you'll be able to (1) import/ swap-in a document prepared outside Boilerplate (like in Word), or (2) pre-fill/ fill-in-the-blanks to personalize a template saved on our system.": 1,
                  "Information-Only. The other party will be able to view and download the document, but not fill or sign it.": 2,
                }}
                bind:selectedValue={template_type}
                showDisabledText={false}
                on:disabled={(evt) => {
                  templateFlag = templateTypeToFlagMapper(evt.detail);
                  showTemplateResetConfirmationBox = true;
                }}
                type="Template"
              />
            </span>
          </div>
          <div class="field">
            <p>Actions after client submission</p>
            <span>
              <Switch
                checked={template_allow_edits}
                action={switchActionTemplateAllowEdit}
                text="Enable counter-signatures and form filling after submission"
                icon="file-signature"
              />
            </span>
          </div>
        {/if}
      </section>
    </section>
  {:catch error}
    <p>Failed to load this template</p>
  {/await}
</section>
{#if $isToastVisible}
  <ToastBar />
{/if}
<div class="mobile-only">
  <BottomBar
    leftButtons={[
      { button: "Previous tab", evt: "back", disabled: false, color: "white" },
      {
        button: "Next tab",
        evt: "next",
        color: "white",
        disabled:
          current_tab == max_tab ||
          (current_tab == 0 && template_type == 3) ||
          template_name.length > 60 ||
          template_description.length > 60 ||
          (template_name.replace(/\s/g, "").length < 1 &&
            template_name.length >= 1),
      },
    ]}
    rightButtons={[
      {
        button: "Cancel",
        evt: "cancel",
        disabled: false,
        color: "danger",
      },
      {
        button: "Save & Finish Later",
        evt: "save",
        color: "primary",
        disabled:
          template_name.length > 60 ||
          template_description.length > 60 ||
          (template_name.replace(/\s/g, "").length < 1 &&
            template_name.length >= 1),
      },
    ]}
    saveDisabled={changes_saved}
    nextdisabled={current_tab == max_tab}
    on:save={() => {
      if (template_type === 3) {
        showToast(`Error! Select Template Type.`, 2000, "error", "MM");
        return;
      }
      saveChanges().then(() => {
        window.location.hash = `#templates`;
      });
    }}
    on:back={doBack}
    on:cancel={() => {
      window.location.hash = `#templates`;
    }}
    on:next={doNext}
  />
</div>
<div class="desktop-only">
  <BottomBar
    leftButtons={[
      { button: "Cancel", evt: "cancel", disabled: false, color: "gray" },
      { button: "Previous tab", evt: "back", disabled: false, color: "gray" },
    ]}
    rightButtons={[
      {
        button: "Save & Finish Later",
        evt: "save",
        color: "gray",
        disabled:
          template_name.length > 60 ||
          template_description.length > 60 ||
          (template_name.replace(/\s/g, "").length < 1 &&
            template_name.length >= 1),
      },
      {
        button: "Next tab",
        evt: "next",
        disabled:
          current_tab == max_tab ||
          (current_tab == 0 && template_type == 3) ||
          template_name.length > 60 ||
          template_description.length > 60 ||
          (template_name.replace(/\s/g, "").length < 1 &&
            template_name.length >= 1),
      },
    ]}
    saveDisabled={changes_saved}
    nextdisabled={current_tab == max_tab}
    on:save={() => {
      if (template_type === 3) {
        showToast(`Error! Select Template Type.`, 2000, "error", "MM");
        return;
      }
      saveChanges().then(() => {
        window.location.hash = `#templates`;
      });
    }}
    on:back={doBack}
    on:cancel={() => {
      window.location.hash = `#templates`;
    }}
    on:next={doNext}
  />
</div>

{#if showUploadModal}
  <UploadFileModal
    multiple={false}
    uploadHeaderText={`Replace Template`}
    requireIACwarning={true}
    on:done={processReplacement}
    on:close={() => {
      showUploadModal = false;
    }}
  />
{/if}

{#if showTemplateResetConfirmationBox}
  <ConfirmationDialog
    question={`this resets the previous template versions and allows to setup template, but will not impact versions that were previously sent.
      You will need to setup online form filling again for this new template.`}
    yesText="Proceed with template replace"
    noText="Cancel"
    yesColor="primary"
    noColor="white"
    on:yes={() => {
      showLoadingIcon = true;
      processTemplateReset(templateId, templateFlag);
      showTemplateResetConfirmationBox = false;
    }}
    on:close={() => {
      showTemplateResetConfirmationBox = false;
    }}
  />
{/if}

{#if showReplaceFileConfirmationBox}
  <ConfirmationDialog
    question={`Replacing this template will update all sent versions of this template going forward, but will not impact versions that were previously sent.
      You will need to setup online form filling again for this replacement template.`}
    yesText="Proceed with replace"
    noText="Cancel"
    yesColor="primary"
    noColor="white"
    on:yes={() => {
      showUploadModal = true;
      showReplaceFileConfirmationBox = false;
    }}
    on:close={() => {
      showReplaceFileConfirmationBox = false;
    }}
  />
{/if}

{#if showLoadingIcon}
  <ConfirmationDialog question="Template Reset in progress" hideX={true} />
{/if}

<style>
  /* Container */
  * {
    box-sizing: border-box;
  }
  .container {
    padding-left: 4rem;
    padding-right: 4rem;
    margin-bottom: 100px;
  }

  .disableEvents {
    pointer-events: none;
  }

  .required {
    color: rgb(221, 38, 38);
  }

  .preamble {
    position: sticky;
    top: 64px;
    background: #fcfdff;
    padding: 0.5rem;
    /* padding-top: 0; */
    margin-top: 1rem;
    z-index: 1;
  }
  section.content {
    padding-top: 1rem;
  }

  .tabbar {
    display: flex;
    width: 100%;
    flex-flow: row nowrap;
  }

  .tab {
    flex-grow: 1;
    justify-content: center;
    text-align: center;

    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    color: #b3c1d0;
    padding-bottom: 1rem;

    cursor: pointer;
  }

  .tab:hover {
    border-bottom: 1px solid #2a2f3462;
  }

  .tab.is-active {
    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    color: #2a2f34;
    border-bottom: 2px solid #2a2f34;
    cursor: default;
  }

  /* Content */
  .main-content {
    background: #ffffff;

    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 2rem;
  }

  /* Description tab */
  .heading {
    font-weight: 600;
    font-size: 18px;
    line-height: 22px;
    color: #4a5158;
  }

  .field {
    margin-bottom: 2rem;
    width: 60%;
  }

  .field > p {
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #4a5158;
  }

  .template-file {
    display: grid;
    /* flex-flow: row nowrap; */
    align-items: center;
    row-gap: 1rem;
  }
  .template-file > .actions {
    display: grid;
    grid-template-columns: 1fr 0.3fr 1fr;
    justify-self: end;
    column-gap: 0.5rem;
  }
  .template-file .actions a {
    justify-self: end;
  }

  .errormessage {
    display: inline-block;
    color: #cc0033;
    font-size: 12px;
    font-weight: bold;
    line-height: 15px;
  }
  .mobile-only {
    display: none;
  }
  @media only screen and (max-width: 1024px) {
    .field {
      width: 70%;
    }
  }
  @media only screen and (max-width: 767px) {
    .field {
      width: 100%;
    }
    .template-file > .actions {
      display: flex;
      flex-direction: column;
      margin-inline: auto;
    }
    .template-file > .actions > * {
      margin-bottom: 1rem;
    }

    .container {
      padding-inline: 2rem;
    }

    .tab {
      font-size: 14px !important;
      padding-inline: 0.5rem;
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
  }

  @media only screen and (min-width: 1024px) {
    .template-file {
      /* flex-flow: row nowrap; */
      grid-template-columns: 3fr 1fr;
    }
  }
</style>
