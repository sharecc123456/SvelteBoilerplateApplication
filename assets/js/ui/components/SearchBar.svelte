<script>
  import { start_search } from "./../../store";
  import TextField from "./TextField.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { onMount } from "svelte";
  import { debounce } from "Helpers/util";

  export let search_value;
  export let searchPlaceholder;
  export let handleServerSearch = () => {};
  export let width = "95%";
  let elm;

  function clearSearch() {
    search_value = "";
    handleServerSearch();
  }

  $: if ($start_search) {
    setTimeout(() => {
      elm.focus();
    }, 500);
  }

  const debouncedSearch = debounce(handleServerSearch, 1000);

  const bindSearchKeyup = () => {
    elm.addEventListener("keyup", debouncedSearch);
  };

  onMount(() => {
    bindSearchKeyup();
  });
</script>

<div class="search-group">
  <TextField
    bind:value={search_value}
    bind:elm
    {width}
    icon="search"
    float="right"
    text={searchPlaceholder}
  />
  {#if search_value != ""}
    <span on:click={clearSearch} class="clear-button-icon">
      <FAIcon icon="times-circle" iconStyle="solid" />
    </span>
  {/if}
</div>

<style>
  .search-group {
    position: relative;
  }
  .clear-button-icon {
    cursor: pointer;
    color: #ccc;
    position: absolute;
    right: 8px;
    top: 6px;
  }

  @media only screen and (max-width: 767px) {
    .clear-button-icon {
      display: none;
    }
  }
</style>
