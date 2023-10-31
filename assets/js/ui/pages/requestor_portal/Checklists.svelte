<script>
  import QrCode from "svelte-qrcode";
  import ChecklistMobileView from "../../components/ChecklistHelpers/ChecklistMobileView.svelte";
  import Button from "../../atomic/Button.svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Dropdown from "../../components/Dropdown.svelte";
  import BackgroundPageHeader from "../../components/BackgroundPageHeader.svelte";
  import ChooseRecipientModal from "../../modals/ChooseRecipientModal.svelte";
  import ConfirmationDialog from "../../components/ConfirmationDialog.svelte";
  import { showErrorMessage } from "Helpers/Error";
  import { featureEnabled } from "Helpers/Features";
  import { convertTime } from "Helpers/util";
  import { onMount } from "svelte";
  import {
    getChecklists,
    deleteChecklist,
    duplicateChecklist,
    createIntakeLink,
    archiveChecklist,
  } from "BoilerplateAPI/Checklist";
  import Modal from "../../components/Modal.svelte";
  import RequestorHeaderNew from "../../components/RequestorHeaderNew.svelte";
  import EmptyDefault from "../../util/EmptyDefault.svelte";
  import Loader from "../../components/Loader.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import ChooseMultiRecipientModal from "../../modals/ChooseMultiRecipientModal.svelte";
  import Tag from "../../atomic/Tag.svelte";

  let search_value = "";
  let taskToBeViewed = null;
  let showTaskDetails = false;

  let chevron_state = {};
  let checklists = getChecklists().then((x) => {
    // default sort state to checklist name
    totalchecklistsCount = x?.length;
    checklistArray = x;
    return sortState(x, 1);
  });
  let checklistArray = [];

  let totalchecklistsCount = 0;

  let showSelectRecipientModal = false;
  let showMultiRecipientModal = false;
  let assignee = undefined;
  let popUpAfterDuplication = false;
  let duplicatedChecklist = "";
  let checklistId = undefined;
  let checklistNotFound = false;
  let isLoading = false;

  //single assign and bulk assign
  let assignActions = (cl) => {
    const options = [
      {
        text: "Single recipient",
        icon: "paper-plane",
        iconStyle: "solid",
        ret: 1,
      },
      {
        text: "Multiple recipients/ bulk send",
        icon: "users",
        iconStyle: "solid",
        ret: 2,
        blocked: cl.has_rspec,
        title:
          "Cannot bulk send checklists that contain personalized documents.",
      },
    ];
    if (cl.is_draft) {
      return options;
    }

    return options;
  };

  let checklistActions = (cl) => {
    const commonOptions = [
      {
        text: "Expand / Collapse",
        icon: "chevron-down",
        iconStyle: "solid",
        ret: 5,
      },
      {
        text: "Send",
        icon: "paper-plane",
        iconStyle: "solid",
        disabled: cl?.is_draft,
        ret: 7,
      },
      {
        text: "Edit",
        icon: "edit",
        iconStyle: "solid",
        disabled: !featureEnabled("requestor_allow_checklist_edit"),
        ret: 2,
      },
      {
        text: "Details",
        icon: "info-circle",
        iconStyle: "solid",
        disabled: !featureEnabled("requestor_allow_checklist_edit"),
        ret: 2,
      },
      {
        text: "Archive",
        icon: "archive",
        iconStyle: "solid",
        disabled: !featureEnabled("requestor_allow_checklist_edit"),
        ret: 6,
      },
      {
        text: "Delete",
        icon: "trash",
        disabled: !featureEnabled("requestor_allow_checklist_edit"),
        iconStyle: "solid",
        ret: 1,
      },
    ];

    if (cl.is_draft) {
      return commonOptions;
    }

    // check if the checklist has any contact specific document
    const hasContactSpecificTemplate = cl.documents.filter((docu) => {
      return docu.is_rspec;
    });

    const enableIntakeOption = !(
      hasContactSpecificTemplate.length > 0 ||
      (cl.enforce_due_date == true && cl.due_date_type === 1)
    );

    if (enableIntakeOption) {
      return [
        {
          text: "QR code/ shareable link",
          icon: "link",
          iconStyle: "solid",
          ret: 4,
        },
        {
          text: "Duplicate",
          disabled: !featureEnabled("requestor_allow_checklist_creation"),
          icon: "copy",
          iconStyle: "solid",
          ret: 3,
        },
        ...commonOptions,
      ];
    } else {
      return [
        {
          text: "QR code/ shareable link",
          icon: "link",
          iconStyle: "solid",
          showTooltip: true,
          blocked: !enableIntakeOption,
          tooltipMessage:
            "Checklists that contain personalized documents cannot be shared this way.",
          ret: 4,
        },
        {
          text: "Duplicate",
          disabled: !featureEnabled("requestor_allow_checklist_creation"),
          icon: "copy",
          iconStyle: "solid",
          ret: 3,
        },
        ...commonOptions,
      ];
    }
  };

  let fileRequestActions = [{ text: "Delete", ret: 3 }];

  let showIntakeModal = false;
  let newIntakeLink = "";
  let copyButtonText = "Copy Link";
  let copyButtonIcon = "";
  let linkTextCopied = false;

  let showConfirmationDialog = false;
  let checklistToBeDeleted = undefined;
  let ifConfirmed = undefined;
  async function tryDeleteChecklist(checklist, confirmed) {
    if (!confirmed) {
      showConfirmationDialog = true;
      checklistToBeDeleted = checklist;
      ifConfirmed = () => {
        tryDeleteChecklist(checklist, true);
      };
    } else {
      showConfirmationDialog = false;
      let reply = await deleteChecklist(checklist.id);
      if (reply.ok) {
        checklists = getChecklists();
        //checklistCount();
      } else {
        let error = await reply.json();
        showErrorMessage("checklist", error.error);
      }
    }
  }

  async function tryDuplicateChecklist(checklist) {
    let reply = await duplicateChecklist(checklist.id);
    if (reply.ok) {
      reply.json().then((response) => {
        duplicatedChecklist = response?.new_id;
      });
      checklists = getChecklists();
      //checklistCount();
      setTimeout(() => {
        popUpAfterDuplication = true;
      }, 1000);
    } else {
      let error = await reply.json();
      showErrorMessage("checklist", error.error);
    }
  }

  async function tryCreateIntakeLink(checklist) {
    let reply = await createIntakeLink(checklist.id);
    if (reply.ok) {
      let response = await reply.json();
      newIntakeLink = response.link;
      showIntakeModal = true;
      copyButtonText = "Copy Link";
      copyButtonIcon = "";
    } else {
      let error = await reply.json();
      showErrorMessage("checklist", error.error);
    }
  }

  let showArchiveChecklistConfirmationDialog = false;
  let ChecklistToArchive;

  async function tryArchiveChecklist(checklist) {
    let reply = await archiveChecklist(checklist.id);
    showArchiveChecklistConfirmationDialog = false;
    ChecklistToArchive = null;
    if (reply.ok) {
      showToast(`Success! Checklist Archived.`, 300, "default", "MM");
      /* reload the checklist list */
      checklists = getChecklists();
      //checklistCount();
    } else {
      showToast(`Error! unable to archive Checklist.`, 500, "error", "MM");
    }
  }

  const assignsDropdownClick = (checklist, actionId) => {
    if (actionId == 1) {
      beginAssign(checklist);
    } else if (actionId == 2) {
      showMultiRecipientModal = true;
      checklistId = checklist.id;
    } else {
      alert(`${checklist.name} -> ${actionId}`);
    }
  };

  function dropdownClick(checklist, actionId) {
    if (actionId == 2) {
      window.location.hash = `#checklist/${checklist.id}?userGuide=true`;
    } else if (actionId == 1) {
      tryDeleteChecklist(checklist, false);
    } else if (actionId == 3) {
      tryDuplicateChecklist(checklist);
    } else if (actionId == 4) {
      tryCreateIntakeLink(checklist);
    } else if (actionId == 5) {
      handleChevronClick(checklist);
    } else if (actionId == 6) {
      ChecklistToArchive = checklist;
      showArchiveChecklistConfirmationDialog = true;
    } else if (actionId == 7) {
      beginAssign(checklist);
    } else {
      alert(`${checklist.name} -> ${actionId}`);
    }
  }

  function handleChevronClick(cl) {
    chevron_state[cl.id] = !chevron_state[cl.id];
  }
  function disableScrolling() {
    window.document.body.style["overflow"] = "hidden";
  }

  function enableScrolling() {
    window.document.body.style["overflow"] = "auto";
  }

  function beginAssign(a) {
    assignee = a;
    showSelectRecipientModal = true;
    disableScrolling();
  }

  function processSelection(evt) {
    enableScrolling();
    let detail = evt.detail;
    window.location.hash = `#recipient/${detail.recipientId}/assign/${assignee.id}`;
  }

  function checklistContains(cl, sv) {
    if (cl.description.toLowerCase().includes(sv.toLowerCase())) return true;
    for (const fr of cl.file_requests) {
      if (fr.name.toLowerCase().includes(sv.toLowerCase())) return true;
    }
    for (const dr of cl.documents) {
      if (dr.name.toLowerCase().includes(sv.toLowerCase())) return true;
    }
    return false;
  }

  let sortType1 = 2; // Checklists
  let sortType2 = 1; // Created
  let sortType3 = 1; // Last Used
  let orgTemplates = null;
  function sortState(array, type) {
    console.log(array);
    let sortedArray;
    //TO:DO add Version and Used Support \/ Remove this after update
    if (type == 1) {
      switch (sortType1) {
        case 1 /* Switching to ABC */:
          sortType1 = 2;
          sortedArray = array.sort((b, a) => {
            const sortedData = a.name.localeCompare(b.name);
            if (sortedData === 0) {
              return a.description.localeCompare(b.description);
            }
            return sortedData;
          });
          break;
        case 2 /* Switching to ZXY */:
          sortType1 = 3;
          sortedArray = array.sort((a, b) => {
            const sortedData = a.name.localeCompare(b.name);
            if (sortedData === 0) {
              return a.description.localeCompare(b.description);
            }
            return sortedData;
          });
          break;
        case 3 /* Switching to Original Array */:
          sortType1 = 1;
          sortedArray = array.sort((a, b) => {
            const sortedData = a.name.localeCompare(b.name);
            if (sortedData === 0) {
              return a.description.localeCompare(b.description);
            }
            return sortedData;
          });
          break;
      }
    } else if (type == 2) {
      sortType1 = 1; // reset default
      switch (sortType2) {
        case 1 /* Switching to ABC */:
          sortType2 = 2;
          sortedArray = array.sort((a, b) =>
            a.inserted_at.localeCompare(b.inserted_at)
          );
          break;
        case 2 /* Switching to ZXY */:
          sortType2 = 3;
          sortedArray = array.sort((b, a) =>
            a.inserted_at.localeCompare(b.inserted_at)
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType2 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          console.log(sortedArray);
          break;
      }
    } else {
      switch (sortType3) {
        case 1 /* Switching to ABC */:
          sortType3 = 2;
          sortedArray = array.sort((a, b) =>
            a.updated_at.localeCompare(b.updated_at)
          );
          break;
        case 2 /* Switching to ZXY */:
          sortType3 = 3;
          sortedArray = array.sort((b, a) =>
            a.updated_at.localeCompare(b.updated_at)
          );
          break;
        case 3 /* Switching to Original Array */:
          sortType3 = 1;
          sortedArray = array.sort((a, b) => a.name.localeCompare(b.name));
          console.log(sortedArray);
          break;
      }
    }
    checklists = Promise.resolve(sortedArray);
  }
  let scrollY;

  $: {
    if (search_value) {
      console.log({ d: 1, search_value });
      let found = checklistArray?.some(
        (cl) =>
          cl?.name?.toLowerCase()?.includes(search_value?.toLowerCase()) ||
          checklistContains(cl, search_value)
      );
      found ? (checklistNotFound = false) : (checklistNotFound = true);
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
    contactCount={totalchecklistsCount}
    icon="clipboard-list"
    title="Reusable Checklists"
    headerBtn={featureEnabled("requestor_allow_checklist_creation")}
    btnText="Create New Checklist"
    btnAction={() => {
      window.location.hash = "#checklists/new?userGuide=true";
    }}
    bind:search_value
    searchPlaceholder="Search Checklists"
  />
</div>

<section class="checklist-main">
  <div class="checklist-table">
    {#await checklists || isLoading}
      <span class="loader-container">
        <Loader loading />
      </span>
    {:then cls}
      {#if cls.length}
        <div class="checklist-tr checklist-th">
          <div
            class="checklist-td"
            style="flex-basis: 0; flex-grow: 0; width: 24px;"
          />
          <div class="checklist-td" style="flex-grow: 2;">
            <div
              class="sortable {sortType1 === 2 || sortType1 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(cls, 1);
              }}
            >
              &nbsp; Checklist &nbsp;
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
          <div
            class="checklist-td version"
            style="position: relative; left: -18px;"
          >
            <div
              class="sortable {sortType2 === 2 || sortType2 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(cls, 2);
              }}
            >
              &nbsp; Created &nbsp;
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
          <div
            class="checklist-td last-used"
            style="position: relative; left: -18px;"
          >
            <div
              class="sortable {sortType3 === 2 || sortType3 === 3
                ? 'selectedBorder'
                : ''}"
              style="display: flex;
                  align-items: center;"
              on:click={() => {
                sortState(cls, 3);
              }}
            >
              &nbsp; Modified &nbsp;
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
          <div class="checklist-td actions actions-hd">Actions</div>
        </div>
        {#each cls as cl}
          {#if cl.name
            .toLowerCase()
            .includes(search_value.toLowerCase()) || checklistContains(cl, search_value)}
            <span class="outer-border desktop-only">
              <div
                class="checklist-tr"
                on:click={() => {
                  handleChevronClick(cl);
                }}
              >
                <div class="checklist-td chevron">
                  {#if chevron_state[cl.id]}
                    <div>
                      <FAIcon color={true} icon="minus" />
                    </div>
                  {:else}
                    <div>
                      <FAIcon color={true} icon="plus" />
                    </div>
                  {/if}
                </div>
                <div class="checklist-td clickable" style="flex-grow: 2;">
                  <div class="cl-namedesc">
                    <div class="cl-name">
                      {#if cl.is_draft}
                        <i class="cl-draft">DRAFT: </i>
                      {/if}
                      {cl.name}
                    </div>
                    {#if cl.description}
                      <div class="cl-description">{cl.description || "-"}</div>
                    {/if}
                    {#if cl.tags}
                      <ul class="reset-style">
                        {#each cl.tags as tag}
                          <Tag
                            isSmall={true}
                            tag={{ ...tag, selected: true }}
                            listTags={true}
                          />
                        {/each}
                      </ul>
                    {/if}
                  </div>
                </div>
                <div class="checklist-td version">
                  <span class="version-label">Created: &nbsp; </span>
                  <span style="white-space: nowrap"
                    >&nbsp;{cl.inserted_at}
                    <br />
                    &nbsp;{convertTime(cl.inserted_at, cl.inserted_time)}
                  </span>
                </div>
                <div class="checklist-td last-used">
                  <span class="last-used-label">Modified: </span>
                  <span
                    >{cl.updated_at}
                    <br />
                    &nbsp;{convertTime(cl.updated_at, cl.updated_time)}
                  </span>
                </div>
                <div class="checklist-td actions with-ellipsis">
                  {#if cl.is_draft}
                    <span
                      on:click|stopPropagation={() => {
                        dropdownClick(cl, 2);
                      }}
                    >
                      <Button text="Continue" />
                    </span>
                  {:else}
                    <Dropdown
                      elements={assignActions(cl)}
                      clickHandler={(ret) => {
                        assignsDropdownClick(cl, ret);
                      }}
                      text="Send"
                      triggerType="button"
                    />
                  {/if}
                  <Dropdown
                    elements={checklistActions(cl)}
                    clickHandler={(ret) => {
                      dropdownClick(cl, ret);
                    }}
                    triggerType="vellipsis"
                  />
                </div>
              </div>
              {#if chevron_state[cl.id]}
                {#each cl.file_requests as filereq}
                  <div
                    class=" checklist-tr child outer-border"
                    on:click={() => {
                      taskToBeViewed = filereq;
                      showTaskDetails = true;
                    }}
                  >
                    <div class="checklist-td chevron">
                      <span class="bar" />
                    </div>
                    <div class="checklist-td clickable" style="flex-grow: 2;">
                      <div class="filerequest checklist-icon">
                        <span>
                          {#if filereq.type == "file"}
                            <FAIcon
                              icon="paperclip"
                              iconStyle="regular"
                              iconSize="small"
                            />
                          {:else if filereq.type == "data"}
                            <span style="margin-left: -0.5rem;">
                              <FAIcon
                                icon="font-case"
                                iconStyle="regular"
                                iconSize="small"
                              />
                            </span>
                          {:else if filereq.type == "task"}
                            <FAIcon
                              icon="thumbtack"
                              iconStyle="regular"
                              iconSize="small"
                            />
                          {/if}
                        </span>
                        <div class="filerequest-name">
                          <span class="truncate">{filereq.name}</span>
                          {#if filereq.type == "file"}
                            <div class="truncate">
                              {filereq.description || "-"}
                            </div>
                          {:else if filereq.type == "data"}
                            <div class="truncate">
                              {filereq.description || "-"}
                            </div>
                          {:else if filereq.type == "task"}
                            <div class="truncate">
                              {filereq.description || "-"}
                            </div>
                            {#if filereq.link && Object.keys(filereq.link).length !== 0 && filereq.link.url != ""}
                              <div>
                                <a
                                  style="width: 250px;
                                        display: block;
                                        white-space: nowrap;
                                        text-overflow: ellipsis;
                                        overflow: hidden;"
                                  target="_blank"
                                  href={filereq.link.url}
                                >
                                  {filereq.link.url}
                                </a>
                              </div>
                            {/if}
                          {/if}
                        </div>
                      </div>
                    </div>
                    <div class="checklist-td version">
                      <span class="version-label">Created: &nbsp; </span>
                      <span>{filereq.inserted_at}</span>
                    </div>
                    <!-- <div class="checklist-td last-used">
                        <span class="last-used-label">Last Updated : </span>
                        <span>N/A</span>
                      </div> -->
                    <div class="checklist-td actions">
                      <div class="checklist-td">
                        <!-- <Button color="white" text="View Details" /> -->
                        <!-- <Dropdown elements={fileRequestActions} text="" clickHandler={(ret) => { dropdownClick(cl, ret)}} chevron={false} /> -->
                      </div>
                    </div>
                  </div>
                {/each}
                {#each cl.documents as doc}
                  <a href={`#view/template/${doc.id}?filePreview=true`}>
                    <div class="checklist-tr child outer-border">
                      <div class="checklist-td chevron">
                        <!-- <span class='bar'>&#124;</span> -->
                        <span class="bar" />
                      </div>
                      <div
                        class="checklist-td clickable"
                        style="flex-grow: 2; flex-direction: column"
                      >
                        <div class="filerequest ">
                          {#if doc.is_rspec}
                            <span
                              ><FAIcon
                                iconStyle="solid"
                                icon="file-user"
                              /></span
                            >
                          {:else if doc.is_info}
                            <span
                              ><FAIcon
                                iconStyle="regular"
                                icon="info-square"
                              /></span
                            >
                          {:else}
                            <span
                              ><FAIcon
                                iconStyle="regular"
                                icon="file-alt"
                              /></span
                            >
                          {/if}
                          <div class="filerequest-name">
                            <span class="truncate">{doc.name}</span>
                            <span class="truncate"
                              >{doc.description || "-"}</span
                            >
                          </div>
                        </div>
                        {#if doc.tags}
                          <div>
                            <ul class="reset-style">
                              {#each doc.tags.values as tag}
                                <Tag
                                  tag={{ ...tag, selected: true }}
                                  color="#2a2f34"
                                  listTags={true}
                                />
                              {/each}
                            </ul>
                          </div>
                        {/if}
                      </div>
                      <div class="checklist-td version">
                        <span class="version-label">Created: &nbsp; </span>
                        <span style="white-space: nowrap"
                          >&nbsp;{doc.inserted_at}</span
                        >
                      </div>
                      <!-- <div class="checklist-td last-used ">
                        <span class="last-used-label">Last Updated : </span>
                        <span>{doc.updated_at}</span>
                      </div> -->
                      <div class="checklist-td actions with-ellipsis">
                        <div class="checklist-td ">
                          <!-- <a href={`#template/${doc.id}`}> -->
                          <a href={`#view/template/${doc.id}?filePreview=true`}>
                            <span class="btn">
                              <Button color="white" text="View" />
                            </span>
                          </a>
                          <!-- <Dropdown elements={fileRequestActions} clickHandler={(ret) => { dropdownClick(cl, ret)}} triggerType="vellipsis" /> -->
                        </div>
                      </div>
                    </div>
                  </a>
                {/each}

                {#each cl.forms as form}
                  <div class="checklist-tr child outer-border">
                    <div class="checklist-td chevron">
                      <!-- <span class='bar'>&#124;</span> -->
                      <span class="bar" />
                    </div>
                    <div class="checklist-td clickable" style="flex-grow: 2;">
                      <div class="filerequest ">
                        <span style="margin-left: -0.5rem;">
                          <FAIcon iconStyle="regular" icon="rectangle-list" />
                        </span>
                        <div class="filerequest-name">
                          <span class="truncate">{form.title}</span>
                          <span class="truncate">{form.description || "-"}</span
                          >
                        </div>
                      </div>
                    </div>
                    <div class="checklist-td version">
                      <span class="version-label">Created: &nbsp; </span>
                      <span style="white-space: nowrap"
                        >&nbsp;{cl.inserted_at}</span
                      >
                    </div>
                    <!-- <div class="checklist-td last-used ">
                    <span class="last-used-label">Last Updated : </span>
                    <span>{doc.updated_at}</span>
                  </div> -->
                    <div class="checklist-td actions with-ellipsis">
                      <div class="checklist-td ">
                        <!-- <a href={`#template/${doc.id}`}> -->

                        <a href={`#preview/form/${cl.id}/${form.id}`}>
                          <span class="btn">
                            <Button color="white" text="View" />
                          </span>
                        </a>
                        <!-- <Dropdown elements={fileRequestActions} clickHandler={(ret) => { dropdownClick(cl, ret)}} triggerType="vellipsis" /> -->
                      </div>
                    </div>
                  </div>
                {/each}

                {#if !cl.documents.length && !cl.file_requests.length && !cl.forms.length}
                  <p class="no-request-text">
                    <FAIcon icon="alert" />
                    No documents or file requests attached to this checklist
                  </p>
                {/if}
              {/if}
            </span>

            <span class="mobile-only">
              <ChecklistMobileView
                data={cl}
                {convertTime}
                {checklistActions}
                {dropdownClick}
                {beginAssign}
                on:file_item_click={({ detail: item }) => {
                  taskToBeViewed = item;
                  showTaskDetails = true;
                }}
              />
            </span>
          {/if}
        {/each}
      {:else}
        <EmptyDefault
          defaultHeader="No checklists found!"
          defaultMessage="You have not created any checklists, start now by hitting Create New Checklist"
        />
      {/if}

      {#if checklistNotFound}
        <EmptyDefault
          cancelButton={true}
          defaultHeader="No Search results!"
          defaultMessage="No results for this search on this screen"
          on:close={() => {
            search_value = "";
          }}
        />
      {/if}
    {:catch error}
      <EmptyDefault
        defaultHeader="Oh uh, something went wrong!"
        defaultMessage="Try refreshing the page through your browser navigation bar above. If that doesn’t work, please contact support@boilerplate.co thank you!"
        error
      />
    {/await}
  </div>
</section>

<!-- Single Assign -->
{#if showSelectRecipientModal}
  <ChooseRecipientModal
    on:selectionMade={processSelection}
    on:close={() => {
      showSelectRecipientModal = false;
      enableScrolling();
    }}
  />
{/if}

<!-- Bulk Assign -->
{#if showMultiRecipientModal}
  <ChooseMultiRecipientModal
    on:close={() => {
      showMultiRecipientModal = false;
    }}
    {checklistId}
  />
{/if}

{#if showConfirmationDialog}
  <ConfirmationDialog
    question={`Are you sure you want to delete the checklist named "${checklistToBeDeleted.name}"?`}
    yesText="Yes, delete"
    noText="No, keep it"
    yesColor="primary"
    noColor="gray"
    on:yes={ifConfirmed}
    on:close={() => {
      showConfirmationDialog = false;
    }}
  />
{/if}

{#if popUpAfterDuplication}
  <ConfirmationDialog
    question={`Checklist duplicated. Would you like to edit the new checklist now?`}
    yesText="Yes, edit"
    noText="No, thanks"
    yesColor="primary"
    noColor="gray"
    on:yes={() => {
      if (duplicatedChecklist != "") {
        window.location.hash = `#checklist/${duplicatedChecklist}?userGuide=true`;
      }
    }}
    on:close={() => {
      popUpAfterDuplication = false;
    }}
  />
{/if}

{#if showIntakeModal}
  <Modal
    on:close={() => {
      showIntakeModal = false;
    }}
  >
    <div slot="header">QR code/ shareable link created</div>

    <div style="display: flex; flex-direction: column;" class="intake-text">
      <span style="font-weight: 900;">To share:</span>
      <br />
      <span>
        <span style="font-weight: 900;">QR code : </span>Download by
        right-clicking the QR code on desktop, or long-pressing on mobile.
        Display the QR in a scannable location.
      </span>
      <br />
      <span>
        <span style="font-weight: 900;">Link : </span>Copy to your clipboard and
        then post on your website, social media, in an email (no tracking), etc.
      </span>
      <br />
      <span>
        Anyone who scans the QR code or clicks the link will be able to submit.
        You will be notified of any submissions.
      </span>
    </div>

    <br />

    <div class="intake-qr-code">
      <QrCode value={newIntakeLink} />
    </div>

    <div class="intake-link">
      <p>{newIntakeLink}</p>
    </div>
    <div
      class="intake-link-copy"
      on:click={async () => {
        linkTextCopied = true;
        copyButtonText = "Copied";
        copyButtonIcon = "check-circle";
        await navigator.clipboard.writeText(newIntakeLink);
        showToast(`Link copied to clipboard.`, 1000, "white", "MM");
      }}
      data-text-copy="Click to Copy"
      on:mouseleave={() => {
        linkTextCopied = false;
      }}
    >
      <FAIcon icon="copy" />&nbsp;&nbsp;Copy link
    </div>
    <!-- <span
      class="intake-link"
      on:click={async () => {
        copyButtonText = "Copied";
        copyButtonIcon = "check-circle";
        await navigator.clipboard.writeText(newIntakeLink);
      }}
    >
      <Button text={copyButtonText} icon={copyButtonIcon} iconStyle="solid" />
    </span> -->
  </Modal>
{/if}

{#if showTaskDetails}
  <ConfirmationDialog
    title="Task Details"
    itemDisplay={taskToBeViewed}
    popUp={true}
    on:close={() => {
      showTaskDetails = false;
      taskToBeViewed = null;
    }}
  />
{/if}

{#if showArchiveChecklistConfirmationDialog}
  <ConfirmationDialog
    question={`Archiving a checklist will remove it from the Checklists screen and make it unavailable for future use.
                  Any open or submitted versions of this checklist will remain available. To restore an archived checklist, contact your administrator. Archive checklist?`}
    yesText="Yes, Archive"
    noText="No, Cancel"
    yesColor="primary"
    noColor="gray"
    on:yes={() => {
      console.log(ChecklistToArchive);
      tryArchiveChecklist(ChecklistToArchive);
    }}
    on:close={() => {
      showArchiveChecklistConfirmationDialog = false;
      ChecklistToArchive = null;
    }}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  /* .checklist-td.last-used,
  .checklist-td.version {
    display: none;
  } */
  .selectedBorder {
    border: 1px solid #76808b;
    border-radius: 5px;
  }
  a {
    text-decoration: none;
  }

  * {
    box-sizing: border-box;
    /* outline: 1px solid #f00 !important; */
  }

  .reset-style {
    margin: 0;
    padding: 0;
  }

  .page-header {
    position: sticky;
    top: 0px;
    z-index: 11;
    background: #fcfdff;
    margin-top: -4px;
  }

  /* contents */
  .checklist-table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    margin: 1rem auto;
    padding-top: 0.5rem;
    /* margin-right: 4rem; */
  }

  .checklist-tr.checklist-th {
    display: none;
    /* border-top: 0.5px solid #b3c1d0; */
  }

  .checklist-th > .checklist-td {
    white-space: normal;
    justify-content: left;
    /* background: #fcfdff; */
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    align-self: center;
    height: 37px;
    align-items: center;
  }
  .checklist-th .checklist-td {
    color: #76808b;
  }
  .checklist-tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    position: relative;
  }

  .checklist-tr:not(.checklist-th) {
    /* height: 60px; */
    display: grid;
    row-gap: 0.3rem;
    grid-template-columns: 20px 1fr 1fr;

    grid-template-areas:
      "a b b"
      ". c c"
      ". d d"
      ". e e";
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #2a2f34;
    padding: 0.5rem;
    position: relative;
  }
  .checklist-tr:not(.checklist-th) .chevron {
    grid-area: a;
    justify-self: center;
    height: 100%;

    /* text-align: center; */
  }

  .checklist-tr:not(.checklist-th) .clickable {
    grid-area: b;
  }
  .checklist-tr:not(.checklist-th) .version {
    grid-area: c;
  }
  .checklist-tr:not(.checklist-th) .last-used {
    grid-area: d;
  }
  .checklist-tr:not(.checklist-th) .actions {
    grid-area: e;
    justify-self: center;
    /* width: 100%; */
  }
  .checklist-tr:not(.checklist-th) .actions span {
    width: 75%;
    /* margin-right: 1rem; */
  }

  .outer-border {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;

    margin-bottom: 1em;
  }

  .checklist-td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
    color: #7e858e;
  }

  .chevron div {
    display: flex;
    align-items: center;
    color: #000;
  }

  .cl-namedesc {
    display: flex;
    flex-flow: column nowrap;
    word-break: break-word;
  }

  .cl-name {
    display: flex;
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #171f46;
  }

  .cl-description {
    display: flex;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 24px;
    color: #76808b;
  }

  .filerequest {
    width: 95%;
    display: flex;
    flex-flow: row nowrap;
  }

  .filerequest:nth-child(1) {
    font-size: 24px;
    align-items: center;
    color: #606972;
  }

  .filerequest-name {
    width: 95%;
    display: flex;
    flex-flow: column nowrap;
    padding-left: 0.5rem;
  }

  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .filerequest-name > *:nth-child(1) {
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 24px;
    letter-spacing: 0.15px;
    color: #2a2f34;
  }

  .filerequest-name > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }

  .filerequest-name > *:nth-child(3) {
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;
  }

  .checklist-td.actions {
    flex-grow: 1;
    justify-content: center;
    align-items: center;
    /* padding-right: 2rem; */
    padding-right: 0.5rem;
  }

  .with-ellipsis {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .intake-text {
    padding-top: 1rem;
  }

  .intake-qr-code {
    display: flex;
    flex-direction: column;
    align-items: center;
  }

  .intake-link {
    padding-top: 2rem;
    display: flex;
    flex-flow: row nowrap;

    justify-content: center;
  }

  .intake-link-copy {
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: copy;
    width: 30%;
    margin: 0 auto;
    padding: 5px;
    position: relative;
    border-radius: 5px;
  }

  .intake-link-copy:hover::before {
    content: attr(data-text-copy);
    position: absolute;
    background-color: red;
    top: -126%;
    width: 80px;
    text-align: center;
    background: white;
    box-shadow: 0px 3px 20px rgba(46, 56, 77, 0.22);
    padding: 3px;
    font-size: 10px;
  }

  .intake-link-copy:focus,
  .intake-link-copy:hover {
    box-shadow: 0px 3px 20px 7px rgba(46, 56, 77, 0.22);
  }

  .cl-draft {
    padding-right: 0.2rem;
    font-weight: 600;
  }

  .sortable {
    cursor: pointer;
    left: 6px;
    top: 2px;
    position: relative;
    color: #76808b;
  }

  .clickable {
    cursor: pointer;
  }
  .checklist-tr .btn {
    display: none;
  }
  .checklist-tr.child {
    width: 90%;
    margin: 0.5rem auto;
    padding: 0.5rem;
  }

  @media only screen and (min-width: 320px) {
    .checklist-tr:not(.checklist-th) {
      grid-template-areas:
        "a b b"
        ". c d"
        ". e e";
    }
  }
  @media only screen and (min-width: 480px) {
    .checklist-table {
      margin: 0 auto;
    }
  }

  @media only screen and (min-width: 640px) {
    .checklist-tr:not(.checklist-th) .actions span {
      width: 50%;
    }
  }

  @media only screen and (min-width: 768px) {
    .checklist-tr:not(.checklist-th) {
      row-gap: 0.5rem;
      grid-template-columns: 37px 2.5fr 0.75fr 0.75fr 0.75fr;
      grid-template-areas: "a b c d e ";
      /* padding: 1rem; */
    }
    .version-label,
    .last-used-label {
      display: none;
    }
    .checklist-tr:not(.checklist-th) .actions span {
      width: 100%;
    }
    .checklist-tr.checklist-th {
      display: grid;
      grid-template-columns: 57px 2.5fr 0.75fr 0.75fr 0.75fr;
      justify-items: start;
      position: sticky;
      top: 90px;
      height: 40px;
      z-index: 11;
      background: #f8fafd;
    }
    .checklist-tr .last-used,
    .checklist-tr .version,
    .checklist-tr .actions {
      justify-self: center;
    }
    .checklist-tr:not(.checklist-th) .actions {
      padding: 0.5rem;
    }
    .checklist-tr.child:not(.checklist-th) .with-ellipsis a {
      width: 100%;
    }
    .checklist-tr .btn {
      display: flex;
    }
    .checklist-tr.child {
      width: 99%;
      margin-top: 0;
    }

    .checklist-tr.child:not(.checklist-th) .actions {
      padding-right: 1rem;
    }
    .checklist-table {
      padding-top: 0;
    }
  }

  .no-request-text {
    margin-left: 27px;
    color: #444;
  }
  .mobile-only {
    display: none;
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
  }
</style>
