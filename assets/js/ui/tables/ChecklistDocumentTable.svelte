<script>
  import Button from "../atomic/Button.svelte";
  import Dropdown from "../components/Dropdown.svelte";
  import SendChecklistTemplateView from "../components/ChecklistHelpers/SendChecklistTemplateView.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { getRSDsIACPrefilled } from "BoilerplateAPI/IAC";
  import { createEventDispatcher } from "svelte";
  import Panel from "./../components/Panel.svelte";

  let dispatch = createEventDispatcher();

  export let documents;
  export let customizations;
  export let recpt_assign_view = true;
  export let contentsId = 0;
  export let recipientId = 0;

  let prefilled = [];
  let IACPreFillButtonDisabled = false;
  let IACSetupButtonDisabled = false;

  let dropdownElements = (doc) => {
    return [
      {
        text: "Setup",
        ret: 3,
        icon: "file-edit",
        disabled:
          prefilled.includes(doc.id) ||
          (doc.id in customizations && !customizations[doc.id].is_iac),
      },
      {
        text: "Replace",
        ret: 1,
        icon: "exchange-alt",
      },
      { text: "Revert", ret: 2, icon: "undo-alt" },
    ];
  };

  if (recpt_assign_view) {
    getRSDsIACPrefilled(contentsId, recipientId)
      .then((x) => x.json())
      .then((x) => {
        console.log("prefilled:" + x);
        prefilled = x;
      });
  }

  function documentAlreadyCustomized(doc) {
    if (doc.is_rspec == false) return true;

    return doc.id in customizations;
  }

  function doIacSetupFor(doc) {
    let customization = customizations[doc.id];
    window.location.hash = `#iac/setup/rsd/${customization.customization_id}?ro=1`;
  }

  function doIacFillFor(doc) {
    let customization = customizations[doc.id];
    window.location.hash = `#iac/fill/${customization.iac_doc_id}/${contentsId}/${recipientId}`;
  }

  function doIacFillForBase(doc) {
    window.location.hash = `#iac/fill/${doc.iac_doc_id}/${contentsId}/${recipientId}`;
  }

  function dropdownClickHandler(doc, ret) {
    if (ret == 3) {
      doIacSetupFor(doc);
    }

    if (ret == 1) {
      // replace
      dispatch("customizeTemplate", {
        templateId: doc.id,
      });
    }

    if (ret == 2) {
      dispatch("revertTemplate", {
        templateId: doc.id,
      });
    }
  }
</script>

