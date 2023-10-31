<script>
  import { createEventDispatcher } from "svelte";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;

  export let title = "";

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          {title}
          <span on:click={close}>
            <slot name="closer" />
          </span>
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>
      </div>
    </div>
    <slot />
  </div>
</div>

<style>
  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 98;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 90%;
    height: 80%;
    min-width: fit-content;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 999;
    padding-top: 0;
    overflow-y: scroll;
    overflow-x: hidden;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-direction: column;
  }

  .inner-content {
    position: sticky;
    top: 0;
    z-index: 10;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    padding-right: 0.6875em;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
  }

  .modal-x {
    font-size: 24px;
    left: calc(100% - 4em);
    top: 0.85em;
    cursor: pointer;
  }
</style>
