<script>
  import { start_search, dashboard_filter_modal } from "./../../store";
  import DashboardFilterModal from "./../modals/DashboardFilterModal.svelte";
  import { onMount } from "svelte";
  import Panel from "./Panel.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import SearchIcon from "../atomic/SearchIcon.svelte";
  import SearchBar from "./SearchBar.svelte";
  import Button from "../atomic/Button.svelte";
  import { loadDashboardMetadata } from "BoilerplateAPI/Recipient";

  export let title = "",
    icon,
    search_value,
    enable_search_bar = true,
    searchPlaceholder;
  export let headerBtn,
    showMobileActionBtn,
    btnAction,
    btnText,
    useDropdown, // use a dropdown instead of a button
    dropdownClickHandler, // function to handle dropdown clicks
    btnDisabled = false,
    bulkSendBtnIcon,
    btnIcon,
    bulkSendBtn,
    bulkSendBtnAction,
    sendAssignsBtnAction,
    sendAssignsBtnDisabled = false,
    showSendAssignsBtn,
    client_portal = false,
    client_new_ui = false;
  export let title_classes = "title-margin-top",
    classes = "",
    has_mobile_page_header = false;
  export let showCsvUploadBtn = false,
    uploadBtnText,
    uploadBtnAction,
    uploadBtnDisabled,
    uploadBtnIcon;
  export let showExportCSVBtn = false,
    ExportCSVBtnText,
    ExportCSVBtnAction,
    ExportCSVBtnDisabled,
    ExportCSVBtnIcon;

  export let contactCount; // rename this variable to more generic name as contentscount
  export let loadAssignment = false; // disable assingment load from review screen
  export let handleServerSearch = () => {
    console.log("from reqh");
  };

  import FilterHeader from "./FilterHeader.svelte";
  import { searchParamObject } from "../../helpers/util";
  import Dropdown from "./Dropdown.svelte";
  import MediaQuery from "../util/MediaQuery.svelte";

  export let showFilter = false;

  const loadAllAssignments = async () => {
    const { data } = await loadDashboardMetadata({}, "?all=true");
    return data;
  };
  export let loadFilteredAssignments;

  const requestParams = searchParamObject();
  const isFiltersInURL = requestParams.apiKey ? true : false;
  showFilter = showFilter || isFiltersInURL;

  function handleSearch() {
    $start_search = !$start_search;
    mobile_start_search = false;
  }
  // width: calc(100% - rem);

  let mobile_panel_style = `
    padding: 1rem;
    width: calc(100% - 1rem);
  `;

  let style = `padding: 1rem 3rem 0.2rem 1rem;`;

  $: uploadBtnDisabled
    ? (style = `
    padding: 1rem 3rem 0.2rem 1rem;
    background: rgba(0, 0, 0, 0.3);
    border-radius: 0px;
    `)
    : (style = `padding: 1rem 3rem 0.2rem 1rem;`);
  let mobile_start_search = false;

  $: if ($start_search) {
    setTimeout(() => {
      mobile_start_search = true;
    }, 1);
  }
</script>

