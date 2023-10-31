<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  export let title = "";

  let modal;

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" bind:this={modal}>
    <div class="modal-content">
      <div class="close" on:click={close}>
        <FAIcon icon="times-circle" iconStyle="solid" iconSize="large" />
      </div>
      {#if title}
        <div class="modal-header">
          {title}
        </div>
      {/if}

      <slot />
    </div>
  </div>
</div>

<style>
  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 9998;
  }

  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 50%;
    min-width: fit-content;
    height: auto;
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 10px;
    background: #ffffff;
    border-radius: 5px;
    z-index: 9999;
    padding-top: 0;
  }

  .modal-content {
    padding: 0.5rem;
    display: flex;
    flex-direction: column;
    position: relative;
    font-family: "Nunito", sans-serif;
  }
  .close {
    position: absolute;
    top: 15px;
    right: 0px;
    cursor: pointer;
    color: #2a2f34;
  }
  .modal-header {
    font-size: 18px;
    font-weight: bold;
    padding: 5px 0;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    color: #2a2f34;
    margin-bottom: 1rem;
  }

  /* .modal-header{
    display: ;
  } */

  @media only screen and (max-width: 780px) {
    .modal {
      width: calc(100% - 3rem);
    }
  }
</style>
