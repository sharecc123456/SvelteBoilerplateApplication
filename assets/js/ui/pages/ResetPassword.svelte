<script>
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import TextField from "../components/TextField.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers//ToastStorage.js";

  export let lhash;
  export let uid;
  export let email;
  let password = "";

  export let ResetInfoText =
    "As you do not yet have a password, please use this one-time form to create \
    one for yourself.";

  let PasswordRequirementText =
    "Your password should be secure, and have at least 8 \
    characters.";

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

  const callFocus = (node) => {
    node.focus();
  };

  async function setPassword() {
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    const hashed_password = await crypto.subtle.digest("SHA-256", data);
    const encoded_password = encode_base16(hashed_password);

    // Enforce the password length requirement, here too because the span takes the event first.
    if (password.trim().length < 8) {
      return;
    }

    let submit_data = {
      current_lhash: lhash,
      uid: uid,
      new_lhash: encoded_password,
    };

    const reply = await fetch("/n/api/v1/user/setpwd", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(submit_data),
    });

    if (reply.ok) {
      window.location = "/login";
    } else {
      showToast(
        "Error! could not reset password. Try again",
        1500,
        "error",
        "MM"
      );
    }
  }
</script>

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="header">Welcome to Boilerplate!</div>
  <div class="text">
    {ResetInfoText}
    <br />
    {PasswordRequirementText}
  </div>

  <div>
    <TextField disabled={true} text={email} type="text" icon="envelope" />
  </div>
  <div class="buttons">
    <TextField
      type="password"
      bind:value={password}
      text="Your New Password"
      icon="lock"
      iconStyle="regular"
      useFocusCallback={callFocus}
      enterCallback={() => {
        setPassword();
      }}
    />
  </div>

  <div class="buttons">
    <span on:click={setPassword}>
      <LoadingButton
        disabled={password.trim().length < 8}
        text="Set Password & Login"
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
  }

  .logo > img {
    width: 100%;
  }

  .header {
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 24px;
    line-height: 30px;
    color: #2a2f34;
    max-width: 35%;
    text-align: center;
  }

  .text {
    font-family: "Nunito", sans-serif;
    font-weight: 400;
    font-size: 16px;
    line-height: 28px;
    color: #2a2f34;
    max-width: 35%;
    text-align: center;
    margin-top: 1rem;
  }

  .buttons {
    padding-top: 2rem;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    justify-content: center;
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

  @media only screen and (max-width: 1020px) {
    .text {
      width: 80%;
      padding: 0 2rem;
      max-width: none;
      font-size: 14px;
      margin-top: 0;
    }

    .header {
      font-size: 18px;
      width: 80%;
      padding: 0 2rem;
      max-width: none;
    }

    .buttons {
      padding-top: 1rem;
    }
  }
</style>
