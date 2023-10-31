<script>
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import TextField from "../components/TextField.svelte";
  import Modal from "../components/Modal.svelte";
  import { loginUser, loginUserSSO } from "BoilerplateAPI/User";
  import { initializePaperCups } from "../../paperCups.js";
  import { onMount } from "svelte";
  import ResetPassword from "./ResetPassword.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import Button from "../atomic/Button.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";
  import { featureEnabled } from "Helpers/Features";
  import { VALIDEMAILFORMAT } from "Helpers/util";
  let email;
  let password;
  let pressed = false;
  let googleUser = null;

  let email_error_messae = "";
  let bad_password = false;
  let too_many_attempts = false;
  let showTroubleLoggingInModal = false;
  const searchParams = window.location.search;

  const adhocEmail = searchParams.includes("?")
    ? searchParams.split("?")[1].split("=")[0] == "email"
      ? searchParams.split("?")[1].split("=")[1]
      : ""
    : "";

  email = decodeURIComponent(adhocEmail);
  // https://tools.ietf.org/html/rfc4648#section-8
  function encode_base16(hash) {
    let arr = new Uint8Array(hash);
    let result = "";
    let alphabet = "0123456789abcdef";

    for (const val of arr) {
      let lower_value = val & 0x0f;
      let upper_value = (val & 0xf0) >> 4;

      let lower_char = alphabet[lower_value];
      let upper_char = alphabet[upper_value];

      // Lower-endian!
      result = `${result}${upper_char}${lower_char}`;
    }

    return result;
  }
  let routeResetPasswordScreen = false;
  let resetPasswordUser;
  let ResetInfoText =
    "Reset the password you used when you first created your Boilerplate account";
  function doLogin(email, ok, res) {
    sessionStorage.clear();

    if (ok) {
      if (window.FS != null && window.FS != undefined) {
        window.FS.identify(res.id, {
          displayName: res.name,
          email: email,
        });
      }
      if (res.status == "reset_password") {
        routeResetPasswordScreen = true;
        resetPasswordUser = res;
      } else if (res.status == "requestor") {
        window.location = "/n/requestor";
      } else if (res.status == "recipient") {
        window.location = "/n/recipient";
      } else if (res.status == "recipientc") {
        window.location = "/n/recipientc";
      } else if (res.status == "requestorc") {
        window.location = "/n/requestorc";
      } else if (res.status == "midlogin") {
        window.location = "/midlogin";
      } else if (res.status == "failed") {
        window.location = "/recipientDeleted";
      } else {
        alert("Sorry - redirect failure.");
      }
    } else {
      if (res.error == "invalid_email") {
        email_error_messae =
          "The email address you provided was not found. Please double check that you provided the correct one.";
      } else if (res.error == "invalid_password") {
        bad_password = true;
      } else if (res.error == "too_many_attempts") {
        too_many_attempts = true;
      } else if (res.error == "sso_invalid") {
        email_error_messae = "SSO Error: Invalid email.";
      } else if (res.error == "sso_already") {
        email_error_messae = "SSO Error: Email mismatch.";
      } else if (res.error == "sso_no_user") {
        email_error_messae = "SSO Error: Email doesn't exist in the system";
      } else if (res.error == "sso_bad_token") {
        email_error_messae = "SSO Error: Couldnt' verify Google JWT";
      }
      pressed = false;
    }
  }

  async function handleLogin() {
    bad_password = false;
    email_error_messae = "";

    if (!isValidEmail(email)) {
      pressed = false;
      email_error_messae = "Please enter a valid email address.";
      return;
    }

    if (email && password) {
      // SHA-256 hash
      const encoder = new TextEncoder();
      const data = encoder.encode(password);
      const hashed_password = await crypto.subtle.digest("SHA-256", data);

      // Now encode with base16
      const encoded_password = encode_base16(hashed_password);

      // Send using the API.
      let reply = await loginUser(email.toLowerCase(), encoded_password);
      let res = await reply.json();
      doLogin(email, reply.ok, res);
    } else {
      pressed = false;
      if (!email && !password) {
        showToast(
          `Please Input Email Address and Password!`,
          1000,
          "error",
          "MM"
        );
      } else if (!email) {
        showToast(`Please Input Email Address!`, 1000, "error", "MM");
      } else {
        showToast(`Please Input Password!`, 1000, "error", "MM");
      }
    }
  }

  async function handleKeyUp(evt) {
    if (evt.code == "Enter" || evt.keyCode == 13) {
      handleLogin();
    }
  }

  onMount(() => initializePaperCups({}));

  const isValidEmail = (email) => {
    return email.match(VALIDEMAILFORMAT);
  };

  window.unloadJWT = (token) => {
    var base64Url = token.split(".")[1];
    var base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
    var jsonPayload = decodeURIComponent(
      window
        .atob(base64)
        .split("")
        .map(function (c) {
          return "%" + ("00" + c.charCodeAt(0).toString(16)).slice(-2);
        })
        .join("")
    );

    return JSON.parse(jsonPayload);
  };

  window.handleGoogleSignin = async (event) => {
    let reply = await loginUserSSO("google", event.credential);
    let res = await reply.json();
    let jwt = unloadJWT(event.credential);

    console.log({ jwt });
    doLogin(jwt.email, reply.ok, res);
  };
