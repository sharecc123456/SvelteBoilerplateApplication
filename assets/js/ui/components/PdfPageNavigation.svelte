<script>
  import { createEventDispatcher, onMount } from "svelte";
  import Select from "svelte-select";
  import FAIcon from "../atomic/FAIcon.svelte";
  export let isPdfView = false,
    currentPage = 0,
    totalPage = 1,
    elmWidth = 0;
  const dispatch = createEventDispatcher();
  let items = [],
    elm;
  let value = { value: 1, label: 1 };
  $: {
    let _tempItems = [];
    for (let i = 1; i <= totalPage; i++) {
      let _obj = {
        value: i,
        label: i,
      };
      _tempItems.push(_obj);
    }
    items = _tempItems;
  }
  $: value = {
    value: currentPage ? currentPage : 1,
    label: currentPage ? currentPage : 1,
    preventPageForwarding: true,
  };
  $: totalPageDigitLength = totalPage.toString().length;

  onMount(() => {
    elmWidth = elm.clientWidth;
  });
  function handlePageForwarder({ detail }) {
    let { value, preventPageForwarding } = detail;
    if (!preventPageForwarding) {
      value = isPdfView ? value : --value;
      dispatch("pageForwarder", { pageNumber: value });
    }
  }
</script>

<div class="field has-addons">
  <div class="container" bind:this={elm}>
    <div class="control" style="margin-top: 0.2rem;">
      <button
        type="button"
        class="button {currentPage == 1 ? 'disabled' : ''}"
        style="box-shadow: none;"
        on:click={() => {
          dispatch("prev");
        }}
      >
        <FAIcon icon="chevron-left" iconSize="large" />
      </button>
    </div>
    <div class="control contents">
      <span
        class={totalPageDigitLength > 2
          ? "selectThemedForHundreds"
          : "selectThemedForTens"}
      >
        <Select
          {items}
          {value}
          on:select={handlePageForwarder}
          noOptionsMessage=""
          placeholder=""
          isClearable={false}
          containerStyles={`
              height: 2rem;
              padding-right: 0.2rem;
              min-width: 50px;
            `}
        />
      </span>
      <span style="padding: 5px;"
        >of
        <strong>{totalPage}</strong>
      </span>
    </div>
    <div class="control" style="margin-top: 0.2rem;">
      <button
        type="button"
        class="button {currentPage == totalPage ? 'disabled' : ''}"
        style="box-shadow: none;"
        on:click={() => {
          dispatch("next");
        }}
      >
        <FAIcon icon="chevron-right" iconSize="large" />
      </button>
    </div>
  </div>
</div>

<style>
  .selectThemedForTens {
    --itemPadding: 0 14px;
  }
  .selectThemedForHundreds {
    --itemPadding: 0 10px;
  }
  :global(.listContainer::-webkit-scrollbar) {
    display: none;
  }

  .field.has-addons {
    display: flex;
    justify-content: flex-start;
    gap: 0.1rem;
    font-family: "Nunito", sans-serif;
  }
  .container {
    margin-right: auto;
    display: flex;
  }
  .control {
    box-sizing: border-box;
    clear: both;
    font-size: 1rem;
    position: relative;
    text-align: inherit;
  }
  .contents {
    display: contents;
  }
  .button {
    box-shadow: none;
    border: none;
    background: none;
    cursor: pointer;
  }
  .disabled {
    color: #aeaeae;
    pointer-events: none;
  }

  @media screen and (min-width: 481px) and (max-width: 1280px) {
    .field.has-addons {
      display: flex;
      justify-content: flex-start;
      gap: 0.1rem;
      font-family: "Nunito", sans-serif;
      width: 132px;
    }
  }
</style>
