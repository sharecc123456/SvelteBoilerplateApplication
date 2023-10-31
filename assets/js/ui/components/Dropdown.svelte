<script>
  import { createEventDispatcher } from "svelte";
  import Button from "../atomic/Button.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import VEllipsis from "../atomic/VEllipsis.svelte";
  import TightButton from "../atomic/TightButton.svelte";
  import { clickOutside } from "../../helpers/clickOutside.js";
  import { isBrowserTypeSafari } from "../../helpers/util";

  export let classes = "";
  export let parentClasses = "";
  export let childClasses = "";
  export let text = "Dropdown Trigger";
  export let chevron = true;
  // if triggerType == normal, then the color of the button
  export let btnColor = "light";

  export let hasTrigger = true;
  export let triggerType = "normal";
  export let buttonColor = "primary";

  // Example elements:
  //
  // {
  //   icon: 'garbage',
  //   text: 'whatever',
  // }
  export let elements;
  export let clickHandler;
  export let scrollable = false;
  let showContent = false;
  let menu = null;
  export let optionsCenter = false;

  const isSafari = isBrowserTypeSafari();

  const dispatch = createEventDispatcher();

  // Make state reactive as props is being manupilated
  $: __elements = elements.filter((ele) => {
    return isSafari ? ele.text != "Print" : ele;
  });

  function internalClickHandler(a) {
    showContent = false;

    if (clickHandler != undefined) clickHandler(a);
  }
</script>

<svelte:window
  on:keydown={(evt) => {
    if (evt.key == "Escape") {
      showContent = false;
    }
  }}
/>

<div class="dropdown {parentClasses}" bind:this={menu}>
  <div
    class="dropdown-trigger {childClasses} {__elements.length == 0
      ? 'unclickable'
      : ''} "
    on:click|stopPropagation={() => {
      if (__elements.length != 0) {
        showContent = !showContent;
        setTimeout(() => {
          dispatch("openMenu");
        }, 0);
      }
    }}
  >
    {#if hasTrigger == false}
      <!-- no trigger -->
    {:else if triggerType == "normal"}
      {#if chevron}
        {#if showContent}
          <Button
            {text}
            color={btnColor}
            icon="caret-up"
            iconStyle="solid"
            iconLocation="right"
          />
        {:else}
          <Button
            {text}
            color={btnColor}
            icon="caret-down"
            iconStyle="solid"
            iconLocation="right"
          />
        {/if}
      {:else}
        <TightButton
          {text}
          color={btnColor}
          icon="ellipsis-v"
          iconStyle="solid"
          iconLocation="right"
        />
      {/if}
    {:else if triggerType == "vellipsis"}
      <VEllipsis />
    {:else if triggerType == "ellipsis"}
      <FAIcon icon="ellipsis-v" iconStyle="solid" />
    {:else if triggerType == "button"}
      <Button {text} color={buttonColor} />
    {/if}
  </div>
  {#if showContent}
    <div
      class="dropdown-content {classes}"
      class:scrollable
      use:clickOutside
      on:click_outside={() => {
        showContent = false;
      }}
    >
      {#each __elements as element}
        {#if !element.disabled}
          {#if !element.blocked}
            <div
              on:click|stopPropagation={internalClickHandler(element.ret)}
              class={optionsCenter ? "element elementC" : "element"}
            >
              {#if element.icon != undefined}
                <div
                  class="icon"
                  style={`color: ${
                    element.iconColor || "#2a2f34"
                  }; margin-right: ${
                    element.icon == "exclamation" ? "1rem" : "0.5rem"
                  }`}
                >
                  <FAIcon icon={element.icon} iconStyle={element.iconStyle} />
                </div>
              {/if}
              <div>{element.text}</div>
            </div>
          {:else}
            <div
              on:click|stopPropagation={/* Do nothing */ ""}
              style="cursor: not-allowed;"
              class:blocked={element.blocked}
              class={optionsCenter
                ? "element elementC tooltip"
                : "element tooltip"}
            >
              {#if element.icon != undefined}
                <div
                  class="icon"
                  style={`color: ${
                    element.iconColor || "#2a2f34"
                  }; margin-right: 0.5rem`}
                >
                  <FAIcon icon={element.icon} iconStyle={element.iconStyle} />
                </div>
              {/if}
              {#if element.showTooltip}
                <span class="tooltiptext">{element.tooltipMessage}</span>
              {/if}
              <div>{element.text}</div>
            </div>
          {/if}
        {/if}
        {#if element.after == "marker"}
          <hr />
        {/if}
      {/each}
    </div>
  {/if}
</div>

<style>
  .blocked {
    background: #a3a4a5 !important;
    color: #ffffff;
    cursor: not-allowed;
  }

  .blocked:hover {
    background-color: #a3a4a5 !important;
  }

  hr {
    margin: 0.1rem 1rem 0.1rem 1rem;
    border: 1px solid #b1b1b1;
    border-radius: 12px;
  }

  .element {
    cursor: pointer;
  }

  .dropdown-trigger {
    display: inline-block;
    width: 100%;
  }

  .dropdown-content {
    position: absolute;
    background: #ffffff;
    box-shadow: 4px 4px 15px 2px rgba(23, 31, 70, 0.12);
    border-radius: 5px;
    right: 2rem;
    z-index: 10;
    min-width: 12rem;
    top: 0;
  }

  .element {
    font-family: "Nunito", sans-serif;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.25px;
    /* Black */
    color: #2a2f34;
    padding: 0.5rem 1rem;
    display: flex;
    align-items: center;
  }
  .elementC {
    justify-content: start;
  }

  .scrollable {
    overflow-y: scroll;
    height: 150px;
  }

  .dropdown-content div:hover {
    /* background: #e9f1fa; */
  }
  .unclickable {
    cursor: not-allowed;
  }
  .dropdown {
    position: relative;
  }

  .dropdown-content-filter {
    position: absolute;
    right: -0.1rem !important;
    z-index: 99999 !important;
    min-width: 7.5rem !important;
    top: 36px !important;
  }

  .tooltip {
    position: relative;
  }
  .tooltip .tooltiptext {
    visibility: hidden;
    width: 100%;
    background-color: black;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 6px 0;
    position: absolute;
    z-index: 1;
    bottom: 110%;
    left: 0%;
    right: 0%;
    font-size: 10px;
  }
  .tooltip .tooltiptext::after {
    content: "";
    position: absolute;
    top: 100%;
    left: 50%;
    margin-left: -5px;
    border-width: 5px;
    border-style: solid;
    border-color: black transparent transparent transparent;
  }
  .tooltip:hover .tooltiptext {
    visibility: visible;
  }

  .width19 {
    width: 19%;
  }

  @media screen and (max-width: 767px) {
    .ck-requestor-dropdown-content {
      right: 1rem;
      min-width: 10rem;
    }
  }

  @media screen and (max-width: 400px) {
    .ck-requestor-dropdown-content {
      min-width: 8rem;
    }
  }
</style>
