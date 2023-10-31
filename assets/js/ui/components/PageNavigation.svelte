<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";

  export let firstPage, lastPage, currentPage, pageCount, pageLoading;
  let dispatch = createEventDispatcher();
</script>

{#if !pageLoading}
  <div class="desktop-only left">
    <div
      on:click={() => {
        dispatch("doPrevPage");
      }}
      style="cursor: pointer;"
      class="left-actions {currentPage == 0 || firstPage ? 'disabled' : ''}"
    >
      <span><FAIcon icon="angle-left" iconStyle="light" iconSize="5x" /> </span>
    </div>
  </div>
  <div class="desktop-only right">
    <div
      on:click={() => {
        dispatch("doNextPage");
      }}
      style="cursor: pointer;"
      class="right-actions {currentPage == pageCount - 1 || lastPage
        ? 'disabled'
        : ''}"
    >
      <span
        ><FAIcon icon="angle-right" iconStyle="light" iconSize="5x" />
      </span>
    </div>
  </div>

  <div class="mobile-only">
    <div
      class="left-actions {currentPage == 0 || firstPage ? 'disabled' : ''}"
      on:click={() => {
        dispatch("doPrevPage");
      }}
      style="cursor: pointer;"
    >
      <FAIcon icon="angle-left" iconStyle="light" iconSize="2x" />
    </div>

    <div
      on:click={() => dispatch("doNextPage")}
      style="cursor: pointer;"
      class="right-actions {currentPage == pageCount - 1 || lastPage
        ? 'disabled'
        : ''}"
    >
      <FAIcon icon="angle-right" iconStyle="light" iconSize="2x" />
    </div>
  </div>
{/if}

<style>
  .left-actions {
    color: #808080;
    z-index: 1;
    position: relative;
  }
  .left-actions::after {
    font-family: "Nunito", sans-serif;
    content: "Prev Page";
    white-space: nowrap;
    min-width: 6rem;
  }
  .right-actions {
    color: #808080;
    text-align: right;
    position: relative;
  }

  .right-actions::after {
    font-family: "Nunito", sans-serif;
    white-space: nowrap;
    content: "Next Page";
    min-width: 6rem;
  }
  .disabled {
    color: #e6e6e6;
    pointer-events: none;
  }
  .mobile-only {
    display: none;
  }

  /* .desktop-only {
    position: sticky;
  } */
  .left,
  .right {
    /* top: 45%; */
    width: 2rem;
    display: flex;
    height: 100vh;
    align-items: center;
    position: sticky;
    top: 0;
  }
  .left {
    order: 0;
    text-align: left;
  }
  .right {
    order: 3;
    justify-content: flex-end;
    /* left: calc(100% - 2rem); */
  }

  @media only screen and (max-width: 767px) {
    .left-actions {
      position: absolute;
      top: 40%;
      left: -0.5rem;
      color: #fefefe;
      background: #0e0e0e;
      width: 2rem;
      height: 2rem;
      border-radius: 50%;
      text-align: center;
    }
    .right-actions {
      position: absolute;
      top: 40%;
      right: -0.5rem;
      color: #fefefe;
      background: #0e0e0e;
      width: 2rem;
      height: 2rem;
      border-radius: 50%;
      text-align: center;
    }
    .disabled {
      background: #e6e6e6;
      pointer-events: none;
    }
    .left-actions::after {
      content: "";
    }
    .right-actions::after {
      content: "";
    }
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
  }
</style>
