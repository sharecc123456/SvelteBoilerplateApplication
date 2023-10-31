<script>
  import { onMount } from "svelte";
  import { add_template_modal } from "./../../../store";
  import Dropdown from "../../components/Dropdown.svelte";
  import UploadFileModal from "../../modals/UploadFileModal.svelte";
  import BackgroundPageHeader from "../../components/BackgroundPageHeader.svelte";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import TemplateMobileView from "../../components/TemplateHelpers/TemplateMobileView.svelte";

  import {
    getTemplates,
    deleteTemplate,
    archiveTemplate,
  } from "BoilerplateAPI/Template";
  import { showErrorMessage } from "Helpers/Error";
  import { featureEnabled } from "Helpers/Features";
  import { convertTime } from "Helpers/util";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import EmptyDefault from "../../util/EmptyDefault.svelte";
  import Loader from "../../components/Loader.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import Button from "../../atomic/Button.svelte";
  import Modal from "Components/Modal.svelte";
  import ProgressTab from "../../components/ProgressTab.svelte";
  import ChooseRecipientModal from "../../modals/ChooseRecipientModal.svelte";
  import { createNewChecklist, archiveChecklist } from "../../../api/Checklist";
  import { requestorTemplateNonIACExtensions } from "../../../helpers/fileHelper";
  import Tag from "../../atomic/Tag.svelte";
  import { replaceActiveTemplateUpload } from "../../../api/Template";
  import { isMobile } from "../../../helpers/util";

  let search_value = "";
  let templates = [];
  let showUploadModal = false;
  let templateTipsPopUp = false;
  let templateTipsPopUpPage = 0;
  let templateTipsPopUpCheckbox = false;
  let showReplaceFileConfirmationBox = false;
  let showReplaceUploadModal = false;
  let isLoading = true;
  let apiError = false;
  let templateNotFound = false;
  let totaltemplatesCount = 0;
  $: showUploadModal = $add_template_modal;
  let donotShowTemplateRequestSendDialog = JSON.parse(
    localStorage.getItem("dontshowTemplateSendRequestDialog")
  );

  onMount(() => {
    loadTemplates();
  });

  const templateTipsPopUpHandleCheckbox = () => {
    templateTipsPopUpCheckbox = !templateTipsPopUpCheckbox;
  };

  let templateTipsPopUpStatus = JSON.parse(
    localStorage.getItem("dontShowtemplateTipsPopUp")
  );

  let loadTemplates = async () => {
    try {
      templates = await getTemplates();
      totaltemplatesCount = templates.length;
    } catch (error) {
      apiError = true;
      console.log(error);
    }
    isLoading = false;
  };

  /* A new file was selected */
  async function processNewTemplate(evt) {
    let detail = evt.detail;
    let fd = new FormData();
    fd.append("name", detail.name);
    fd.append("upload", detail.file);

    let reply = await fetch(`/n/api/v1/template`, {
      method: "POST",
      credentials: "include",
      body: fd,
    });

    console.log(reply);
    if (reply.ok) {
      let jsonReply = await reply.json();
      window.location.hash = `#template/new/${jsonReply.id}`;
    } else {
      alert("Something went wrong while uploading this file");
    }
  }

  let templateDropdown = [
    {
      text: "Send as single Request",
      icon: "paper-plane",
      iconStyle: "solid",
      ret: 5,
    },
    {
      text: "Preview",
      icon: "eye",
      iconStyle: "solid",
      ret: 3,
    },
    {
      text: "Details / Edit",
      icon: "info-circle",
      iconStyle: "solid",
      disabled: !featureEnabled("requestor_allow_template_edit"),
      ret: 2,
    },
    {
      text: "Replace",
      icon: "exchange",
      iconStyle: "solid",
      ret: 6,
    },
    {
      text: "Archive",
      icon: "archive",
      iconStyle: "solid",
      disabled: !featureEnabled("requestor_allow_template_edit"),
      ret: 4,
    },
    {
      text: "Delete",
      icon: "trash",
      iconStyle: "solid",
      disabled: !featureEnabled("requestor_allow_template_edit"),
      ret: 1,
    },
  ];

  let templateDropdownMobile = [
    {
      text: "Send as single Request",
      icon: "paper-plane",
      iconStyle: "solid",
      ret: 5,
    },
    {
      text: "Preview",
      icon: "eye",
      iconStyle: "solid",
      ret: 3,
    },
    {
      text: "Archive",
      icon: "archive",
      iconStyle: "solid",
      disabled: !featureEnabled("requestor_allow_template_edit"),
      ret: 4,
    },
    {
      text: "Delete",
      icon: "trash",
      iconStyle: "solid",
      disabled: !featureEnabled("requestor_allow_template_edit"),
      ret: 1,
    },
  ];

  let showSelectRecipientModal = false;
  let newChecklistId = null;
  async function processRecipientSelection(evt) {
    let detail = evt.detail;
    let checklist_created = await createChecklist(templateRequestToSend);

    if (checklist_created) {
      // hides the newly created checklist from the checklist screen
      await archiveChecklist(newChecklistId);
      window.location.hash = `#recipient/${detail.recipientId}/assign/${newChecklistId}`;
    } else {
      showToast(
        `Could create new submission. Please try again later!.`,
        1500,
        "error",
        "MM"
      );
    }
    showSelectRecipientModal = false;
    newChecklistId = null;
  }

  async function createChecklist(template) {
    let checklistContents = {
      name: template.name,
      description: template.description == "" ? "-" : template.description,
      documents: [template.id],
      file_requests: [],
      commit: true,
      allow_duplicate_submission: false,
      allow_multiple_requests: false,
    };
    let reply = await createNewChecklist(checklistContents);
    if (reply.ok) {
      let response = await reply.json();
      newChecklistId = response.id;
      return true;
    } else {
      return false;
    }
  }

  function onSendTemplate() {
    showSendTemplateRequestConfirmationDialog = false;
    showSelectRecipientModal = true;
  }

  async function tryDeleteTemplate(template) {
    let reply = await deleteTemplate(template.id);

    if (reply.ok) {
      /* reload the template list */
      loadTemplates();
      showDeleteConfirmationDialog = false;
      toBeDel = null;
    } else {
      showDeleteConfirmationDialog = false;
      toBeDel = null;
      let error = await reply.json();
      showErrorMessage("template", error.error);
    }
  }

  async function tryArchiveTemplate(template) {
    let reply = await archiveTemplate(template.id);
    showArchiveConfirmationDialog = false;
    templateToArchive = null;

    if (reply.ok) {
      showToast(`Success! Template Archived.`, 300, "default", "MM");
      /* reload the template list */

      loadTemplates();
    } else {
      showToast(`Error! unable to archive Template.`, 500, "error", "MM");
    }
  }

  let toBeDel = null;
  let showDeleteConfirmationDialog = false;
  let showArchiveConfirmationDialog = false;
  let showSendTemplateRequestConfirmationDialog = false;
  let templateRequestToSend;
  let templateToArchive;
  let templateToReplace;
  function dropdownClick(template, ret) {
    switch (ret) {
      case 1 /* Delete */:
        toBeDel = template;
        showDeleteConfirmationDialog = true;
        break;
      case 2 /* Details */:
        window.location.hash = `#template/${template.id}`;
        break;
      case 3 /* Preview */:
        window.location.hash = `#view/template/${template.id}?filePreview=true`;
        break;
      case 4 /* Archive */:
        templateToArchive = template;
        showArchiveConfirmationDialog = true;
        break;
      case 5 /* Send Template As Checklist */:
        templateRequestToSend = template;
        donotShowTemplateRequestSendDialog = JSON.parse(
          localStorage.getItem("dontshowTemplateSendRequestDialog")
        );
        donotShowTemplateRequestSendDialog === true
          ? (showSelectRecipientModal = true)
          : (showSendTemplateRequestConfirmationDialog = true);
        break;
      case 6:
        templateToReplace = template;
        showReplaceFileConfirmationBox = true;
        break;

      default:
        alert("unknown dropdown click: " + ret);
    }
  }

  let sortType1 = 1;
  let sortType2 = 1;
  let sortType3 = 1;
  let sortType4 = 1;
  function sortState(array, type) {
    let sortedArray;
    if (type == 1) {
      switch (sortType1) {
        case 1 /* Switching to ABC */:
          sortType1 = 2;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          break;
        case 2 /* Switching to ZXY */:
          sortType1 = 3;
          sortedArray = array.sort((b, a) => a.name.localeCompare(b.name));
          break;
        case 3 /* Switching to Original Array */:
          sortType1 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          break;
      }
    } else if (type == 2) {
      switch (sortType2) {
        case 1 /* Switching to inserted_at a .. B */:
          sortType2 = 2;
          sortedArray = array.sort((a, b) =>
            a.inserted_at.localeCompare(b.inserted_at)
          );
          break;
        case 2 /* Switching to inserted_at b .. A */:
          sortType2 = 3;
          sortedArray = array.sort((b, a) =>
            a.inserted_at.localeCompare(b.inserted_at)
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType2 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          break;
      }
    } else if (type == 3) {
      switch (sortType3) {
        case 1 /* Switching to Generic, Info Only, or RSD */:
          sortType3 = 2;
          sortedArray = array.sort(function (x, y) {
            let tempx, tempy;
            tempx = x.is_rspec ? 0 : x.is_info ? 1 : 2;
            tempy = y.is_rspec ? 0 : y.is_info ? 1 : 2;

            return tempx < tempy;
          });
          break;
        case 2 /* Switching to RSD, Info Only, Generic*/:
          sortType3 = 3;
          sortedArray = array.sort(function (y, x) {
            let tempx, tempy;
            tempx = x.is_rspec ? 0 : x.is_info ? 1 : 2;
            tempy = y.is_rspec ? 0 : y.is_info ? 1 : 2;

            return tempx < tempy;
          });
          break;
        case 3 /* Switching to Original Array */:
          sortType3 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          break;
      }
    } else if (type == 4) {
      switch (sortType4) {
        case 1 /* Switching to inserted_at a .. B */:
          sortType4 = 2;
          sortedArray = array.sort((a, b) =>
            a.updated_at.localeCompare(b.updated_at)
          );
          break;
        case 2 /* Switching to inserted_at b .. A */:
          sortType4 = 3;
          sortedArray = array.sort((b, a) =>
            a.updated_at.localeCompare(b.updated_at)
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType4 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          break;
      }
    }
    templates = sortedArray;
  }

  let scrollY;

  /* The document is being replaced */
  async function processReplacement(evt) {
    let detail = evt.detail;
    let id = await replaceActiveTemplateUpload(
      templateToReplace.id,
      detail.file
    );

    showReplaceUploadModal = false;
    templateToReplace = undefined;

    if (id !== undefined) {
      window.location.hash = `#template/${id}`;
    } else {
      alert("Failed to replace this file");
    }
  }

  $: {
    if (search_value) {
      let found = templates.some(
        (temp) =>
          temp?.name.toLowerCase()?.includes(search_value?.toLowerCase()) ||
          temp?.description
            ?.toLowerCase()
            ?.includes(search_value?.toLowerCase())
      );
      found ? (templateNotFound = false) : (templateNotFound = true);

      isLoading = true;
      setTimeout(() => {
        isLoading = false;
      }, 1000);
    }
  }
</script>

<svelte:window bind:scrollY />

<BackgroundPageHeader {scrollY} />

<div class="page-header">
  <RequestorHeaderNew
    contactCount={totaltemplatesCount}
    title="Reusable Individual Templates"
    icon="copy"
    headerBtn={featureEnabled("requestor_allow_template_creation")}
    btnText="Create New Templates"
    bind:search_value
    searchPlaceholder="Search Templates"
    btnAction={() => {
      templateTipsPopUpStatus = JSON.parse(
        localStorage.getItem("dontShowtemplateTipsPopUp")
      );
      if (templateTipsPopUpStatus) {
        showUploadModal = true;
      } else {
        templateTipsPopUp = true;
      }
    }}
  />
</div>

<section id="main" class="content">
  <div class="table">
    {#if isLoading}
      <span class="loader-container">
        <Loader loading />
      </span>
    {:else if templates.length}
      <div class="tr th">
        <div class="td name">
          <div
            class="sortable {sortType1 === 2 || sortType1 === 3
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click={() => {
              sortState(templates, 1);
            }}
          >
            Template Name &nbsp;
            {#if sortType1 == 1}
              <div><FAIcon iconStyle="solid" icon="sort" /></div>
            {:else if sortType1 == 2}
              <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
            {:else if sortType1 == 3}
              <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
            {/if}
            &nbsp;
          </div>
        </div>
        <div class="td type">
          <div
            class="sortable {sortType3 === 2 || sortType3 === 3
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click={() => {
              sortState(templates, 3);
            }}
          >
            Type &nbsp;
            {#if sortType3 == 1}
              <div><FAIcon iconStyle="solid" icon="sort" /></div>
            {:else if sortType3 == 2}
              <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
            {:else if sortType3 == 3}
              <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
            {/if}
            &nbsp;
          </div>
        </div>
        <div class="td type">
          <div
            class="sortable {sortType2 === 2 || sortType2 === 3
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click={() => {
              sortState(templates, 2);
            }}
          >
            Created &nbsp;
            {#if sortType2 == 1}
              <div><FAIcon iconStyle="solid" icon="sort" /></div>
            {:else if sortType2 == 2}
              <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
            {:else if sortType2 == 3}
              <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
            {/if}
            &nbsp;
          </div>
        </div>
        <div class="td type">
          <div
            class="sortable {sortType4 === 2 || sortType4 === 3
              ? 'selectedBorder'
              : ''}"
            style="display: flex;
                  align-items: center;"
            on:click={() => {
              sortState(templates, 4);
            }}
          >
            Modified &nbsp;

            {#if sortType4 == 1}
              <div><FAIcon iconStyle="solid" icon="sort" /></div>
            {:else if sortType4 == 2}
              <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
            {:else if sortType4 == 3}
              <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
            {/if}
            &nbsp;
          </div>
        </div>
        <div class="td actions actions-header">Actions</div>
      </div>
      {#each templates as tmpl}
        {#if tmpl?.name
          ?.toLowerCase()
          ?.includes(search_value?.toLowerCase()) || tmpl?.description
            ?.toLowerCase()
            ?.includes(search_value?.toLowerCase())}
          <span class="outer-border desktop-only">
            <div
              on:click={() => {
                window.location.hash = `#template/${tmpl.id}`;
              }}
              class="tr"
            >
              <div class="td name columnar">
                <div class="tmpl-namedesc">
                  <span class="template-icon" style="flex-grow: 2;">
                    {#if tmpl.is_rspec}
                      <FAIcon icon="file-user" iconStyle="solid" />
                    {:else if tmpl.is_info}
                      <FAIcon icon="info-square" iconStyle="solid" />
                    {:else}
                      <FAIcon icon="file-alt" iconStyle="regular" />
                    {/if}
                  </span>
                  <div>
                    <div class="tmpl-name">{tmpl.name ? tmpl.name : ""}</div>
                    <div class="tmpl-description">
                      {tmpl.description ? tmpl.description : ""}
                    </div>
                  </div>
                </div>
                <div>
                  {#if tmpl.tags}
                    <ul class="reset-style">
                      {#each tmpl.tags.values as tag}
                        <Tag tag={{ ...tag, selected: true }} listTags={true} />
                      {/each}
                    </ul>
                  {/if}
                </div>
              </div>
              <div class="td type">
                <div class="tmpl-type">
                  {tmpl.is_rspec
                    ? "Contact-Specific PDF"
                    : tmpl.is_info
                    ? "Informational-Only"
                    : "Generic PDF"}
                </div>
              </div>
              <div class="td type desktop">
                <div class="tmpl-type">
                  {tmpl.inserted_at}
                  <br />
                  {convertTime(tmpl.inserted_at, tmpl.inserted_time)}
                </div>
              </div>
              <div class="td type desktop">
                <div class="tmpl-type">
                  {tmpl.updated_at}
                  <br />
                  {convertTime(tmpl.updated_at, tmpl.updated_time)}
                </div>
              </div>
              <div class="td actions">
                <span
                  on:click|stopPropagation={() => {
                    templateRequestToSend = tmpl;
                    donotShowTemplateRequestSendDialog = JSON.parse(
                      localStorage.getItem("dontshowTemplateSendRequestDialog")
                    );
                    donotShowTemplateRequestSendDialog === true
                      ? (showSelectRecipientModal = true)
                      : (showSendTemplateRequestConfirmationDialog = true);
                  }}
                >
                  <Button text="Send" />
                </span>
                {#if tmpl.is_iac}
                  <Dropdown
                    elements={templateDropdown}
                    triggerType="vellipsis"
                    clickHandler={(ret) => {
                      dropdownClick(tmpl, ret);
                    }}
                  />
                {:else}
                  <Dropdown
                    elements={templateDropdown}
                    triggerType="vellipsis"
                    clickHandler={(ret) => {
                      dropdownClick(tmpl, ret);
                    }}
                  />
                {/if}
              </div>
            </div>
          </span>

          <span class="mobile-only">
            <TemplateMobileView
              data={tmpl}
              {convertTime}
              templateDropdown={templateDropdownMobile}
              {dropdownClick}
              on:handleSend={({ detail: { data } }) => {
                templateRequestToSend = data;
                donotShowTemplateRequestSendDialog = JSON.parse(
                  localStorage.getItem("dontshowTemplateSendRequestDialog")
                );
                donotShowTemplateRequestSendDialog === true
                  ? (showSelectRecipientModal = true)
                  : (showSendTemplateRequestConfirmationDialog = true);
              }}
            />
          </span>
        {/if}
      {:else}
        <EmptyDefault
          defaultHeader="No templates found!"
          defaultMessage="Looks like you have not added any templates, start now by clicking Create New Template"
        />
      {/each}
    {:else if !templates.length}
      <EmptyDefault
        defaultHeader="No Templates Found!"
        defaultMessage="Nothing to display right now. Use the 'Create New Template' button to add."
      />
    {/if}

    {#if templateNotFound}
      <EmptyDefault
        cancelButton={true}
        defaultHeader="No Search results!"
        defaultMessage="No results for this search on this screen"
        on:close={() => {
          search_value = "";
        }}
      />
    {/if}

    {#if apiError}
      <EmptyDefault
        defaultHeader="Oh uh, something went wrong!"
        defaultMessage="Try refreshing the page through your browser navigation bar above. If that doesn’t work, please contact support@boilerplate.co thank you!"
        error
      />
    {/if}
  </div>
</section>

{#if templateTipsPopUp}
  {#if templateTipsPopUpStatus !== true}
    <Modal
      on:close={() => {
        templateTipsPopUp = false;
        showUploadModal = true;
        templateTipsPopUpPage = 0;

        if (templateTipsPopUpCheckbox) {
          localStorage.setItem("dontShowtemplateTipsPopUp", true);
        } else {
          localStorage.setItem("dontShowtemplateTipsPopUp", false);
        }
      }}
    >
      <p slot="header">User Guide</p>

      <div class="progress-tab">
        <ProgressTab
          elements={[
            "Standard Information",
            "Personalized Information",
            "Client Fills",
            "Fill After",
          ]}
          current={templateTipsPopUpPage}
        />
        <br />
      </div>

      {#if templateTipsPopUpPage == 0}
        <p class="tipsPopHeader">Standard Information</p>

        <div class="modal-subheader">
          Add any standard information that never changes, like your business
          info, to the document BEFORE loading it into the system.
        </div>
      {/if}

      {#if templateTipsPopUpPage == 1}
        <p class="tipsPopHeader">Personalized Information</p>

        <div class="modal-subheader">
          You`ll be able to set fields to be pre-filled in the system before
          sending to a specific person, like filling in details of a contract or
          offer letter. We recommend leaving these as blanks in the template you
          upload.
        </div>
      {/if}

      {#if templateTipsPopUpPage == 2}
        <p class="tipsPopHeader">Client Fills</p>

        <div class="modal-subheader">
          A “client” is the other party who will be filling and signing the form
          or document you send. A “client” may be an employee, vendor,
          contractor, etc.
        </div>
      {/if}

      {#if templateTipsPopUpPage == 3}
        <p class="tipsPopHeader">Fill After</p>

        <div class="modal-subheader">
          These are fields you’ll be prompted to fill and sign AFTER the client/
          other party has completed their parts.
        </div>
      {/if}

      <br />
      <label
        style="display: flex; justify-content: flex-start; align-items: center; font-family: sans-serif;
    font-size: 14px;"
      >
        <input
          type="checkbox"
          on:click={templateTipsPopUpHandleCheckbox}
          bind:checked={templateTipsPopUpCheckbox}
        />
        <span class="pl-2">Don't ask me this again</span>
      </label>
      <br />

      <div class="modal-buttons">
        <span
          on:click={() => {
            if ((templateTipsPopUpPage = !0)) {
              templateTipsPopUpPage = templateTipsPopUpPage - 1;
            }
          }}
        >
          <Button
            color="white"
            text="Previous Page"
            disabled={templateTipsPopUpPage == 0}
          />
        </span>

        {#if templateTipsPopUpPage != 3}
          <span
            on:click={() => {
              templateTipsPopUpPage = templateTipsPopUpPage + 1;
            }}
          >
            <Button
              color="primary"
              text="Next Page"
              disabled={templateTipsPopUpPage == 3}
            />
          </span>
        {:else}
          <span
            on:click={() => {
              templateTipsPopUp = false;
              showUploadModal = true;
              templateTipsPopUpPage = 1;
              if (templateTipsPopUpCheckbox) {
                localStorage.setItem("dontShowtemplateTipsPopUp", true);
              } else {
                localStorage.setItem("dontShowtemplateTipsPopUp", false);
              }
            }}
          >
            <Button color="primary" text="Proceed to Upload" />
          </span>
        {/if}
      </div>
    </Modal>
  {/if}
{/if}

{#if showUploadModal}
  <UploadFileModal
    multiple={false}
    requireIACwarning={true}
    specializedFor="newTemplate"
    allowNonIACFileTypes={requestorTemplateNonIACExtensions}
    on:done={processNewTemplate}
    on:close={() => {
      showUploadModal = false;
      $add_template_modal = false;
    }}
  />
{/if}

{#if showDeleteConfirmationDialog}
  <ConfirmationDialog
    question={`Are you sure you want to delete this template?`}
    yesText="Yes, Delete"
    noText="No, Keep it"
    yesColor="primary"
    noColor="gray"
    on:yes={() => {
      tryDeleteTemplate(toBeDel);
    }}
    on:close={() => {
      showDeleteConfirmationDialog = false;
      toBeDel = null;
    }}
  />
{/if}

{#if showArchiveConfirmationDialog}
  <ConfirmationDialog
    question={`Archiving a template will remove it from the Templates screen and make it unavailable to use in future checklists.
                It will remain in any existing checklists. To restore an archived template, contact your administrator. Archive template?`}
    yesText="Yes, Archive"
    noText="No, Keep it"
    yesColor="primary"
    noColor="gray"
    on:yes={() => {
      tryArchiveTemplate(templateToArchive);
    }}
    on:close={() => {
      showArchiveConfirmationDialog = false;
      templateToArchive = null;
    }}
  />
{/if}

{#if showSendTemplateRequestConfirmationDialog}
  <ConfirmationDialog
    title="Sending Single Request"
    question={`If you'd like to send additional requests with this template, use a checklist instead. The checklist will assume the document name.`}
    yesText="Send single request"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    checkBoxEnable={"enable"}
    checkBoxText={"Don't ask me this again"}
    on:yes={() => {
      onSendTemplate();
    }}
    on:close={() => {
      showSendTemplateRequestConfirmationDialog = false;
      templateRequestToSend = null;
    }}
    on:hide={(event) => {
      localStorage.setItem("dontshowTemplateSendRequestDialog", event?.detail);
      showSendTemplateRequestConfirmationDialog = false;
    }}
  />
{/if}

{#if showSelectRecipientModal}
  <ChooseRecipientModal
    on:selectionMade={processRecipientSelection}
    on:close={() => {
      showSelectRecipientModal = false;
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
      showReplaceUploadModal = true;
      showReplaceFileConfirmationBox = false;
    }}
    on:close={() => {
      showReplaceFileConfirmationBox = false;
    }}
  />
{/if}

{#if showReplaceUploadModal}
  <UploadFileModal
    multiple={false}
    uploadHeaderText={`Replace Template`}
    requireIACwarning={true}
    on:done={processReplacement}
    on:close={() => {
      showReplaceUploadModal = false;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .columnar {
    flex-direction: column !important;
  }
  .selectedBorder {
    border: 1px solid #76808b;
    border-radius: 5px;
  }
  * {
    box-sizing: border-box;
  }

  .reset-style {
    margin: 0;
    padding: 0;
  }

  .page-header {
    position: sticky;
    top: -2px;
    z-index: 11;
    background: #fcfdff;
    margin-top: -4px;
  }
  .mobile-only {
    display: none;
  }
  .template-icon {
    grid-area: a;
    width: 100%;
    font-size: 24px;
    color: #76808b;
  }
  .sortable {
    cursor: pointer;
    left: 0px;
    top: 2px;
    position: relative;
    color: #76808b;
  }

  /* Table */

  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    padding-top: 0.5rem;
    margin: 0 auto;
    position: relative;
  }

  .tr.th {
    display: none;
    position: sticky;
    top: 90px;
    height: 40px;
    z-index: 11;
    /* background:#ffffff; */
    background: #f8fafd;
  }

  .th > .td {
    align-items: center;
    white-space: normal;
    /* height: 37px; */
    /* background: #fcfdff; */
    background: #f8fafd;
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
  }

  .tr {
    width: 100%;
    display: grid;
    justify-items: center;
    align-items: center;
    grid-template-columns: 30px 1fr 1fr 80px;
    padding: 0.5rem;
    padding-left: 20px;
    row-gap: 0.3rem;
    grid-template-areas:
      "a a a d"
      ". b b b"
      ". c c c";
    cursor: pointer;
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

  .td.name {
    width: 90%;
    flex-grow: 2;
    justify-content: left;
    justify-self: start;
    grid-area: a;
  }

  .td.actions {
    display: flex;
    flex-grow: 1;
    /* justify-self: end; */
    align-items: center;
    grid-area: e;
    /* width: 75%; */
    justify-self: center;
    align-self: start;
  }
  .tr:not(.th) .td.actions {
    margin-right: 1rem;
  }
  .td.type {
    justify-self: left;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }
  .outer-border {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    margin-bottom: 1em;
  }

  .tmpl-namedesc {
    width: 100%;
    display: grid;
    grid-template-columns: 30px auto 1fr;
    grid-template-areas:
      "a b"
      "a c";
    align-items: center;
    word-break: break-word;
  }

  .tmpl-name {
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #171f46;
    grid-area: b;
  }

  .tmpl-description {
    display: flex;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  .tmpl-type {
    display: flex;
    font-weight: normal;
    font-style: normal;
    grid-area: c;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }
  .modal-buttons {
    display: flex;
    flex-flow: row nowrap;
    justify-content: space-between;
    width: 100%;
    align-items: center;
  }

  .tipsPopHeader {
    display: none;
    justify-content: flex-start;
    font-size: large;
    font-weight: bolder;
    color: #2a2f34;
  }

  .modal-subheader {
    color: #2a2f34;
    height: 90px;
  }

  .progress-tab {
    display: flex;
    flex-flow: column nowrap;
    justify-content: center;
  }

  .pl-2 {
    padding-left: 0.5rem;
  }

  /* media query */
  @media only screen and (min-width: 768px) {
    .table {
      padding-top: 0;
    }
    .tr {
      grid-template-columns: 3fr 1fr 1fr 1fr 1fr;
      align-items: center;
      grid-template-areas: "a b c d e ";
    }
    .tr.th {
      display: grid;
      grid-template-columns: 3fr 1fr 1fr 1fr 1fr;
    }
    .tr.th > .td {
      color: #76808b;
    }
    .td.actions {
      /* width: 100%; */
      align-self: center;
    }
    .td.actions.actions-header {
      justify-self: center;
      /* width: 35%; */
      display: grid;
    }
  }
  @media only screen and (max-width: 767px) {
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
    .loader-container {
      height: 70vh;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    .progress-tab {
      display: none;
    }
    .tipsPopHeader {
      display: flex;
    }
  }
</style>
