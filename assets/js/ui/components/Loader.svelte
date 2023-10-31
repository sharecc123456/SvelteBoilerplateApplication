<script>
  import { onMount, onDestroy } from "svelte";

  export let loading = false;
  export let absoluteLoader = false;

  let timer = null;
  let somethingWrong = false;

  onMount(() => {
    let timer = setTimeout(() => {
      somethingWrong = true;
    }, 10000);
  });

  onDestroy(() => {
    console.log("[loader] loading exiting");
    clearTimeout(timer);
  });
</script>

{#if loading}
  <div class="loader" class:absoluteLoader>
    <div class="lds-dual-ring" />
    {#if somethingWrong}
      <div class="warning">
        It looks like something went wrong. It may be your internet connection,
        or our system. Please restart your browser and try again in a few
        minutes. If the issue continues, please contact support@boilerplate.co
        or use the blue chat button in the bottom right. Thank you
      </div>
    {/if}
  </div>
{/if}

<style>
  .warning {
    max-width: 70%;
    text-align: center;
    line-height: 36px;
    color: #c31900;
  }

  .loader {
    min-height: 200px;
    width: 100%;
    display: grid;
    place-items: center;
  }

  .absoluteLoader {
    position: absolute;
    top: 20%;
  }

  .lds-dual-ring {
    display: inline-block;
    width: 80px;
    height: 80px;
  }
  .lds-dual-ring:after {
    content: " ";
    display: block;
    width: 64px;
    height: 64px;
    margin: 8px;
    border-radius: 50%;
    border: 6px solid rgb(22, 22, 24);
    border-color: rgb(22, 22, 24) transparent rgb(22, 22, 24) transparent;
    animation: lds-dual-ring 1.2s linear infinite;
  }
  @keyframes lds-dual-ring {
    0% {
      transform: rotate(0deg);
    }
    100% {
      transform: rotate(360deg);
    }
  }
</style>
