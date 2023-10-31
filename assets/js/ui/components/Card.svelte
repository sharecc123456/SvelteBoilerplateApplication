<script>
  export let isHeader = false;
  export let isSelected = false;

  export let setSelected = () => {};
</script>

<div on:click={setSelected} class="card">
  {#if isHeader}
    <div class="header" />
  {/if}

  {#if isSelected}
    <div class="selected" />
  {/if}
  <div class="card-content">
    <slot />
  </div>
</div>

<style>
  .card {
    position: relative;
    box-shadow: rgba(50, 50, 93, 0.25) 0px 2px 5px -1px,
      rgba(0, 0, 0, 0.3) 0px 1px 3px -1px;
    border: 1px solid #dadce0;
    border-radius: 8px;
    max-width: 100%;
  }
  .card-content {
    padding: 1.5rem;
  }

  .header {
    background-color: #4a5158;
    border-top-left-radius: 8px;
    border-top-right-radius: 8px;
    height: 10px;
    position: absolute;
    top: -1px;
    left: -1px;
    width: calc(100% + 2px);
    z-index: 1;
  }

  .selected {
    height: calc(100% + 2px);
    width: 6px;
    background-color: #0693e3;
    position: absolute;
    top: 0;
    left: 0;
    border-top-left-radius: 8px;
    border-bottom-left-radius: 8px;
  }
</style>
