<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  import { getCompanies } from "BoilerplateAPI/Recipient";
  import { initializePaperCups } from "../../paperCups.js";
  import { onMount } from "svelte";
  import ChooseCompanyModal from "../modals/ChooseCompanyModal.svelte";

  let requestorChoiceElements = [];
  let showRequestorCompanyChoice = false;
  let numRecipientCompanies = 2;
  let numRequestorCompanies = 0;

  // the email of the user logging in
  export let email = "";

  // figure out what to do when the user has clicked the Requestor side button
  const handleRequestorClick = () => {
    if (numRequestorCompanies <= 1) {
      if (numRequestorCompanies <= 0) {
        console.error(
          `Invalid requestor state! No requestor companies: ${numRequestorCompanies} ??`
        );
      }
      // single requestor, the backend will figure out the reuqestor
      window.location = "/n/requestor";
    } else {
      // need to restrict the current JWT - show a dropdown.
      showRequestorCompanyChoice = true;
    }
  };

  // the user has made a choice from multiple requestor companies,
  // call the API to modify our JWT.
  const handleRequestorClickDropdown = async (ret) => {
    let request = await fetch("/n/api/v1/user/restrict", {
      method: "POST",
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        companyId: ret,
      }),
    });

    if (request.ok) {
      window.location = "/n/requestor";
    } else {
      alert("An error occured while restricting your JWT to the chosen suborg");
      console.log(request);
    }
  };

  onMount(() => {
    let r = getCompanies().then((c) => {
      numRecipientCompanies = c.recipient_companies.length;
      numRequestorCompanies = c.requestor_companies.length;
      requestorChoiceElements = c.requestor_companies.map((x) => {
        return {
          icon: "",
          text: x.name,
          ret: x.id,
        };
      });
      console.log(`numRecipientCompanies = ${numRecipientCompanies}`);
    });
    const user = { email } || {};
    initializePaperCups(user);
  });
</script>

<form class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="text">
    Your email ({email}) is registered as both a Requestor and Contact. Please
    choose which mode you’d like to enter. To switch again, select "Switch User
    Mode" from your menu.
  </div>

  <div class="buttons">
    <span class="buttonContainer" on:click={handleRequestorClick}>
      <button
        type="button"
        class="midLoginButton"
        style="background: #4badf3; border-color: #4badf3;"
      >
        <FAIcon icon="user-cog" iconSize="large" rightPad />
        Admin/ Requestor
        <br />
        (send/ manage requests to others)
      </button>
    </span>

    {#if numRecipientCompanies > 1}
      <span
        class="buttonContainer"
        on:click={() => (window.location = "/n/recipientc")}
      >
        <button
          type="button"
          class="midLoginButton"
          style="background: #4a5157; border-color: #4a5157;"
        >
          <FAIcon icon="cloud-upload-alt" iconSize="large" rightPad />
          Contact/ Recipient
          <br />
          (submit assigned requests)
        </button>
      </span>
    {:else}
      <span
        class="buttonContainer"
        on:click={() => (window.location = "/n/recipient")}
      >
        <button
          type="button"
          class="midLoginButton"
          style="background: #4a5157; border-color: #4a5157;"
        >
          <FAIcon icon="cloud-upload-alt" iconSize="large" rightPad />
          Contact/ Recipient
          <br />
          (submit assigned requests)
        </button>
      </span>
    {/if}
    <span
      class="buttonContainer"
      on:click={() => (window.location = "/logout")}
    >
      <button
        type="button"
        class="midLoginButton"
        style="background: #ffffff; border: 0.5px solid #b3c1d0; color: #606972; filter: none;"
      >
        <FAIcon icon="sign-out-alt" iconSize="large" rightPad />
        Logout
      </button>
    </span>
  </div>
</form>

{#if showRequestorCompanyChoice}
  <ChooseCompanyModal
    buttonText={"Go"}
    on:close={() => {
      window.sessionStorage.removeItem("boilerplate_company");
      showRequestorCompanyChoice = false;
      window.location = "/n/requestor";
    }}
  />
{/if}

<style>
  .logo {
    width: 25%;
    padding-bottom: 5rem;
  }

  .logo > img {
    width: 100%;
  }

  .text {
    font-family: "Nunito", sans-serif;
    font-weight: 400;
    font-size: 18px;
    line-height: 28px;
    color: #2a2f34;
    max-width: 35%;
    text-align: center;
    padding: 0 24px;
  }

  .buttonContainer {
    padding: 10px;
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

  .buttonContainer {
    padding: 10px;
  }
  .midLoginButton {
    display: flex;
    align-items: center;
    width: 100%;
    border-style: solid;
    border-radius: 4px;
    cursor: pointer;
    padding: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 16px;
    max-height: 40px;
    text-align: center;
    text-decoration: none;
    letter-spacing: 0.02em;
    text-transform: none;
    white-space: nowrap;
    color: #ffffff;
    filter: drop-shadow(0px 3px 4px rgba(46, 56, 77, 0.12));
  }
  @media only screen and (max-width: 780px) {
    .text {
      max-width: none;
      padding: 0 24px;
    }
    .buttons {
      flex-direction: column;
    }
  }
</style>
