<script>
  import { onDestroy, onMount } from "svelte";
  import { COUNTDOWN_MIN } from "../../helpers/autologout";
  import Button from "../atomic/Button.svelte";

  export let setLogoutWarning = () => {};
  export let handleLogout = () => {};

  let seconds = COUNTDOWN_MIN * 60;
  let counter;

  onMount(() => {
    counter = setInterval(() => {
      seconds = seconds - 1;
    }, 1000);
  });

  onDestroy(() => {
    clearInterval(counter);
  });

  const handleCountOver = (s) => {
    if (s == 1) {
      handleLogout();
      return;
    }
  };
  $: handleCountOver(seconds);
</script>

<div class="wrapper">
  <div class="content">
    <h1>
      Warning! Due to inactivity, you will be logged out in <span class="second"
        >{seconds}</span
      > seconds.
    </h1>
    <div class="action" on:click={() => setLogoutWarning(false)}>
      <Button text="Keep me logged in" color="primary" />
    </div>
  </div>
</div>

<style>
  .wrapper {
    position: fixed;
    top: 0px;
    left: 0px;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.5);
    z-index: 9999999;
    display: grid;
    place-items: center;
    font-family: "Nunito", sans-serif;
  }

  .content {
    background: white;
    padding: 1em;
    border-radius: 15px;
  }

  .second {
    color: red;
  }

  .action {
    width: max-content;
    margin: auto;
  }

  @media only screen and (max-width: 768px) {
    .wrapper {
      display: flex;
      flex-direction: column;
      justify-content: flex-end;
    }
    .content {
      border-bottom-right-radius: 0;
      border-bottom-left-radius: 0;
      padding-inline: 4rem;
    }

    .content h1 {
      font-size: 1.1rem;
      text-align: center;
    }
  }
</style>
