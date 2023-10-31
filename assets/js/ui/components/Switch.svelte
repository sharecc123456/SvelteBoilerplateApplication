<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  export let checked = false;
  export let text = "This is a default text.";
  export let icon = "";
  export let disabled = false; // is this component disabled?
  //this is a second option to get the checked value
  export let action = undefined;
  export let marginBottom = true;
</script>

<div class="container" class:mb={marginBottom}>
  <label class="switch">
    <input
      type="checkbox"
      bind:checked
      {disabled}
      on:click={() => {
        if (!disabled && action !== undefined) action(!checked);
      }}
    />
    <span class="slider" />
  </label>
  <span class="text" class:disabled>
    {#if icon != ""}
      <FAIcon {icon} iconStyle="regular" iconSize="large" />
    {/if}
    {text}
  </span>
</div>

<style>
  .container {
    display: contents;
    align-items: center;
  }

  .mb {
    margin-bottom: 15px;
  }
  .text {
    width: 100%;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 15px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: var(--text-primary);
    margin-left: 10px;
  }
  .text.disabled {
    text-decoration: line-through;
  }
  .switch {
    position: relative;
    display: inline-block;
    width: 35px;
    height: 17px;
  }
  .switch input {
    opacity: 0;
    width: 0;
    height: 0;
  }
  .slider {
    position: absolute;
    cursor: pointer;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: #ccc;
    -webkit-transition: 0.4s;
    transition: 0.4s;
    border-radius: 34px;
  }
  .slider:before {
    position: absolute;
    content: "";
    height: 13px;
    width: 13px;
    left: 4px;
    bottom: 2px;
    background-color: white;
    -webkit-transition: 0.4s;
    transition: 0.4s;
    border-radius: 50%;
  }
  input:checked + .slider {
    background-color: #4badf3;
  }
  input:checked + .slider {
    box-shadow: 0 0 1px #76808b;
  }
  input:checked + .slider:before {
    -webkit-transform: translateX(15px);
    -ms-transform: translateX(15px);
    transform: translateX(15px);
  }
</style>
