<script>
  import TextField from "../../components/TextField.svelte";
  import LoadingButton from "../../atomic/LoadingButton.svelte";
  import Logo from "./Logo.svelte";

  let signHash;
  let pressed = false;

  const handleSignatureVerify = (event) => {
    document.location = document.location.href.replace(
      document.location.pathname,
      "/verify/signature/" + signHash
    );
  };
</script>

<div class="container">
  <Logo />
  <div class="signature-container__box">
    <div class="field">
      <h1 class="title has-text-centered">Signature Verification</h1>
      <h2 class="subtitle has-text-centered">
        Enter the unique signature hash (numeric code) from a Boilerplate
        signature stamp to access transaction details and check its validity.
      </h2>
    </div>
    <div style="margin-bottom: 20px;">
      <TextField bind:value={signHash} text="In the form of BP-abcdef123456" />
    </div>

    <div class="button">
      <span on:click={handleSignatureVerify}>
        <LoadingButton bind:pressed text="Verify Signature" />
      </span>
    </div>
  </div>
</div>

<style>
  .container {
    width: 100%;
    height: 100%;
    background-color: #fcfdff;
  }

  .signature-container__box {
    width: 70%;
    margin: auto;
    font-family: sans-serif;
    font-style: normal;
    font-weight: normal;
    text-align: center;

    color: #000000;
  }

  .title {
    margin-top: 0px;
    font-weight: 600;
    font-size: 48px;
    line-height: 56px;

    color: #363636;
  }

  .subtitle {
    font-size: 22px;
    line-height: 26px;
    color: #515249;
  }

  .title,
  .subtitle {
    word-break: break-word;
  }

  .button {
    text-align: center;
    margin-top: 1rem;
  }
</style>
