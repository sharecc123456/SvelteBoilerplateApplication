<script>
  import LoadingButton from "Atomic/LoadingButton.svelte";
  let pressed = false;

  const handleAccept = async () => {
    window.location.href = "/terms/accept";
  };
</script>

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>
  <div class="card">
    <h1>Terms of Service</h1>
    <p>
      In order to use Boilerplate, we need your acceptance of our <a
        class="has-text-info"
        href="/terms"
        target="_blank">Terms of Service</a
      >
      and our
      <a
        class="has-text-info"
        href="https://boilerplate.co/privacy-policy"
        target="_blank">Privacy Policy</a
      >.
    </p>
    <div class="button" on:click={handleAccept}>
      <LoadingButton bind:pressed text="Accept & Continue" />
    </div>
  </div>
</div>

<style>
  .container {
    max-width: 1000px;
    margin: 0 auto;
    padding: 2rem;
  }

  .logo {
    max-width: 400px;
    margin: 0 auto;
    padding: 1rem;
  }

  .logo img {
    width: 100%;
  }

  .card {
    box-shadow: rgba(0, 0, 0, 0.24) 0px 3px 8px;
    padding: 1rem;
    border-radius: 10px;
    margin: 2rem auto;
    font-family: "Nunito", sans-serif;
  }

  .card h1 {
    text-align: center;
    margin: 0;
    padding: 0;
    margin-bottom: 0.6rem;
  }

  .card p {
    margin: 0;
    padding: 0;
    text-align: center;
  }

  .button {
    margin-top: 1rem;
    display: grid;
    place-items: center;
  }

  @media only screen and (max-width: 767px) {
    .card h1 {
      font-size: 18px;
      line-height: 20px;
    }

    .card {
      font-size: 14px;
      line-height: 20px;
    }
  }
</style>
