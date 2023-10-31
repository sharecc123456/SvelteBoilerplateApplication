<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import TextField from "../components/TextField.svelte";
  import Button from "../atomic/Button.svelte";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");
  const getTextSignature = () =>
    dispatch("signature", {
      value: textSignature,
    });

  export let title = "";
  export let placeholder = "Placeholder text...";
  let textSignature;
  let errorText = "";
  let isError = false;

  const handleSubmit = () => {
    if (
      !textSignature ||
      textSignature.trim().length === 0 ||
      !textSignature.replace(/\s/g, "").length
    ) {
      isError = true;
      errorText = "Field cannot be empty, please type your FULL name.";
      return;
    } else if (textSignature.length > 30) {
      isError = true;
      errorText = "Name cannot be longer than 30 characters.";
      return;
    } else if (!/^[a-zA-Z'\-,.‘’`\ ]+$/.test(textSignature)) {
      isError = true;
      errorText = "The name must not contain any special characters.";
      return;
    }

    isError = false;
    getTextSignature();
    close();
  };

  let modal;

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }

    if (e.key === "Enter") {
      handleSubmit();
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

      <div class="content-container">
        <TextField bind:value={textSignature} text={placeholder} />
        <span
          class="button"
          on:click={() => {
            handleSubmit();
          }}
        >
          <Button color="primary" text="Submit" />
        </span>
      </div>
      {#if isError}
        <span class="error-text">{errorText}</span>
      {/if}
    </div>
  </div>
</div>

<style>
  .error-text {
    color: rgba(253, 0, 0, 0.719);
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
  }
  .content-container {
    display: flex;
    align-items: center;
  }

  .button {
    margin-left: 16px;
  }
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
    width: auto;
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