</script>

<svelte:head>
  <script src="https://accounts.google.com/gsi/client" async defer></script>
</svelte:head>

<form class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>
  <div class="form">
    <div class="field">
      <div class="name">Email Address</div>
      <div class="value">
        <TextField bind:value={email} text="Email Address" />
      </div>

      <div class="error">{email_error_messae}</div>
    </div>
    <div class="field">
      <div class="name">Password</div>
      <div on:keyup={handleKeyUp} class="value">
        <TextField bind:value={password} type="password" text="Password" />
      </div>
      {#if bad_password}
        <div class="error">
          You’ve entered an incorrect password. Please check that you have
          entered it correctly. If that doesn’t resolve your issue, use the
          Forgot Password link below.
        </div>
      {/if}
      {#if too_many_attempts}
        <div class="error">
          You’ve entered an incorrect password too many times. In order to
          protect your account, access is now restricted for a few minutes.
          Please try again later.
        </div>
      {/if}
    </div>

    <div class="field">
      <div class="policy">
        By continuing, I agree to the
        <a
          style="color: #2a2f34"
          href="https://app.boilerplate.co/terms"
          target="_blank"
        >
          Terms & Conditions
        </a>
        and
        <a
          style="color: #2a2f34"
          href="https://boilerplate.co/privacy-policy"
          target="_blank"
        >
          Privacy Policy.
        </a>
      </div>
    </div>

    <div class="buttons">
      <span on:click={handleLogin}>
        <LoadingButton bind:pressed text="Login" />
      </span>
      {#if featureEnabled("google_integration")}
      <div
        style="display: flex; flex-flow: row nowrap; justify-content: center;"
      >
        <div
          id="g_id_onload"
          data-client_id="742228283026-dho0g52hf3727v014v9ahanbmevqhkbn.apps.googleusercontent.com"
          data-context="signin"
          data-ux_mode="popup"
          data-callback="handleGoogleSignin"
          data-auto_prompt="false"
        />

        <div
          class="g_id_signin"
          data-type="standard"
          data-shape="rectangular"
          data-theme="outline"
          data-text="signin_with"
          data-size="large"
          data-logo_alignment="left"
        />
      </div>
      {/if}
    </div>

    <div class="forgot">
      <a href="/forgot/password">Forgot/ reset password.</a>
    </div>

    <div
      style="color: hsl(217, 13%, 27%); text-decoration: underline; cursor: pointer"
      on:click={() => {
        showTroubleLoggingInModal = true;
      }}
      class="forgot"
    >
      <span>Issues logging in?</span>
    </div>
  </div>
</form>

{#if routeResetPasswordScreen}
  <ResetPassword {...resetPasswordUser} {ResetInfoText} />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showTroubleLoggingInModal}
  <Modal
    on:close={() => {
      showTroubleLoggingInModal = false;
    }}
  >
    <p slot="header">Issues logging in?</p>
    <span style="font-family: 'Nunito', sans-serif; font-size: 15px;">
      <div class="modal-subheader">Here are some common login issues:</div>

      <ol>
        <li>
          Typos in your login info, please ensure your email address is typed
          correctly.
        </li>
        <li>
          Wrong email address (for example, the checklist was assigned to your
          Gmail, but you're trying to login with your MSN or Yahoo email).
        </li>
        <li>
          Not the original recipient of a checklist (for example, someone
          forwarded you a checklist to complete).
        </li>
      </ol>

      <div style="margin-bottom: 1rem;">
        If none of these are your issue, please try the 'Forgot password' link.
        If that doesn't work, please contact
        <a href="mailto: support@boilerplate.co"> support@boilerplate.co </a>
        or use the blue chat bot in the bottom right.
      </div>
    </span>

    <div class="modal-buttons">
      <span
        on:click={() => {
          showTroubleLoggingInModal = false;
        }}
      >
        <Button color="white" text="Close" />
      </span>
    </div>
  </Modal>
{/if}

<style>
  .error {
    padding-top: 0.4rem;
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 12px;
    line-height: 17px;
    color: red;
    max-width: 30rem;
  }

  .logo {
    width: 25%;
    padding-bottom: 5rem;
  }

  .logo > img {
    width: 100%;
  }

  .name {
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 18px;
    line-height: 34px;
    color: #2a2f34;
  }

  .forgot {
    padding-top: 1rem;
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 14px;
    line-height: 24px;
    text-align: center;
  }

  .buttons {
    text-align: center;
    margin-top: 1rem;
    display: flex;
    column-gap: 1rem;
    row-gap: 1rem;
    flex-flow: column nowrap;
  }
  .forgot > a:link {
    color: hsl(217, 13%, 27%);
  }

  .field {
    margin-bottom: 1rem;
    width: 400px;
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

  .policy {
    font-family: "Nunito", sans-serif;
    font-size: 13px;
  }

  @media screen and (max-width: 1000px) {
    .logo {
      width: 75%;
    }

    .form {
      max-width: 100%;
    }

    .name {
      font-size: 16px;
    }

    .field {
      margin-bottom: 0.5rem;
      width: 300px;
    }
  }
</style>