<div class="documents">
  <div class="tr th desktop-only">
    <div class="td icon" />
    <div class="td name">Template Name</div>
    <div class="td type">Type</div>
    <div class="td date">Date Created</div>
    <div class="td actions">Actions</div>
  </div>
  {#each documents as doc}
    <span class="desktop-only">
      <div
        class="tr"
        class:rspec={recpt_assign_view &&
          doc.is_rspec &&
          doc.type === 0 &&
          !(doc.id in customizations) &&
          !prefilled.includes(doc.id)}
      >
        <div class="td icon">
          <div>
            {#if doc.is_rspec}
              <div>
                <FAIcon icon="file-user" iconStyle="solid" />
              </div>
            {:else if doc.is_info}
              <div>
                <FAIcon iconStyle="regular" icon="info-square" />
              </div>
            {:else}
              <div>
                <FAIcon icon="file-alt" iconStyle="regular" />
              </div>
            {/if}
          </div>
        </div>
        <div class="td name">
          <div class="name-container">
            <div class="truncate">{doc.name}</div>
            <div class="truncate">{doc.description ?? ""}</div>
          </div>
        </div>
        <div class="td type">
          {#if doc.is_rspec}
            {#if recpt_assign_view && prefilled.includes(doc.id)}
              <p>Placeholder - pre-filled</p>
            {:else if recpt_assign_view && documentAlreadyCustomized(doc)}
              <p>Placeholder - already customized</p>
            {:else}
              <p>Contact-Specific PDF</p>
            {/if}
          {:else if doc.is_info}
            <p>Informational Only - send as is</p>
          {:else}
            <p>Generic PDF - send as is</p>
          {/if}
        </div>
        <div class="td date">
          {doc.inserted_at}
        </div>
        <div class="td actions">
          {#if recpt_assign_view && doc.is_rspec && doc.type === 0}
            {#if documentAlreadyCustomized(doc)}
              {#if customizations[doc.id].is_iac}
                <div>
                  <span
                    on:click={() => {
                      doIacFillFor(doc);
                    }}
                  >
                    <Button color="white" text="Pre-Filled" />
                  </span>
                </div>
              {:else}
                <div>
                  <span
                    on:click={() => {
                      doIacSetupFor(doc);
                      IACSetupButtonDisabled = true;
                    }}
                  >
                    <Button
                      color="secondary"
                      text="Setup"
                      disabled={IACSetupButtonDisabled}
                    />
                  </span>
                </div>
              {/if}
              <div>
                <Dropdown
                  triggerType="vellipsis"
                  clickHandler={(r) => {
                    dropdownClickHandler(doc, r);
                  }}
                  elements={dropdownElements(doc)}
                />
              </div>
            {:else}
              <div class="button-group">
                {#if doc.is_iac}
                  <div>
                    <span
                      on:click={() => {
                        doIacFillForBase(doc);
                        IACPreFillButtonDisabled = true;
                      }}
                    >
                      <Button
                        color="primary"
                        text="Prefill online"
                        disabled={IACPreFillButtonDisabled}
                      />
                    </span>
                  </div>
                {/if}
                <div>
                  <span
                    on:click={() => {
                      dispatch("customizeTemplate", {
                        templateId: doc.id,
                      });
                    }}
                  >
                    <Button color="secondary" text="Swap In/ Import" />
                  </span>
                </div>
              </div>
            {/if}
          {:else}
            <div
              on:click={() => {
                window.open(
                  `#view/template/${doc.id}?filePreview=true?newTab=true`,
                  "_blank"
                );
              }}
            >
              <Button color="white" text="View" />
            </div>
          {/if}

          <div
            on:click={() => {
              dispatch("deleteTemplate", {
                templateId: doc.id,
                item: doc,
              });
            }}
            class="deleter"
          >
            <div>
              <FAIcon iconStyle="regular" icon="times-circle" />
            </div>
          </div>
        </div>
      </div>
    </span>

    <span class="mobile-only">
      <SendChecklistTemplateView
        data={doc}
        {prefilled}
        {documentAlreadyCustomized}
        {doIacFillForBase}
        {customizations}
        {doIacFillFor}
        {doIacSetupFor}
        {dropdownClickHandler}
        {dropdownElements}
        {recpt_assign_view}
        on:deleteTemplate
        isResp={recpt_assign_view &&
          doc.is_rspec &&
          doc.type === 0 &&
          !(doc.id in customizations) &&
          !prefilled.includes(doc.id)}
      />
    </span>
  {/each}
</div>

<style>
  .truncate {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .documents {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    justify-content: left;
    align-items: center;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #606972;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .button-group {
    display: flex;
    flex-direction: column;
    justify-content: center;
  }

  .button-group > * {
    margin-bottom: 10px;
  }
  .button-group > *:last-child {
    margin-bottom: 0;
  }

  .tr.rspec {
    background: #f9ecec;
  }

  .td.name {
    flex: 2 1 0;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
    align-items: center;
    padding-right: 5px;
  }

  .td.icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    width: 48px;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: center;
  }
  .type > * {
    font-size: 14px;
    line-height: 16px;
  }

  .name-container {
    width: 100%;
    display: flex;
    flex-flow: column nowrap;
    justify-content: space-around;
  }

  .name-container > *:nth-child(1) {
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #2a2f34;
  }

  .name-container > *:nth-child(2) {
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #7e858e;
  }

  .mobile-only {
    display: none;
  }

  .deleter {
    cursor: pointer;
    display: flex;
    color: #76808b;
    font-size: 24px;
    margin-left: 0.5rem;
  }

  .deleter:hover {
    color: hsl(0, 95%, 77%);
  }

  .actions {
    display: flex;
    justify-content: center !important;
  }

  @media only screen and (max-width: 767px) {
    .mobile-only {
      display: block;
    }
    .desktop-only {
      display: none;
    }

    .name-container {
      padding-right: 0.5rem;
    }

    .tr {
      padding: 0.5rem !important;
      margin-bottom: 0.5rem !important;
    }
    .type p {
      margin-top: 0.5rem;
      margin-bottom: 0.5rem;
    }
  }
</style>
