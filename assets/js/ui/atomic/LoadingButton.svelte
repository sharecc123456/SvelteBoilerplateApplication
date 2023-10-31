<script>
  import FAIcon from "./FAIcon.svelte";
  export let text;
  export let color = "primary";
  export let type = "button";
  export let icon = "";
  export let iconStyle = "";
  export let disabled = false;

  import { Circle } from "svelte-loading-spinners";
  export let pressed = false;
  export let fullWidth = false;
  export let isErr = false; //if it is error stop spin
</script>

<button
  {type}
  class={color}
  class:width-100={fullWidth}
  {disabled}
  class:disabled
  on:click={() => {
    if (!disabled) pressed = true;
  }}
>
  <div class="inner">
    {#if pressed && !isErr}
      <Circle size="12" color="white" duration="2s" />
    {:else if icon != ""}
      <FAIcon {icon} {iconStyle} rightPad />
    {/if}
    <span class="text" class:pressed>{text}</span>
  </div>
</button>

<style>
  .width-100 {
    width: 100%;
  }

  button {
    display: inline-block;
    border-style: solid;
    border-radius: 4px;
    cursor: pointer;
    padding: 0.5rem 1.5rem;

    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 16px;
    max-height: 40px;
    /* identical to box height, or 114% */
    text-align: center;
    text-decoration: none;
    letter-spacing: 0.02em;
    text-transform: capitalize;
    white-space: nowrap;
    color: #ffffff;

    filter: drop-shadow(0px 3px 4px rgba(46, 56, 77, 0.12));
  }

  button:hover:enabled {
    box-shadow: 0px 3px 20px 7px rgba(46, 56, 77, 0.22);
  }

  button:active:enabled {
    filter: brightness(0.8);
  }

  button.noLeftPad {
    padding: 0.5rem 0.75rem 0.5rem 0.75rem;
  }

  .primary {
    background: #4a5157;
    border-color: #4a5157;
  }

  .secondary {
    background: #4badf3;
    border-color: #4badf3;
  }

  .danger {
    background: #fce7e7;
    border-color: #fce7e7;
    color: #db5244;
  }

  .warning {
    background: #fbeed7;
    border-color: #fbeed7;
    color: #eda839;
  }

  .green {
    background: #eaf7f0;
    border-color: #eaf7f0;
    color: #54cc86;
  }

  .light {
    background: #e9f1fa;
    border-color: #e9f1fa;
    color: #2a2f34;
  }

  .white {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    color: #606972;
    filter: none;
  }

  .disabled {
    background: #b3c1d0;
    border-color: #b3c1d0;
    color: #ffffff;
    cursor: not-allowed;
  }

  .inner {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    justify-content: center;
  }

  .text.pressed {
    padding-left: 0.5rem;
  }

  @media only screen and (max-width: 1040px) {
    button {
      font-size: 12px;
      padding: 0.3rem 1.2rem;
    }
  }
  @media only screen and (max-width: 767px) {
    button {
      width: 100%;
    }
  }
</style>
