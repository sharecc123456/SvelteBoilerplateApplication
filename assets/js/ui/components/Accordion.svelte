<script>
  import { onMount } from "svelte";
  import { slide } from "svelte/transition";
  import FAIcon from "../atomic/FAIcon.svelte";

  export let title = "Title";
  export let open = false;

  function toggleAccordion() {
    open = !open;
  }
</script>

<div class="accordion" class:open>
  <div class="accordion-header" on:click={toggleAccordion}>
    <div class="accordion-summary">
      <span class="accordion-title">{title}</span>
      <span transition:slide={{ duration: 300 }} class="expand-icon">
        {#if open}
          <FAIcon iconSize="extrasmall" icon="chevron-up" iconStyle="solid" />
        {:else}
          <FAIcon iconSize="extrasmall" icon="chevron-down" iconStyle="solid" />
        {/if}
      </span>
    </div>
  </div>
  {#if open}
    <div transition:slide={{ duration: 300 }} class="accordion-details">
      <slot />
    </div>
  {/if}
</div>

<style>
  .accordion {
    border-radius: 15px;
    margin-bottom: 10px;
    box-shadow: none;
    overflow: hidden;
    transition: all 0.3s ease-in-out;
    box-shadow: rgb(0 0 0 / 10%) 0px 4px 12px;
  }
  .accordion.open {
    min-height: 64px;
  }
  .accordion-header {
    padding: 16px;
    cursor: pointer;
    background-color: #ffffff;
    font-size: 1.2rem;
    font-weight: 400;
  }
  .accordion-summary {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .accordion-title {
    margin-right: 16px;
  }
  .expand-icon {
    font-size: 1.5rem;
  }
  .accordion-details {
    padding: 8px 16px 16px;
    background-color: #ffffff;
  }
</style>
