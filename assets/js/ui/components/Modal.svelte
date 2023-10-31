<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");
  export let maxWidth = null;

  let modal;
  // minimizeModal = true will make Modal Display: none;
  let minimizeModal = false;
  // Text we are going to display on minimized Text."
  export let minimizeModalText = "";
  // In Order to show minimize icon pass "showMinimizeModal = true;"
  export let showMinimizeModal = false;

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
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
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click={close} />

<div
  class="modal"
  role="dialog"
  aria-modal="true"
  bind:this={modal}
  style={`max-width: ${maxWidth ? maxWidth : "32rem"}; display: ${
    minimizeModal ? "none" : "block"
  }`}
>
  <div class="modal-content">
    <span class="modal-header"><slot name="header" /></span>
    <slot />

    <span on:click={close}>
      <slot name="closer" />
    </span>

    {#if showMinimizeModal}
      <div
        on:click={() => {
          minimizeModal = true;
        }}
        class="modal-minus"
      >
        <i class="fa-solid fa-minus logo-color" />
      </div>
    {/if}
    <div on:click={close} class="modal-x">
      <i class="fas fa-times logo-color" />
    </div>
  </div>
</div>

{#if minimizeModal}
  <div class="minimize-tab">
    <div class="inner">
      <div>{minimizeModalText}</div>
      <div>
        <span
          on:click={() => {
            minimizeModal = false;
          }}
        >
          <i class="fa-light fa-window-maximize logo-color" />
        </span>
        <span style="margin-left:1rem;" on:click={close}>
          <i class="fas fa-times logo-color" />
        </span>
      </div>
    </div>
  </div>
{/if}

<style>
  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 9997;
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
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    max-height: calc(100vh - 4em);
    width: calc(100vw - 5em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 9998;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .modal-x {
    position: absolute;
    font-size: 24px;
    left: calc(100% - 1.5em);
    top: 0.5em;

    cursor: pointer;
  }

  .modal-minus {
    position: absolute;
    font-size: 24px;
    left: calc(100% - 3em);
    top: 0.5em;
    cursor: pointer;
  }

  .minimize-tab {
    position: fixed;
    bottom: 8.5%;
    left: 0%;
    background: white;
    z-index: 9999;
    padding: 1rem;
    border-radius: 5px;
    width: 50%;
  }

  .minimize-tab .inner {
    width: 100%;
    display: flex;
    justify-content: space-between;
    font-size: 20px;
  }
  .logo-color {
    color: #2a2f34;
  }
  @media only screen and (max-width: 640px) {
    .modal {
      top: 50%;
    }
    .modal-content {
      margin: 0;
      padding: 0;
    }
    .modal-header {
      font-size: 18px;
    }
    .modal-x {
      font-size: 18px;
    }
  }
</style>