{#if has_mobile_page_header}
  <div class="mobile-header">
    <Panel
      style={mobile_panel_style}
      collapsed={true}
      innerContentClasses="m-0"
    >
      <div class="container">
        {#if $start_search}
          <span class="search-bar">
            <div class="search {mobile_start_search ? 'active-search' : ''}">
              <SearchBar
                bind:search_value
                {searchPlaceholder}
                {handleServerSearch}
              />
            </div>
          </span>
        {:else}
          <span class="title">
            {#if icon}
              <FAIcon
                {icon}
                iconSize="2x"
                fontStyle="regular"
                iconStyle="regular"
              />
            {/if}
            <h3>{title} {contactCount ? `(${contactCount})` : ""}</h3>
          </span>
        {/if}

        {#if enable_search_bar}
          <span
            class="action-icon"
            style={$start_search ? "margin-bottom: 0px" : "margin-bottom: 8px"}
            on:click={handleSearch}
          >
            {#if $start_search}
              <FAIcon icon="times-circle" iconStyle="solid" iconSize="large" />
            {:else}
              <SearchIcon />
            {/if}
          </span>
        {/if}
      </div>
      {#if client_portal}
        <slot name="client-action" />
      {/if}
      {#if client_new_ui}
        <hr />
        <slot name="client_new_ui" />
      {/if}
    </Panel>
  </div>
{/if}

{#if !showSendAssignsBtn}
  <span class="mobile-searchbar {$start_search ? 'active-searchbar' : ''}">
    <SearchBar bind:search_value {searchPlaceholder} {handleServerSearch} />
  </span>
{/if}

{#if headerBtn && showMobileActionBtn}
  <div class="action-icon-mobile add-btn">
    {#if useDropdown}
      <Dropdown
        triggerType="normal"
        text="Add New Contact"
        clickHandler={(ret) => {
          alert(ret);
        }}
        elements={[
          {
            text: "Add New Contact",
            ret: "new",
          },
          {
            text: "Import From Google",
            ret: "google_import",
          },
        ]}
      />
    {:else}
      <span on:click={btnAction}>
        <Button
          color="secondary"
          text={btnText}
          iconStyle="regular"
          icon={btnIcon}
          iconLocation="right"
          disabled={btnDisabled}
        />
      </span>
    {/if}
  </div>
{/if}

<MediaQuery query="(min-width: 481px) and (max-width: 1280px)" let:matches>
  {#if matches}
    <div class="header {classes}">
      <Panel {style} collapsed={true} innerContentClasses="m-0">
        {#if client_new_ui}
          <slot name="client_new_ui" />
        {/if}
        <div class="container {classes}">
          <div class="tabletActionButtons">
            <span class="title {title_classes}">
              {#if icon}
                <FAIcon
                  {icon}
                  iconSize="2x"
                  fontStyle="regular"
                  iconStyle="regular"
                />
              {/if}
              <h2>{title} {contactCount ? `(${contactCount})` : ""}</h2>
            </span>
            {#if enable_search_bar}
              <span class="search-bar">
                <div class="search active-search">
                  <SearchBar
                    width="100%"
                    bind:search_value
                    {searchPlaceholder}
                    {handleServerSearch}
                  />
                </div>
              </span>
            {/if}
          </div>

          <div class="tabletActionButtons">
            {#if useDropdown}
              <span style="width: 1rem;" />
              <Dropdown
                triggerType="normal"
                text="Add New Contact"
                btnColor="secondary"
                clickHandler={dropdownClickHandler}
                elements={[
                  {
                    text: "Create New Contact",
                    icon: "plus",
                    ret: "new",
                  },
                  {
                    text: "Import From Google",
                    icon: "cloud-arrow-down",
                    ret: "google_import",
                  },
                ]}
              />
            {/if}
            <div class="tabletActionButtons">
              {#if headerBtn}
                <div class="action-icon add-btn">
                  <span on:click={btnAction}>
                    <Button
                      color="secondary"
                      text={btnText}
                      iconStyle="regular"
                      icon={btnIcon}
                      iconLocation="right"
                      disabled={btnDisabled}
                    />
                  </span>
                </div>
              {/if}

              {#if showExportCSVBtn}
                <div class="action-icon add-btn">
                  <span on:click={ExportCSVBtnAction}>
                    <Button
                      color="white"
                      text={ExportCSVBtnText}
                      iconStyle="regular"
                      icon={ExportCSVBtnIcon}
                      iconLocation="right"
                      disabled={ExportCSVBtnDisabled}
                    />
                  </span>
                </div>
                <slot name="show-delete" />
              {/if}
              {#if showCsvUploadBtn}
                <div class="action-icon add-btn">
                  <span
                    on:click={() => {
                      !uploadBtnDisabled && uploadBtnAction();
                    }}
                  >
                    <Button
                      color="white"
                      icon={uploadBtnIcon}
                      disabled={uploadBtnDisabled}
                      iconStyle="solid"
                      text={uploadBtnText}
                    />
                  </span>
                </div>
              {/if}
              {#if bulkSendBtn}
                <div class="action-icon add-btn">
                  <span on:click={bulkSendBtnAction}>
                    <Button
                      color="white"
                      icon={bulkSendBtnIcon}
                      text="Bulk Send"
                    />
                  </span>
                </div>
              {/if}
            </div>
          </div>

          {#if showSendAssignsBtn}
            <div class="action-icon add-btn">
              <span on:click={sendAssignsBtnAction}>
                <Button
                  color="secondary"
                  text="Assign / Send"
                  disabled={sendAssignsBtnDisabled}
                />
              </span>
            </div>
          {/if}
          {#if client_portal}
            <slot name="client-action" />
          {/if}
        </div>
        {#if loadAssignment}
          {#await loadAllAssignments() then filterAssignments}
            {#if showFilter}
              <FilterHeader
                assignments={filterAssignments}
                on:filterApplied={loadFilteredAssignments}
              />
            {/if}
          {/await}
        {/if}
      </Panel>
    </div>
  {/if}
</MediaQuery>

<MediaQuery query="(min-width: 1281px)" let:matches>
  {#if matches}
    <div class="header {classes}">
      <Panel {style} collapsed={true} innerContentClasses="m-0">
        {#if client_new_ui}
          <slot name="client_new_ui" />
        {/if}

        <div class="container {classes}">
          <span class="title {title_classes}">
            {#if icon}
              <FAIcon
                {icon}
                iconSize="2x"
                fontStyle="regular"
                iconStyle="regular"
              />
            {/if}
            <h2>{title} {contactCount ? `(${contactCount})` : ""}</h2>
          </span>
          {#if enable_search_bar}
            <span class="search-bar">
              <div class="search {$start_search ? 'active-search' : ''}">
                <SearchBar
                  bind:search_value
                  {searchPlaceholder}
                  {handleServerSearch}
                />
              </div>
            </span>

            <span class="action-icon" on:click={handleSearch}>
              {#if $start_search}
                <FAIcon
                  icon="times-circle"
                  iconStyle="solid"
                  iconSize="large"
                />
              {:else}
                <SearchIcon />
              {/if}
            </span>
          {/if}
          {#if headerBtn}
            <div class="action-icon add-btn">
              <span on:click={btnAction}>
                <Button
                  color="secondary"
                  text={btnText}
                  iconStyle="regular"
                  icon={btnIcon}
                  iconLocation="right"
                  disabled={btnDisabled}
                />
              </span>
            </div>
          {/if}
          {#if useDropdown}
            <span style="width: 1rem;" />
            <Dropdown
              triggerType="normal"
              text="Add New Contact"
              btnColor="secondary"
              clickHandler={dropdownClickHandler}
              elements={[
                {
                  text: "Create New Contact",
                  icon: "plus",
                  ret: "new",
                },
                {
                  text: "Import From Google",
                  icon: "cloud-arrow-down",
                  ret: "google_import",
                },
              ]}
            />
          {/if}
          <slot name="show-delete" />
          {#if showExportCSVBtn}
            <div class="action-icon add-btn">
              <span on:click={ExportCSVBtnAction}>
                <Button
                  color="white"
                  text={ExportCSVBtnText}
                  iconStyle="regular"
                  icon={ExportCSVBtnIcon}
                  iconLocation="right"
                  disabled={ExportCSVBtnDisabled}
                />
              </span>
            </div>
          {/if}
          {#if showCsvUploadBtn}
            <div class="action-icon add-btn">
              <span
                on:click={() => {
                  !uploadBtnDisabled && uploadBtnAction();
                }}
              >
                <Button
                  color="white"
                  icon={uploadBtnIcon}
                  disabled={uploadBtnDisabled}
                  iconStyle="solid"
                  text={uploadBtnText}
                />
              </span>
            </div>
          {/if}
          {#if bulkSendBtn}
            <div class="action-icon add-btn">
              <span on:click={bulkSendBtnAction}>
                <Button color="white" icon={bulkSendBtnIcon} text="Bulk Send" />
              </span>
            </div>
          {/if}
          {#if showSendAssignsBtn}
            <div class="action-icon add-btn">
              <span on:click={sendAssignsBtnAction}>
                <Button
                  color="secondary"
                  text="Assign / Send"
                  disabled={sendAssignsBtnDisabled}
                />
              </span>
            </div>
          {/if}
          {#if client_portal}
            <slot name="client-action" />
          {/if}
        </div>
        {#if loadAssignment}
          {#await loadAllAssignments() then filterAssignments}
            {#if showFilter}
              <FilterHeader
                assignments={filterAssignments}
                on:filterApplied={loadFilteredAssignments}
              />
            {/if}
          {/await}
        {/if}
      </Panel>
    </div>
  {/if}
</MediaQuery>

{#if $dashboard_filter_modal}
  <DashboardFilterModal
    on:close={() => {
      $dashboard_filter_modal = false;
    }}
  >
    <div style="padding: 0.5rem 0;">
      <SearchBar bind:search_value {searchPlaceholder} />
    </div>
    {#await loadAllAssignments() then filterAssignments}
      <FilterHeader
        assignments={filterAssignments}
        on:filterApplied={loadFilteredAssignments}
      />
    {/await}
  </DashboardFilterModal>
{/if}

<style>
  .title {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    color: #76808b;
    font-family: "Lato", sans-serif;
    /* flex: 1; */
    font-size: 16px;
    margin: 0;
  }
  .title-margin-top {
    margin-top: 5px;
  }
  .search-bar {
    flex: 2;
    margin-top: 5px;
  }
  .search {
    display: block;
    width: 0;
    visibility: hidden;
    transition: width 0.5s ease;
  }
  .active-search {
    visibility: visible;
    width: 100%;
  }
  .container {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 2px;
  }
  .action-icon {
    color: #76808b;
    margin: 0.5rem 0 0 0.8rem;
    cursor: pointer;
  }

  .action-icon-mobile {
    display: none;
  }
  .mobile-header {
    display: none;
  }
  .add-btn {
    margin-bottom: 4px;
  }

  hr {
    border: none;
    border-top: 1px solid #e6e6e6;
    margin: 0;
    margin-top: 0.5rem;
    padding: 0.5rem 0;
  }

  .mobile-searchbar {
    display: none;
  }
  .search-action {
    margin-right: 1.3rem;
  }

  @media only screen and (max-width: 767px) {
    .header {
      display: none;
    }
    .mobile-header {
      display: flex;
    }
    .title h3 {
      margin: 0px;
    }

    .mobile-searchbar {
      display: block;
      position: fixed;
      z-index: 0;
      top: 18px;
      left: 52px;
      height: 2.5rem;
      width: 0;
      transition: width 0.3s ease;
    }
    .active-searchbar {
      width: calc(100% - 150px);
      z-index: 999;
    }

    .action-icon-mobile {
      display: block;
      color: #76808b;
      margin-top: 0.75rem;
      cursor: pointer;
    }
  }
  @media only screen and (max-width: 1024px) {
    .search-bar {
      flex: 1;
      margin-top: 5px;
    }
  }

  .tabletActionButtons {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
</style>
