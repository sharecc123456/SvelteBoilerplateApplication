<script>
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import TextField from "../components/TextField.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers/ToastStorage.js";
  import { sendForgotPassword } from "BoilerplateAPI/User";

  let email;
  let isErr = false;
  let errorMessage = "";

  function doForgot() {
    if (isValidEmail(email.trim())) {
      errorMessage = "";
      isErr = false;
      showToast(
        "Password reset link sent to the email provided. If you don't receive a reset email, please try again (typo) or the email may not exist in the system!",
        3000,
        "default",
        "MM"
      );
      sendForgotPassword(email.trim().toLowerCase());
      setTimeout(() => {
        window.location = "/login";
      }, 3000);
    } else {
      isErr = true;
      errorMessage = `Please enter a valid email address.`;
    }
  }

  const isValidEmail = (email) => {
    return email.match(
      /^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
    );
  };
</script>

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="header">Password Reset</div>
  <div class="text">
    If you've forgotten your password, you can enter your email address here and
    if you have an account with us, you will have an email sent to you with
    instructions to reset your password.
  </div>

  <div class="buttons password">
    <TextField
      bind:value={email}
      text="Your email address"
      icon="envelope"
      iconStyle="regular"
    />
  </div>

  <div class="error">{errorMessage}</div>

  <div class="buttons">
    <span on:click={doForgot}>
      <LoadingButton
        text="Send Password Reset Link"
        disabled={email == null || email == ""}
        {isErr}
      />
    </span>
  </div>
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .logo {
    width: 25%;
    padding-bottom: 5rem;
    padding-top: 2rem;
  }

  .logo > img {
    width: 100%;
  }

  .header {
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 30px;
    line-height: 56px;
    color: #2a2f34;
    text-align: center;
  }

  .text {
    font-family: "Nunito", sans-serif;
    font-weight: 400;
    font-size: 14px;
    line-height: 26px;
    color: #2a2f34;
    max-width: 400px;
    text-align: center;
  }
  .buttons {
    padding-top: 2rem;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    justify-content: center;
    width: 400px;
  }

  .container {
    display: flex;
    flex-flow: column nowrap;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100%;
    background-color: #fcfdff;
  }

  .error {
    padding-top: 0.4rem;
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 12px;
    line-height: 17px;
    color: red;
    max-width: 30rem;
  }

  @media screen and (max-width: 1000px) {
    .header {
      font-size: 18px;
      line-height: 20px;
    }
    .text {
      padding: 0 1rem;
      font-size: 12px;
    }

    .password {
      width: 245px;
    }

    .logo {
      padding: 2rem 0;
    }
    .buttons {
      padding-top: 1rem;
    }
  }
</style>
