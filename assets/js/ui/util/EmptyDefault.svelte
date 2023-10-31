<script>
  import { nanoid } from "nanoid";
  import { onMount } from "svelte";
  import { createEventDispatcher } from "svelte";
  const dispatch = createEventDispatcher();

  import FAIcon from "../atomic/FAIcon.svelte";

  export let defaultHeader = "Header Text";
  export let defaultMessage =
    "Main Body text, if you see this, theres a problem";
  export let error = null;
  export let cancelButton = false;
  const close = () => dispatch("close");
  let errorId = null;
  onMount(() => {
    if (error) {
      errorId = nanoid();
      console.error(errorId);
    }
  });
</script>

<div class="bp-container">
  <div class="bp-box">
    <p class="bp-header">
      <span>
        {defaultHeader}
      </span>
      {#if cancelButton}
        <span style="cursor: pointer;" on:click={close}>
          <FAIcon
            color={true}
            icon="times-circle"
            iconStyle="solid"
            iconSize="large"
          />
        </span>
      {/if}
    </p>
    <span class="bp-line" />
    <p class="bp-text">{defaultMessage}</p>
    {#if error}
      <small>
        Error ID: {errorId}
      </small>
    {/if}
  </div>
</div>

<style>
  .bp-container {
    /* Upload a document NEW*/
    display: flex;
    justify-content: center;
    align-items: center;
    background-color: #f8fafd;
    min-height: 250px;
  }

  .bp-box {
    /* White */
    background: #ffffff;
    /* Gray 300 */
    border-radius: 10px;
    flex-direction: column;
    align-items: flex-start;
    max-width: 500px;
    padding: 1rem;
    box-shadow: rgba(100, 100, 111, 0.2) 0px 7px 29px 0px;
  }

  .bp-line {
    /* Line 75 */
    display: flex;
    flex-flow: column nowrap;
    align-items: center;
    width: 100%;
    border-bottom: 0.5px solid #b3c1d0;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
  }

  .bp-text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;
    /* or 150% */
    letter-spacing: 0.5px;

    /* Gray 700 */
    color: #606972;
    margin-bottom: 0;
  }

  .bp-header {
    display: flex;
    justify-content: space-between;

    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: bold;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.5px;
    color: #202e3b;
    margin: 0 auto;
  }
  small {
    display: block;
    margin-top: 1rem;
  }
</style>
