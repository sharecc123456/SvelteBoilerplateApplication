<script context="module">
  import {
    toastMessage,
    hideToast,
    toastColor,
    bColor,
    bStyle,
    bWidth,
    tColor,
  } from "../../helpers/ToastStorage.js";
  import FAIcon from "../atomic/FAIcon.svelte";

  //Top Left (TL) Top Middle (TM) Top Right (TR)
  //Mid Left (ML) Mid Middle (MM) Mid Right (MR)
  //Bot Left (BL) Bot Middle (MB) Bot Right (MB)

  let toastLength = "string";
  let toastPxCount = 0;
  let checkEnabled = false;

  let leftVar = "auto";
  let rightVar = "auto";
  let topVar = "auto";
  let botVar = "auto";

  export function toastLocation(location, message, type) {
    toastLength = message.length;
    toastPxCount = toastLength * 8;
    if (toastPxCount > 500) {
      toastPxCount = 267;
    } else {
      toastPxCount = toastPxCount / 2;
    }
    if (type == "default" || type == "white") {
      checkEnabled = true;
    } else {
      checkEnabled = false;
    }

    switch (location) {
      case "TL":
        topVar = 0.1; //10% nav heade introduced
        botVar = "auto";
        leftVar = 0.01;
        rightVar = "auto";
        toastPxCount = 0;
        break;
      case "TM":
        topVar = 0.1;
        botVar = "auto";
        leftVar = 0.5;
        rightVar = "auto";
        break;
      case "TR":
        topVar = 0.1;
        botVar = "auto";
        leftVar = "auto";
        rightVar = 0.02;
        toastPxCount = 0;
        break;
      case "ML":
        topVar = 0.5;
        botVar = "auto";
        leftVar = 0.01;
        rightVar = "auto";
        toastPxCount = 0;
        break;
      case "MM":
        topVar = 0.5;
        botVar = "auto";
        leftVar = 0.5;
        rightVar = "auto";
        break;
      case "MR":
        topVar = 0.5;
        botVar = "auto";
        leftVar = "auto";
        rightVar = 0.02;
        toastPxCount = 0;
        break;
      case "BL":
        topVar = "auto";
        botVar = 0.01;
        leftVar = 0.01;
        rightVar = "auto";
        toastPxCount = 0;
        break;
      case "BM":
        topVar = "auto";
        botVar = 0.01;
        leftVar = 0.5;
        rightVar = "auto";
        break;
      case "BR":
        topVar = "auto";
        botVar = 0.01;
        leftVar = "auto";
        rightVar = 0.02;
        toastPxCount = 0;
        break;
      default:
        alert("Toast Bar: Locational Error");
        break;
    }
  }
</script>

<div
  class="toast-container"
  style="background-color: {$toastColor};
  		--left:{leftVar};
		--right:{rightVar};
		--top:{topVar};
		--bottom:{botVar};
		--strLength:{toastPxCount};
    border-style: {$bStyle};
    border-width: {$bWidth};
    z-index: 9999
    border-color: {$bColor};"
>
  {#if checkEnabled}
    <span class="icon" style="color: {$tColor};"
      ><FAIcon icon="check-circle" iconStyle="solid" iconSize="large" /></span
    >
  {/if}
  {#if $toastColor == "#DB5244"}
    <span class="icon" style="color: {$tColor};"
      ><FAIcon
        icon="exclamation-triangle"
        iconStyle="solid"
        iconSize="large"
      /></span
    >
  {/if}
  <div class="toast-message" style="color: {$tColor};">{$toastMessage}</div>
  <!-- <span class="close-btn" style="color: {$tColor};" on:click={hideToast}>
	<span><FAIcon icon="times-circle" iconStyle="solid"/></span>
  </span> -->
</div>

<style>
  .toast-container {
    display: flex;
    flex-direction: row;
    position: fixed;
    top: calc(var(--top) * 100%);
    bottom: calc(var(--bottom) * 100%);
    left: calc(var(--left) * 100% - (var(--strLength) * 1px));
    right: calc(var(--right) * 100%);
    max-width: 500px;
    padding: 16px;
    border-radius: 4px;
    text-align: center;
    font-family: "Nunito", sans-serif;
    z-index: 9999;
    box-shadow: 0px 3px 5px rgba(0, 0, 0, 0.2), 0px 1px 18px rgba(0, 0, 0, 0.12),
      0px 6px 10px rgba(0, 0, 0, 0.14);
  }

  .toast-message {
    padding-left: 0.5rem;
    padding-right: 0.5rem;
    color: white;
    font-family: "Nunito", sans-serif;
    text-align: center;
    font-size: 16px;
  }

  .icon {
    align-self: center;
  }
  @media only screen and (max-width: 767px) {
    .toast-container {
      width: calc(
        100% - 52px
      ); /* border 2+2, body 8+8, padding 16+16 total = 52px */
      left: 0;
      right: 0;
      margin-left: auto;
      margin-right: auto;
    }
  }
</style>
