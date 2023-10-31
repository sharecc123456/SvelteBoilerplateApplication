<script>
  import { onMount } from "svelte";
  export let rows = 4;
  export let cols = 50;
  export let text = "";
  export let value = "";
  export let invalidInput = false;
  export let disabled = false;
  export let focused = false;
  export let elm;
  export let maxlength;

  onMount(() => {
    if (focused) {
      elm.focus();
    }
  });
</script>

<textarea
  bind:value
  class="textarea"
  class:errormessage={invalidInput}
  class:noResizeable={disabled}
  {disabled}
  bind:this={elm}
  placeholder={text}
  {rows}
  {cols}
  {maxlength}
/>
{#if !!maxlength && value?.length >= maxlength}
  <span class="alert-text">
    You reached the limit of the field. The text can't be longer than {maxlength}
    characters.
  </span>
{/if}

<style>
  .alert-text {
    color: #cc0033;
    font-size: 14px;
  }

  .textarea {
    background: #ffffff;

    width: 100%;
    text-align: left;
    /* Gray 300 */
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;
    font-family: "Nunito", sans-serif;
    padding-left: 1rem;
    overflow-y: scroll;
  }

  textarea {
    font-size: inherit;
    resize: vertical;
  }
  textarea::placeholder {
    font-size: inherit;
  }

  .noResizeable {
    resize: none;
  }

  @media only screen and (max-width: 767px) {
    textarea {
      font-size: 14px;
    }
  }
</style>
