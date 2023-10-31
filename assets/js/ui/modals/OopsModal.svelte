<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";

  const dispatch = createEventDispatcher();
  const close = () => {
    // lol wtf
    let container = document.getElementById("boilerplate-error-container");
    container.innerHTML = "";
    dispatch("close");
  };

  let modal;

  const handle_keydown = (e) => {
    if (e.key !== "Tab") {
      close();
      return;
    }

    if (e.key === "Tab") {
      // trap focus
      const nodes = modal.querySelectorAll("*");
      const tabbable = Array.from(nodes).filter((n) => n.tabIndex >= 0);

      let index = tabbable.indexOf(document.activeElement);
      if (index === -1 && e.shiftKey) index = 0;

      index += tabbable.length + (e.shiftKey ? -1 : 1);
      index %= tabbable.length;

      tabbable[index].focus();
      e.preventDefault();
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  export let title = "Nope";
  export let message = "God bless.";
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    <span class="modal-icon">
      <FAIcon icon="exclamation-triangle" />
    </span>

    <span class="modal-header">{title}</span>

    <span class="modal-message">
      {message}
    </span>

    <div on:click={close} class="modal-x">
      <i class="fas fa-times" />
    </div>
  </div>
</div>

<style>
  .modal-icon {
    text-align: center;
    width: 100%;
    font-size: 60px;
    color: #2a2f34;
  }

  .modal-message {
    text-align: center;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 400;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 998;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    text-align: center;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    width: calc(100vw - 4em);
    max-width: 32em;
    max-height: calc(100vh - 4em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 999;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-flow: column nowrap;
  }

  .modal-x {
    position: absolute;

    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;

    cursor: pointer;
  }
</style>
