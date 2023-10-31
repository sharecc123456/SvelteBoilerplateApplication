<script>
  import Button from "../atomic/Button.svelte";
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import PdfPageNavigation from "../components/PdfPageNavigation.svelte";
  import MediaQuery from "../util/MediaQuery.svelte";
  import { createEventDispatcher, onMount } from "svelte";
  let dispatch = createEventDispatcher();

  export let leftButtons = [{ button: "Back", evt: "back", disabled: true }];

  export let rightButtons = [{ button: "Next", evt: "next", disabled: false }];

  export let centerButtons = [{ button: "Fill", evt: "edit", ignore: true }];

  $: pdfPageNavigationLeft = (windowInnerWidth - elmWidth) / 2 - 15;
  let elmWidth, navbar;
  export let IACDoc = false,
    containerClasses = "",
    navbarClasses = "";
  export let currentPage,
    pageCount,
    windowInnerWidth,
    hasPageNavigation = false;

  $: navOffsetHeight = 0;
  const vw = Math.max(
    document.documentElement.clientWidth || 0,
    window.innerWidth || 0
  );
</script>

<div class="container {containerClasses}" bind:clientHeight={navOffsetHeight}>
  <div class="navbar {navbarClasses}" bind:this={navbar} id="bottom-nav">
    <div class:IACDocLeft={IACDoc} class="left">
      {#each leftButtons as b}
        {#if !b.ignore}
          <span
            class:IACDocMarginRight={IACDoc}
            on:click={() => {
              dispatch(b.evt);
            }}
          >
            <Button
              text={b.button}
              disabled={b.disabled}
              color={b.color ? b.color : "primary"}
              showTooltip={b.showTooltip}
              tooltipMessage={b.tooltipMessage}
            />
          </span>
        {/if}
      {/each}
    </div>
    <div class="center items-center">
      {#each centerButtons as b}
        {#if !b.ignore}
          <span
            class:leftMargin={b?.leftMargin}
            on:click={() => {
              if (!b.disabled) {
                dispatch(b.evt);
              }
            }}
          >
            {#if b.loading}
              <LoadingButton
                text={b.button}
                disabled={b.disabled}
                color={b.color ? b.color : "primary"}
              />
            {:else}
              <Button
                text={b.button}
                disabled={b.disabled}
                color={b.color ? b.color : "primary"}
                icon={b?.icon ? b?.icon : ""}
                showTooltip={b.showTooltip}
                tooltipMessage={b.tooltipMessage}
              />
            {/if}
          </span>
        {/if}
      {/each}
    </div>

    {#if hasPageNavigation}
      <!-- desktop-->
      <MediaQuery query="(min-width: 1281px)" let:matches>
        {#if matches}
          <span
            class="pdf-page-navigator-wrapper"
            style="left: {pdfPageNavigationLeft}px; --bottom: {vw > 767
              ? navOffsetHeight
              : navOffsetHeight - 36}px"
          >
            <PdfPageNavigation
              currentPage={currentPage + 1}
              totalPage={pageCount}
              on:next
              on:prev
              on:pageForwarder
              bind:elmWidth
            />
          </span>
        {/if}
      </MediaQuery>
      <!-- tablet -->
      <MediaQuery
        query="(min-width: 481px) and (max-width: 1280px)"
        let:matches
      >
        {#if matches}
          <span>
            <PdfPageNavigation
              currentPage={currentPage + 1}
              totalPage={pageCount}
              on:next
              on:prev
              on:pageForwarder
              bind:elmWidth
            />
          </span>
        {/if}
      </MediaQuery>
    {/if}
    <div class:IACDocRight={IACDoc} style={IACDoc && ""} class="right">
      <slot name="right-slot-start" />
      {#each rightButtons as b}
        {#if !b.ignore}
          <span
            class:IACDocMarginRight={IACDoc}
            on:click={() => {
              if (!b.disabled) {
                dispatch(b.evt);
              }
            }}
          >
            {#if b.loading}
              <LoadingButton
                text={b.button}
                disabled={b.disabled}
                color={b.color ? b.color : "primary"}
              />
            {:else}
              <Button
                text={b.button}
                disabled={b.disabled}
                color={b.color ? b.color : "primary"}
                showTooltip={b.showTooltip}
                icon={b?.icon ? b?.icon : ""}
                tooltipMessage={b.tooltipMessage}
                style={b.style || ""}
              />
            {/if}
          </span>
        {/if}
      {/each}
    </div>
  </div>
</div>

<style>
  .container {
    background: #f0f5fb;
    opacity: 0.9;
    box-shadow: 0px -7px 20px rgba(0, 0, 0, 0.08);

    /* overflow: hidden; */
    position: fixed;
    bottom: 0;
    width: 100%;
    z-index: 1;
    left: 0;
  }

  .navbar {
    display: flex;
    flex-flow: row nowrap;
    padding: 1rem;
    align-items: center;
    justify-content: space-between;
  }

  .right {
    display: flex;
  }

  .center {
    display: flex;
  }

  .pad {
    margin: 5px;
  }

  .right > * {
    margin-left: 7px;
  }

  .center > * {
    margin-left: 10px;
  }
  .left {
    display: flex;
  }

  .left > * {
    margin-right: 10px;
  }

  .leftMargin {
    margin-left: 25%;
  }
  .h-3 {
    height: 3.5rem;
  }
  .h-4 {
    height: 4rem;
  }
  .p-0 {
    padding: 0 !important;
  }
  .gap-0 {
    gap: 0 !important;
  }
  .px-1 {
    padding: 1rem 0 !important;
  }
  .px-3 {
    padding: 3rem 0 !important;
  }

  .pt-8 {
    padding-top: 2rem;
  }

  .pb-12 {
    padding-bottom: 3rem;
  }
  .container-flex-end {
    display: flex;
    align-items: flex-end;
    justify-content: center;
  }

  .pdf-page-navigator-wrapper {
    position: fixed;
    z-index: 99;
    bottom: var(--bottom, 3rem);
  }
  @media screen and (min-width: 768px) {
    .pdf-page-navigator-wrapper {
      bottom: 1rem;
    }
  }
  @media screen and (max-width: 767px) {
    .navbar {
      flex-direction: column;
      flex-flow: column;
      padding: 1rem;
      gap: 0.5rem;
    }

    .left,
    .right {
      width: 100%;
      justify-content: center;
      gap: 0.3rem;
      align-items: center;
    }
    .px-1 {
      padding: 1rem 0 !important;
    }
    span {
      width: 100%;
    }
    .left > *,
    .right > *,
    .center > * {
      margin: 0;
    }

    .pdf-page-navigator-wrapper {
      bottom: var(--bottom, 3rem);
    }
  }
</style>
