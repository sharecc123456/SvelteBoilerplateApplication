<script>
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import TextField from "../components/TextField.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "Helpers//ToastStorage.js";
  import NavBar from "../components/NavBar.svelte";
  import { onMount } from "svelte";

  let password;
  let resetHash;

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

  onMount(() => {
    fetch("/n/api/v1/user/hash", {
      method: "GET",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
    })
      .then((res) => res.json())
      .then((res) => {
        resetHash = res?.reset_hash;
      });
  });

  async function setPassword() {
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    const hashed_password = await crypto.subtle.digest("SHA-256", data);
    const encoded_password = encode_base16(hashed_password);

    let submit_data = {
      hash: resetHash,
      pwd: encoded_password,
    };

    fetch("/n/api/v1/user/password", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(submit_data),
    })
      .then(() => {
        showToast(`Success! Password Changed!.`, 2000, "default", "MM");
        window.history.back(-1);
      })
      .catch((err) => {
        showToast(
          `Something went wrong. Please try again!.`,
          2000,
          "error",
          "MM"
        );
        window.history.back(-1);
      });
  }

  const handle_keydown = (e) => {
    if (e.key === "Enter") {
      // trap focus
      if (password?.length >= 9) {
        setPassword();
      } else {
        showToast(
          `Please make sure your password is longer than 8 characters..`,
          2000,
          "error",
          "MM"
        );
      }
      e.preventDefault();
    }
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<NavBar backLink="  " backLinkHref="javascript:window.history.back(-1)" />

<div class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="header">Change Password</div>

  <div class="text">
    In order to <b>protect your account</b>, make sure your password is longer
    than 8 characters.
  </div>

  <div class="buttons">
    <TextField
      type="password"
      bind:value={password}
      text="Your New Password"
      icon="lock"
      iconStyle="regular"
    />
  </div>

  <div class="buttons">
    <span on:click={() => password?.length >= 9 && setPassword()}>
      <LoadingButton disabled={password?.length < 9} text="Change Password" />
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
