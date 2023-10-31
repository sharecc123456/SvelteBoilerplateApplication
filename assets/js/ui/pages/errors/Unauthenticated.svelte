<script>
  import Button from "../../atomic/Button.svelte";
</script>

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>
  <h1>Session Expired</h1>
  <div class="field">
    <p class="name">
      For security purposes, you must re-authenticate every 12 hours. Please
      enter your credentials to log back in.
    </p>
  </div>
  <div class="field">
    <a style="text-decoration: none;" href="/n/login">
      <Button text="Login" />
    </a>
  </div>
</div>

<style>
  .logo {
    width: 30%;
    padding-bottom: 2rem;
  }

  .logo > img {
    width: 100%;
  }

  h1 {
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 44px;
    line-height: 54px;
    color: #2a2f34;
    margin-bottom: 0px;
  }

  .name {
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 20px;
    line-height: 34px;
    color: #2a2f34;
  }

  .field {
    padding-bottom: 1rem;
    max-width: 70%;
    text-align: center;
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
