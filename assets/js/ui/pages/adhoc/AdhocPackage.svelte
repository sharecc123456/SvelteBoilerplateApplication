<script>
  import LoadingButton from "../../atomic/LoadingButton.svelte";
  import TextField from "../../components/TextField.svelte";
  import {
    checkIfExists,
    adhocRegister,
    adhocAssign,
  } from "BoilerplateAPI/User";
  import { getAdhoc } from "BoilerplateAPI/Adhoc";
  import { showErrorMessage } from "../../../helpers/Error";

  export let adhoc_string;
  let email;
  let password;
  let name;
  let firstName;
  let lastName;
  let org;
  let pressed = false;
  let adhoc_title = "Intake Link";

  let show_password = false;
  // https://gist.github.com/cjaoude/fd9910626629b53c4d25 --(RFC 2822) format
  let emailformat =
    /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/;

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

  async function handleLogin() {
    if (show_password == false) {
      /* check if the user exists */
      let status = await checkIfExists(email);
      if (!status || !status.exists) {
        pressed = false;
        show_password = true;
      } else {
        // TODO: approve adhoc - send to login screen.
        const __name = status.name;
        let request = await adhocAssign(status.id, __name, adhoc_string);
        if (request.ok) {
          window.location = `/login?email=${encodeURI(email)}`;
        }
      }
    } else {
      // New user registration

      // SHA-256 hash
      const encoder = new TextEncoder();
      const data = encoder.encode(password);
      const hashed_password = await crypto.subtle.digest("SHA-256", data);

      // Now encode with base16
      const encoded_password = encode_base16(hashed_password);
      let request = await adhocRegister(
        name,
        email,
        encoded_password,
        adhoc_string,
        org
      );
      if (request.ok) {
        window.location = "/";
      }
    }
  }

  async function full_handleLogin() {
    bad_email = bad_password = false;
    // SHA-256 hash
    const encoder = new TextEncoder();
    const data = encoder.encode(password);
    const hashed_password = await crypto.subtle.digest("SHA-256", data);

    // Now encode with base16
    const encoded_password = encode_base16(hashed_password);

    // Send using the API.
    let reply = await loginUser(email, encoded_password);
    if (reply.ok) {
      let res = await reply.json();
      if (res.status == "requestor") {
        window.location = "/n/requestor";
      } else if (res.status == "recipient") {
        window.location = "/n/recipient";
      } else if (res.status == "midlogin") {
        window.location = "/midlogin";
      } else {
        alert("Sorry - redirect failure.");
      }
    } else {
      let error = await reply.json();
      if (error.error == "invalid_email") {
        bad_email = true;
      } else if (error.error == "invalid_password") {
        bad_password = true;
      }
      pressed = false;
    }
  }

  let validationErrorType = "";

  const isvalidUserInput = () => {
    name = firstName + " " + lastName;
    const emailValidate = email.match(emailformat);
    const nameValidate = name.trim() != "";
    const passwordValidate = password.trim().length >= 8;

    validationErrorType = !emailValidate
      ? "email"
      : !nameValidate
      ? "name"
      : !passwordValidate
      ? "password"
      : "";
    return emailValidate && nameValidate & passwordValidate;
  };

  const handleEmailKeyUp = (evt) => {
    if (evt.code == "Enter") {
      const isValid = show_password
        ? isvalidUserInput()
        : email.match(emailformat);

      isValid
        ? handleLogin()
        : !show_password
        ? showErrorMessage("userErrors", "email")
        : showErrorMessage("userErrors", validationErrorType);
    }
  };

  const handleEmailLogin = () => {
    email = email.toLowerCase();
    if (email.match(emailformat)) {
      handleLogin();
    } else {
      showErrorMessage("userErrors", "email");
    }
    pressed = false;
  };

  const handleRegistration = (evt) => {
    // on button click and enter pressed
    if (evt.type == "click" || evt.code == "Enter") {
      if (isvalidUserInput()) {
        handleLogin();
      } else {
        pressed = false;
        showErrorMessage("userErrors", validationErrorType);
      }
    }
  };

  getAdhoc(adhoc_string).then((adhoc) => {
    adhoc_title = adhoc.title;
  });
