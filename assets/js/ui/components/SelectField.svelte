<script>
  export let label,
    style = "",
    options = [],
    isFormSelect = false,
    value;
</script>

<div class="form-group" {style}>
  {#if label}
    <label for={label}>{label}</label>
  {/if}
  <span class="select is-fullwidth">
    {#if isFormSelect}
      <select bind:value>
        {#each options as option}
          <option value={option}>{option}</option>
        {/each}
      </select>
    {:else}
      <select bind:value>
        {#each options as option}
          <option value={option.value}>{option.text}</option>
        {/each}
      </select>
    {/if}
  </span>
</div>

<style>
  .is-fullwidth {
    width: 100%;
  }
  .is-fullwidth select {
    width: 100%;
  }
  .select {
    display: inline-block;
    max-width: 100%;
    position: relative;
    vertical-align: top;
  }

  option {
    background-color: white !important;
  }
  .select::after {
    border: 3px solid transparent;
    border-radius: 2px;
    border-right: 0;
    border-top: 0;
    content: " ";
    display: block;
    height: 0.625em;
    margin-top: -9px;
    pointer-events: none;
    position: absolute;
    top: 50%;
    transform: rotate(-45deg);
    transform-origin: center;
    width: 0.625em;
  }
  .select::after {
    border-color: #000000;
    right: 1.125em;
    z-index: 4;
  }
  .select select {
    cursor: pointer;
    display: block;
    font-size: 1em;
    max-width: 100%;
    outline: 0;
    -moz-appearance: none;
    -webkit-appearance: none;
    align-items: center;
    border: 1px solid transparent;
    border-radius: 0.375em;
    box-shadow: none;
    display: inline-flex;
    font-size: 1rem;
    height: 2rem;
    justify-content: flex-start;
    line-height: 1.5;
    /* padding-bottom: calc(0.5em - 1px); */
    padding-left: calc(0.75em - 1px);
    padding-right: calc(0.75em - 1px);
    /* padding-top: calc(0.5em - 1px); */
    position: relative;
    background-color: #fff;
    border-color: #dbdbdb;
    color: #363636;
  }
  .select select:not([multiple]) {
    padding-right: 2.5em;
  }
  .select select:hover {
    border-color: #b5b5b5;
  }
  .form-group {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 0.2rem;
    width: 100%;
  }
  .form-group label {
    /* margin-bottom: 0.5rem; */
    color: #76808b;
  }
</style>
