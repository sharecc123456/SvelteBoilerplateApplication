<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import Dropdown from "../Dropdown.svelte";
  export let data,
    prefilled = [],
    doIacFillForBase,
    customizations,
    doIacSetupFor,
    doIacFillFor,
    dropdownElements,
    dropdownClickHandler,
    isResp,
    recpt_assign_view,
    documentAlreadyCustomized;

  const dispatch = createEventDispatcher();

  let IACPreFillButtonDisabled = false;
  let IACSetupButtonDisabled = false;

  const style = `
    width: auto;
    border-radius: .375em;
    padding: 0.5rem 0.5rem 0.1rem;
    background: ${isResp ? "#f9ecec" : "##ffffff;"};
  `;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    collapsed: true,
    disableCollapse: true,
    has_z_index: false,
  };
</script>

<Panel {style} {...panelProps} headerClasses="cursor-pointer">
  <div slot="custom-title">
    <div class="panel-title">
      <div class="status">
        {#if data.is_rspec}
          <FAIcon icon="file-user" iconStyle="solid" iconSize="2x" />
        {:else if data.is_info}
          <FAIcon icon="info-square" iconStyle="solid" iconSize="2x" />
        {:else}
          <FAIcon icon="file-alt" iconStyle="regular" iconSize="2x" />
        {/if}
      </div>
      <div class="panel-text">
        <span class="title-text">{data?.name}</span>
        <span class="subtitle-text flex-column">
          {#if data.is_rspec}
            {#if recpt_assign_view && prefilled.includes(data.id)}
              Placeholder - pre-filled
            {:else if recpt_assign_view && documentAlreadyCustomized(data)}
              Placeholder - already customized
            {:else}
              Contact-Specific PDF
            {/if}
          {:else if data.is_info}
            Informational Only - send as is
          {:else}
            Generic PDF - send as is
          {/if}
        </span>
      </div>
    </div>
  </div>

  <div slot="custom-toolbar">
    {#if recpt_assign_view && data.is_rspec}
      {#if documentAlreadyCustomized(data)}
        <div class="custom-toolbar">
          <div class="right">
            <Dropdown
              elements={dropdownElements(data)}
              clickHandler={(ret) => {
                dropdownClickHandler(data, ret);
              }}
              triggerType="vellipsis"
            />
          </div>
        </div>
      {/if}
    {/if}
  </div>

  <div slot="sub-header">
    <div class="sub-header-wrapper">
      <div class="w-full">
        {#if recpt_assign_view && data.is_rspec && data.type === 0}
          {#if documentAlreadyCustomized(data)}
            {#if customizations[data.id].is_iac}
              <span
                class="content"
                on:click={() => {
                  doIacFillFor(data);
                }}
              >
                <Button color="white" text="Pre-Filled" />
              </span>
            {:else}
              <span
                class="content"
                on:click={() => {
                  doIacSetupFor(data);
                  IACSetupButtonDisabled = true;
                }}
              >
                <Button
                  color="secondary"
                  text="Setup"
                  disabled={IACSetupButtonDisabled}
                />
              </span>
            {/if}
          {:else}
            <div class="content gap-2">
              {#if data.is_iac}
                <span
                  on:click={() => {
                    doIacFillForBase(data);
                    IACPreFillButtonDisabled = true;
                  }}
                  class="w-full"
                >
                  <Button
                    color="primary"
                    text="Prefill online"
                    disabled={IACPreFillButtonDisabled}
                  />
                </span>
              {/if}
              <span
                on:click={() => {
                  dispatch("customizeTemplate", {
                    templateId: data.id,
                  });
                }}
                class="w-full"
              >
                <Button color="secondary" text="Swap In/ Import" />
              </span>
            </div>
          {/if}
        {:else}
          <a class="content" href={`/rawdocument/${data.id}/download`}>
            <Button color="white" text="View" />
          </a>
        {/if}
      </div>
      <div
        on:click={() => {
          dispatch("deleteTemplate", {
            templateId: data.id,
            item: data,
          });
        }}
        class="icon"
      >
        <div>
          <FAIcon iconStyle="regular" icon="times-circle" />
        </div>
      </div>
    </div>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
  }
  .sub-header-wrapper {
    display: flex;
  }
  .w-full {
    width: 100%;
  }
  .gap-2 {
    gap: 0.5rem;
  }
  .panel-text {
    flex-direction: column;
  }
  .title-text {
    color: black;
    font-size: 1rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
  }
  .subtitle-text {
    font-size: 0.8rem;
    font-weight: 400;
    font-family: "Nunito", sans-serif;
  }
  .flex-column {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }

  .content {
    display: flex;
    margin: 0.5rem 0 0.25rem 0;
    text-decoration: none;
    width: 100%;
  }

  .status {
    width: 50px;
    color: #76808b;
  }
  .icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    width: 48px;
    color: #76808b;
    font-size: 24px;
    align-items: flex-end;
    text-align: center;
    justify-content: center;
  }
</style>