</script>

<form on:submit={(evt) => evt.preventDefault()} class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>
  <div class="title">
    {adhoc_title}
  </div>
  <div class="text">
    Please sign in or create a new account to complete the checklist.
  </div>

  <div class="field">
    <div class="name">
      <span class="required">*</span>Email Address
    </div>
    <div on:keyup={handleEmailKeyUp} class="value">
      <TextField
        bind:value={email}
        text="Your Email Address"
        disabled={show_password ? true : false}
      />
    </div>
  </div>

  {#if show_password}
    <div class="instruction">
      You do not currently have a Boilerplate account, please create one here by
      entering your name and your new password. Boilerplate is an encrypted
      platform for managing documentation requests. Learn more about our
      security
      <a target="_blank" href="https://www.boilerplate.co/security">here</a>.
    </div>

    <!-- <div class="field">
      <div class="name">
        <span class="required">*</span>Your Name
      </div>
      <div on:keyup={handleRegistration} class="value">
        <TextField bind:value={name} text="Your full name" />
      </div>
    </div> -->

    <div class="field">
      <div class="name">
        <span class="required">*</span>Password<span
          style="font-size: 12px; color: #898080; margin-left: 5px; vertical-align: middle;"
          >(Password must be at least 8 characters)</span
        >
      </div>
      <div on:keyup={handleRegistration} class="value">
        <TextField bind:value={password} type="password" text="Password" />
      </div>
    </div>

    <div class="field">
      <div class="name">
        <span class="required">*</span>First Name
      </div>
      <div on:keyup={handleRegistration} class="value">
        <TextField bind:value={firstName} text="First name" />
      </div>
    </div>

    <div class="field">
      <div class="name">
        <span class="required">*</span>Last Name
      </div>
      <div on:keyup={handleRegistration} class="value">
        <TextField bind:value={lastName} text="Last name" />
      </div>
    </div>

    <div class="field">
      <div class="name">Your Company/Organization</div>
      <div on:keyup={handleRegistration} class="value">
        <TextField bind:value={org} text="Your company or organization" />
      </div>
    </div>
  {/if}

  <div class="button">
    <span on:click={show_password ? handleRegistration : handleEmailLogin}>
      <LoadingButton
        disabled={password?.length <= 7 ? true : false}
        bind:pressed
        text="Next Step"
      />
    </span>
  </div>
</form>

<style>
  .instruction {
    font-family: "Nunito", sans-serif;
    font-weight: normal;
    font-size: 16px;
    line-height: 22px;
    max-width: 50%;
    text-align: center;
    padding-bottom: 1rem;
  }

  .required {
    color: rgb(221, 38, 38);
  }

  .title {
    font-family: "Nunito", sans-serif;
    font-weight: 500;
    font-size: 24px;
    line-height: 30px;
    text-align: center;
    margin-bottom: 0.5rem;
  }
  .text {
    font-family: "Nunito", sans-serif;
    font-weight: normal;
    font-size: 16px;
    line-height: 20px;
    text-align: center;
    margin-bottom: 1rem;
  }

  .logo {
    margin: 2rem 0;
    width: 100%;
    max-width: 400px;
  }

  .logo > img {
    width: 100%;
  }

  .name {
    font-family: "Nunito", sans-serif;
    font-weight: 600;
    font-size: 16px;
    line-height: 20px;
    color: #2a2f34;
  }

  .field {
    padding-bottom: 1rem;
    width: 100%;
    max-width: 400px;
    margin: 0 1rem;
  }

  .container {
    position: relative;
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

  @media only screen and (max-width: 767px) {
    .instruction {
      max-width: 100%;
    }

    .logo {
      max-width: 300px;
    }

    .text {
      margin-inline: 1rem;
    }

    .field {
      max-width: 350px;
    }

    .name,
    .text {
      font-size: 14px;
    }
  }
</style>
