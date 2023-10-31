<script>
  import { createEventDispatcher, onDestroy, onMount } from "svelte";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");
  export let maxWidth = null;
  export let modalHeader = "When does this expire?";

  let modal;

  //-- let the popup make draggable & movable.
  var popup;
  var offset = { x: 0, y: 0 };
  onMount(() => {
    popup = document.getElementById("modal");
    console.log(popup);
    popup.addEventListener("mousedown", mouseDown, false);
    window.addEventListener("mouseup", mouseUp, false);
  });

  function mouseUp() {
    window.removeEventListener("mousemove", popupMove, true);
  }

  function mouseDown(e) {
    offset.x = e.clientX - popup.offsetLeft;
    offset.y = e.clientY - popup.offsetTop;
    window.addEventListener("mousemove", popupMove, true);
  }

  function popupMove(e) {
    popup.style.position = "absolute";
    var top = e.clientY - offset.y;
    var left = e.clientX - offset.x;
    popup.style.top = top + "px";
    popup.style.left = left + "px";
  }

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
  id="modal"
  class="modal"
  role="dialog"
  aria-modal="true"
  bind:this={modal}
  style={`max-width: ${maxWidth ? maxWidth : "32rem"}`}
>
  <div class="modal-content">
    <span class="modal-header">{modalHeader}</span>
    <slot />

    <span on:click={close}>
      <slot name="closer" />
    </span>

    <div on:click={close} class="modal-x">
      <i class="fas fa-times" />
    </div>
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
    z-index: 11;
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
    width: calc(100vw - 4em);
    max-width: 32em;
    max-height: calc(100vh - 4em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 12;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    cursor: move;
  }

  .modal-x {
    position: absolute;
    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;

    cursor: pointer;
  }

  @media only screen and (max-width: 640px) {
    .modal {
      top: 40%;
      width: calc(100vw - 5em);
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
