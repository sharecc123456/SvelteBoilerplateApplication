<script>
  import MediaQuery from "../util/MediaQuery.svelte";

  export let modal;
</script>

<MediaQuery query="(min-width: 1281px)" let:matches>
  {#if matches}
    <div
      class="modal-common modal-desktop"
      role="dialog"
      aria-modal="true"
      bind:this={modal}
    >
      <slot />
    </div>
  {/if}
</MediaQuery>

<MediaQuery query="(min-width: 481px) and (max-width: 1280px)" let:matches>
  {#if matches}
    <div
      class="modal-common modal-tablet"
      role="dialog"
      aria-modal="true"
      bind:this={modal}
    >
      <slot />
    </div>
  {/if}
</MediaQuery>

<MediaQuery query="(max-width: 480px)" let:matches>
  {#if matches}
    <div
      class=" modal-common modal-mobile"
      role="dialog"
      aria-modal="true"
      bind:this={modal}
    >
      <slot />
    </div>
  {/if}
</MediaQuery>

<style>
  .modal-common {
    position: absolute;
    left: 50%;
    top: 50%;
    min-width: fit-content;
    max-height: 80%;
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 999;
    padding-top: 0;
  }
  .modal-desktop {
    width: 60%;
  }

  .modal-tablet {
    width: 80%;
  }

  .modal-mobile {
    width: 100%;
  }
</style>
