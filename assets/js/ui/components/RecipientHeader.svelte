<script>
  import { start_search } from "./../../store";
  import Panel from "./Panel.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import SearchIcon from "../atomic/SearchIcon.svelte";
  import SearchBar from "./SearchBar.svelte";

  export let title = "",
    search_value,
    enable_search_bar = true,
    searchPlaceholder;
  export let showSendAssignsBtn,
    client_portal = false,
    client_new_ui = false;
  export let title_classes = "title-margin-top",
    classes = "",
    has_mobile_page_header = false;

  export let handleServerSearch = () => {
    console.log("from reqh");
  };

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
            <h3>{title}</h3>
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

<div class="header {classes}">
  <Panel {style} collapsed={true} innerContentClasses="m-0">
    {#if client_new_ui}
      <slot name="client_new_ui" />
    {/if}

    <div class="container {classes}">
      <span class="title {title_classes}">
        <h2>{title}</h2>
      </span>

      <span class="search-bar">
        <div class="search {$start_search ? 'active-search' : ''}">
          <SearchBar
            bind:search_value
            {searchPlaceholder}
            {handleServerSearch}
          />
        </div>
      </span>

      {#if enable_search_bar}
        <span class="action-icon" on:click={handleSearch}>
          {#if $start_search}
            <FAIcon icon="times-circle" iconStyle="solid" iconSize="large" />
          {:else}
            <SearchIcon />
          {/if}
        </span>
      {/if}
      {#if client_portal}
        <slot name="client-action" />
      {/if}
    </div>
  </Panel>
</div>

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
  }
  @media only screen and (max-width: 1024px) {
    .search-bar {
      flex: 1;
      margin-top: 5px;
    }
  }
</style>
