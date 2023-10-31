<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  import { createEventDispatcher } from "svelte";
  export let text;
  export let isChecked;
  export let selectedValue;
  export let changeInternally = true;
  export let disableMarginstyle = false;
  export let disable = false;
  export let subtext = "";

  const dispatch = createEventDispatcher();
</script>

<div
  class="element"
  class:container-margin__no={disableMarginstyle}
  on:click={() => {
    if (disable) return;
    isChecked = !isChecked;
    if (isChecked) {
      selectedValue = text;
    } else {
      selectedValue = "";
    }

    dispatch("changed", { state: isChecked });
    if (!changeInternally) isChecked = !isChecked;
  }}
>
  <div
    class="button"
    style={disable ? "color: #848485;cursor:not-allowed;" : ""}
  >
    {#if isChecked}
      <span>
        <FAIcon icon="check-square" iconStyle="solid" />
      </span>
    {:else}
      <span>
        <FAIcon icon="square" iconStyle="regular" />
      </span>
    {/if}
  </div>
  <span class="text">
    <span class="value-text">
      {text}
    </span>
    <span class="bolder">{subtext}</span>
  </span>
</div>

<style>
  .text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #4a5158;
  }

  .bolder {
    font-weight: bolder;
    font-size: 12px;
  }

  .button {
    padding-right: 1rem;
    filter: drop-shadow(1px 2px 4px rgba(102, 71, 186, 0.18));
    font-size: 20px;
    color: #4a5158;
    cursor: pointer;
    user-select: none;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
  }

  .element {
    cursor: pointer;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    word-break: break-word;
  }

  .container-margin__no {
    margin-bottom: 0 !important;
  }
</style>
