<script>
  import FAIcon from "./FAIcon.svelte";
  export let text;
  export let textStyle = "";
  export let color = "primary";
  export let type = "button";
  export let style = "";
  export let icon = "";
  export let iconStyle = "";
  export let iconLocation = "left";
  export let disabled = false;
  export let centerButton = false;
  export let halfWidth = false;
  export let fullHeight = false;
  export let floatLeft = false;
  export let reviewIcon = false;
  export let ignore = false;
  export let showTooltip = false;
  export let tooltipMessage = "";
  export let tooltipExtraPad = false; // pad the tooltip a little more
  export let onClickHandler = () => {};
</script>

<button
  {type}
  {style}
  class={color}
  {disabled}
  class:disabled
  class:noLeftPad={icon != ""}
  class:wider={centerButton}
  class:halfWidth
  class:ignore
  class:tooltip={showTooltip}
  class:fullHeight
  on:click={onClickHandler}
>
  {#if iconLocation == "left"}
    {#if icon != ""} <FAIcon {icon} {iconStyle} rightPad /> {/if}
    <span style={textStyle}>{text}</span>
    {#if showTooltip}
      <span class="tooltiptext" class:extrapadding={tooltipExtraPad}
        >{tooltipMessage}</span
      >
    {/if}
  {:else if iconLocation == "floatLeft"}
    {#if icon != ""}
      <FAIcon {icon} {iconStyle} iconSize="large" floatLeft />
    {/if}
    <span class:floatLeft>{text}</span>
    {#if icon != "" && reviewIcon}
      <span class="notification">
        <FAIcon icon="exclamation-circle" iconStyle="solid" iconSize="large" />
      </span>
    {/if}
    {#if showTooltip}
      <span class="tooltiptext" class:extrapadding={tooltipExtraPad}
        >{tooltipMessage}</span
      >
    {/if}
  {:else}
    {text}
    {#if icon != ""} <FAIcon {icon} {iconStyle} leftPad /> {/if}
    {#if showTooltip}
      <span class="tooltiptext" class:extrapadding={tooltipExtraPad}
        >{tooltipMessage}</span
      >
    {/if}
  {/if}
</button>

<style>
  .ignore {
    display: none;
  }

  button {
    display: block;
    width: 100%;
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
    text-transform: none;
    white-space: nowrap;
    color: #ffffff;

    filter: drop-shadow(0px 3px 4px rgba(46, 56, 77, 0.12));
  }

  .fullHeight {
    height: 100%;
  }
  .medium {
    padding: 0.8rem 1rem !important;
    max-height: 60px;
  }

  .wider {
    margin: 0 20px;
    min-width: 120px;
  }

  .medium {
    padding: 0.6rem 1.5rem;
    max-height: 60px;
  }

  .halfWidth {
    width: 71% !important;
    display: flex;
    align-items: center;
  }

  .floatLeft {
    float: left;
    margin-left: 10px;
    font-size: 16px;
    white-space: break-spaces;
    text-align: start;
    text-align-last: center;
  }

  .notification {
    color: #db5244;
    border-radius: 50px;
    padding: 2px 5px;
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

  .gray {
    color: #2a2f34;
    background: #e9f1fa;
    border-color: #e9f1fa;
  }

  .secondary {
    background: #4badf3;
    border-color: #4badf3;
  }
  .danger {
    background: #db5244;
    border-color: #db5244;
    color: #ffffff;
  }

  .danger-white {
    background: white;
    border-color: red;
    color: red;
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

  .green-solid {
    background: #28a745;
    border-color: #28a745;
    color: #fff;
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
    background: #b3c1d0 !important;
    border-color: #b3c1d0 !important;
    color: #ffffff !important;
    cursor: not-allowed;
  }

  .black {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    color: #2a2f34;
    filter: none;
  }

  .tooltip {
    position: relative;
  }
  .tooltip .tooltiptext {
    visibility: hidden;
    width: max-content;
    background-color: black;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 6px 0;
    position: absolute;
    z-index: 1;
    bottom: 40%;
    left: -110%;
    right: 0%;
    font-size: 9px;
  }

  .tooltip .extrapadding {
    padding: 6px 12px;
  }

  .tooltip:hover .tooltiptext {
    visibility: visible;
  }
  @media only screen and (max-width: 1024px) {
    .wider {
      max-width: 130px;
    }
  }
  @media only screen and (max-width: 1040px) {
    button {
      font-size: 12px;
      padding: 0.3rem 1.2rem;
    }
    button.noLeftPad {
      padding: 0.3rem 1.2rem;
    }
    .wider {
      margin: 0px;
    }
  }
  @media only screen and (max-width: 425px) {
    .halfWidth {
      width: 100% !important;
      display: block;
    }

    .floatLeft {
      font-size: 16px;
      float: unset;
    }
  }
  @media only screen and (max-width: 320px) {
    .floatLeft {
      font-size: 14px;
    }
  }

  @media screen and (min-width: 481px) and (max-width: 1280px) {
    button {
      font-size: 11px;
      padding: 0.3rem 1.2rem;
    }
  }
</style>
