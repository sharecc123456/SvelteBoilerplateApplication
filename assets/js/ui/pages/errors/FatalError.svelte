<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Button from "../../atomic/Button.svelte";
  export let icon;
  export let message;

  function back() {
    window.location = "/";
  }
</script>

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="icon">
    <FAIcon {icon} />
  </div>

  <div class="header">Oops!</div>

  <div class="text">{message}</div>

  <div class="button">
    <span on:click={back}>
      <Button text="Back to the Homepage" />
    </span>
  </div>
</div>

<style>
  .button {
    padding-top: 4rem;
  }
  .icon {
    font-size: 60px;
    color: #2a2f34;
  }
  .text {
    font-family: "Nunito", sans-serif;
    font-size: 20px;
    line-height: 30px;
    margin-top: 6rem;
    color: #2a2f34;
  }
  .logo {
    width: 15%;
    padding-bottom: 5rem;
  }

  .logo > img {
    width: 100%;
  }
  .header {
    text-align: center;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 60px;
    color: #2a2f34;
  }
  .container {
    position: fixed;
    top: 0;
    left: 0;
    display: flex;
    flex-flow: column nowrap;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100%;
    background-color: #fcfdff;
  }
</style>
