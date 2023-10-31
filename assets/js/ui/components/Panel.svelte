<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";

  export let style = "";
  export let title = "";
  export let headerClasses = "";
  export let headerLeftClasses = "";
  export let collapsible = false;
  export let collapsed = false;
  export let custom_toolbar = false;
  export let custom_title = false;
  export let allowHandleHeaderClick = false;
  export let allowHandlePanelClick = false;
  export let disableCollapse = false;
  export let has_z_index = false;
  export let classes = "";
  export let innerContentClasses = "";

  let innerContent,
    dispatch = createEventDispatcher();

  function handleCollapse() {
    if (disableCollapse) {
      return;
    }
    collapsed = !collapsed;
  }
  function handleHeaderMenuClick() {
    if (allowHandleHeaderClick) {
      dispatch("header_click");
    }
  }
  function handlePanelClick() {
    if (allowHandlePanelClick) {
      dispatch("panel_click");
    }
  }
  $: {
    if (innerContent) {
      if (collapsed) {
        setTimeout(() => {
          if (innerContent && innerContent.style) {
            innerContent.style.visibility = "visible";
          }
        }, 300);
      } else {
        if (innerContent && innerContent.style) {
          innerContent.style.visibility = "hidden";
        }
      }
    }
  }
</script>

<div
  class="panel {collapsible ? 'collapsible' : ''} {collapsed
    ? 'collapsed'
    : ''} {has_z_index ? 'has-z-index' : ''} {classes}"
  {style}
  on:click={handlePanelClick}
>
  <slot name="top_title" />
  {#if title}
    <div class="header {headerClasses}" on:click={handleHeaderMenuClick}>
      <div class="left {headerLeftClasses}">
        {#if custom_title}
          <slot name="custom-title" />
        {:else}
          <h3 style="color: var(--text-secondary);">{title}</h3>
        {/if}
      </div>
      {#if collapsible}
        <div
          class="right cursor-pointer"
          on:click|stopPropagation={handleCollapse}
        >
          {#if custom_toolbar}
            <slot name="custom-toolbar" />
          {:else if collapsed}
            <FAIcon style="solid" icon="angle-up" iconSize="2x" />
          {:else}
            <FAIcon style="solid" icon="angle-down" iconSize="2x" />
          {/if}
        </div>
      {/if}
    </div>
  {/if}
  <slot name="sub-header" />
  <div
    bind:this={innerContent}
    class="inner-content {collapsed
      ? 'hidden-visibility'
      : 'display-none'} {innerContentClasses}"
  >
    <slot />
  </div>
</div>

<style>
  .collapsible {
    max-height: 3rem;
    /* overflow: hidden; */
  }

  .has-z-index {
    z-index: -1;
  }

  .max-height-4 {
    max-height: 4rem;
  }
  .max-height-5 {
    max-height: 5rem;
  }
  .max-height-6 {
    max-height: 6rem;
  }
  .max-height-7 {
    max-height: 7rem;
  }
  .max-height-8 {
    max-height: 8rem;
  }
  .max-height-9 {
    max-height: 9rem;
  }
  .max-height-10 {
    max-height: 10rem;
  }
  .max-height-20 {
    max-height: 20rem;
  }

  .collapsed {
    max-height: 1000rem;
  }
  .inner-content {
    transition: all 0.1s ease-in-out;
  }
  .m-0 {
    margin: 0;
  }
  .display-none {
    display: none;
  }
  .hidden-visibility {
    visibility: hidden;
  }
  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0;
  }
  .left {
    font-family: "Nunito", sans-serif;
    width: 90%;
  }
  .flex-2 {
    flex: 2;
  }
  .right{
    align-self: flex-start;
  }
  .cursor-pointer {
    cursor: pointer;
  }

  @media only screen and (max-width: 767px) {
    .left {
      width: 100%;
    }

    h3 {
      margin: 0;
    }

    .panel {
      padding: 1.5rem 2rem 1.5rem;
      width: calc(100% - 4rem);
      background: #ffffff;
      border-radius: 10px;
      transition: all 0.5s ease-in-out;
      position: relative;
    }
  }

  @media only screen and (min-width: 768px) {
    .panel {
      padding: 1.5rem 2rem 1.5rem;
      width: calc(100% - 4rem);
      background: #ffffff;
      border-radius: 10px;
      transition: all 0.5s ease-in-out;
      position: relative;
      box-shadow: rgba(100, 100, 111, 0.2) 0px 7px 29px 0px;
      margin-bottom: 0.5rem;
    }
  }
</style>
