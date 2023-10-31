<script>
  import LoadingButton from "../../atomic/LoadingButton.svelte";
  import Button from "../../atomic/Button.svelte";
  import Checkbox from "Components/Checkbox.svelte";
  import { userMfaUpdate } from "BoilerplateAPI/User";
  import TextField from "Components/TextField.svelte";
  export let recipient_uid = 0;
  export let mfa_type = "phone";
  let mfa_verification_code = "";
  let mfa_remember = false;
  let showBad = false,
    buttonLoading = false,
    showResent = false;
  userMfaUpdate(recipient_uid, 10);

  async function verify() {
    showBad = false;
    showResent = false;
    userMfaUpdate(recipient_uid, 11, {
      code: mfa_verification_code,
      remember: mfa_remember,
    }).then((x) => {
      if (x.ok) {
        window.location.reload();
      } else {
        showBad = true;
        buttonLoading = false;
      }
    });
  }

  function resend() {
    showResent = true;
    showBad = false;
    userMfaUpdate(recipient_uid, 10);
  }
</script>

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>
  <h1>Multi-Factor Authentication</h1>
  <div class="field">
    <p class="name">
      {#if mfa_type == "phone"}
        This is an unrecognized login. We have sent a text message containing a
        verification code to your registered phone number. Please enter the code
        below to proceed with your login. If you do not have access to your
        phone, or have lost it, please contact support@boilerplate.co
      {:else}
        This is an unrecognized login. Please use your authenticator app to
        generate a 6 digit code and enter it below to proceed with your login.
        If you do not have access to your authenticator, or have lost it, please
        contact support@boilerplate.co
      {/if}
    </p>
  </div>
  {#if showResent}
    <div class="field">
      <p class="name">Code was resent!</p>
    </div>
  {/if}
  {#if showBad}
    <div class="field">
      <p class="name" style="color: red;">Invalid Verification Code.</p>
    </div>
  {/if}
  <div class="field">
    <TextField bind:value={mfa_verification_code} text="Verification Code" />
  </div>
  <div class="field">
    <Checkbox
      bind:isChecked={mfa_remember}
      text="Remember this computer for one day? (Do not use on shared computers.)"
    />
  </div>
  <div class="field buttons">
    <span on:click={verify}>
      <LoadingButton bind:pressed={buttonLoading} text="Login" />
    </span>
    {#if mfa_type == "phone"}
      <span on:click={resend} style="padding-left: 1rem;">
        <Button text="Resend" color="white" />
      </span>
    {/if}
  </div>
</div>

<style>
  .logo {
    width: 25%;
    padding-bottom: 5rem;
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
  }

  .name {
    font-family: "Nunito", sans-serif;
    font-weight: 200;
    font-size: 18px;
    line-height: 26px;
    color: #2a2f34;
  }

  .field {
    padding-bottom: 1rem;
    max-width: 75%;
    text-align: center;
  }

  .field.buttons {
    display: flex;
    flex-flow: row nowrap;
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
    overflow: auto;
  }

  @media only screen and (max-width: 767px) {
    .container {
      width: auto;
      justify-content: start;
    }

    .logo {
      padding-top: 1rem;
      padding-bottom: 1rem;
    }

    h1 {
      font-size: 22px;
    }
    .field {
      max-width: 80%;
    }
  }
</style>
