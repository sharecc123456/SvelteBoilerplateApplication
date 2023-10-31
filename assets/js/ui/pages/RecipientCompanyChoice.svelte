<script>
  import Dropdown from "../components/Dropdown.svelte";
  import { getCompanies } from "BoilerplateAPI/Recipient";

  let elements = [];
  export let type = "recipient"; // recipient|requestor : which text to display

  getCompanies().then((ci) => {
    let companies;
    if (type == "recipient") {
      companies = ci.recipient_companies;
    } else {
      companies = ci.requestor_companies;
    }

    elements = companies.map((c) => {
      return { ret: c.id, text: c.name };
    });
  });

  async function handleClick(ret) {
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
      if (type == "recipient") {
        window.location = "/n/recipient";
      } else {
        window.location = "/n/requestor";
      }
    } else {
      alert("An error occured");
      console.log(request);
    }
  }
</script>

<form class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="text">
    {#if type == "recipient"}
      Your account is part of multiple companies as a Contact, please choose
      which company's documentation request you'd like to fulfill. When you are
      done, logout and log back in to switch again between companies.
    {:else}
      Your account is part of multiple companies/suborganizations as an Admin,
      please choose which company/suborganization you'd like to manage. You can
      use the sidebar's Switch Org option to switch between them once you are
      logged in.
    {/if}
  </div>

  <div class="buttons">
    <Dropdown
      text="Choose Company"
      {elements}
      scrollable={true}
      clickHandler={handleClick}
    />
  </div>
</form>

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
  }

  @media screen and (max-width: 767px) {
    .text {
      max-width: 70%;
    }
    .logo {
      width: 70%;
    }
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
</style>
