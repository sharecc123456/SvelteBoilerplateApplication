<script>
  import Dropdown from "../components/Dropdown.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import { featureEnabled } from "Helpers/Features";
  import { clickOutside } from "../../helpers/clickOutside.js";
  import {
    sessionStorageGet,
    sessionStorageHas,
    sessionStorageSave,
  } from "../../helpers/sessionStorageHelper";
  import Bubble from "./Bubble.svelte";

  export let initials = "--";
  export let recipient = "";
  export let avatarName = "John Doe";
  export let avatarCompany = "ACME, Inc.";
  export let onMain = false;
  export let windowType = "requestor";
  export let isOnline = true;

  export let showDropdown = false;
  export let showMainDropdown = false;
  let userEmail;
  initials = avatarName
    .split(" ")
    .map((n) => n[0])
    .join(".");

  function toggleDropdown() {
    showDropdown = !showDropdown;
  }
  function openMainDropdown() {
    showMainDropdown = true;
  }

  function doLogout() {
    window.location = "/logout";
  }

  function doSwitch() {
    window.location = "/midlogin";
  }

  async function getEmail() {
    let key = `${windowType}_info`;
    let user_struct = {};
    if (sessionStorageHas(key)) {
      user_struct = sessionStorageGet(key);
    } else {
      let request = await fetch(`/n/api/v1/user/me?type=${windowType}`);
      user_struct = await request.json();
      sessionStorageSave(key, user_struct);
    }
    let email = user_struct.email;
    return email;
  }

  getEmail().then((email) => {
    userEmail = email;
  });
</script>

{#if onMain}
  <span on:click={openMainDropdown}>
    <div class="initials clickable">
      {avatarName
        .split(" ")
        .map((n) => n[0])
        .join("")}
    </div>
    <span class="icon clickable">
      <FAIcon icon="ellipsis-v" iconStyle="solid" />
    </span>
  </span>
{:else}
  <span on:click={toggleDropdown} class="avatar-group">
    <div class="initials clickable mr-0">
      {initials}
    </div>
    <div class="__avatar__container-bubble">
      <Bubble {isOnline} />
    </div>
    <span class="description">{recipient}</span>
    <span class="icon clickable desktop-only">
      <FAIcon icon="bars" iconStyle="solid" iconSize="large" />
    </span>
  </span>
{/if}

{#if showMainDropdown}
  <div
    class="main-dropdown-content"
    use:clickOutside
    on:click_outside={() => {
      showMainDropdown = false;
    }}
  >
    <div class="main-avatar-text">
      {avatarName} ( {avatarCompany} )
    </div>
    {#if featureEnabled("internal_development")}
      <div class="main-element clickable" on:click={doLogout}>
        <span class="main-icon">
          <FAIcon icon="user" iconStyle="solid" />
        </span>
        <span class="main-text">(WIP) Account Details</span>
      </div>
      <!-- Move internal Dev here once account details are made -->
      <div class="main-element clickable" on:click={doSwitch}>
        <span class="main-icon">
          <FAIcon icon="repeat-alt" iconStyle="duotone" />
        </span>
        <span class="main-text">Switch to Client</span>
      </div>
    {/if}
    <div class="main-element clickable" on:click={doLogout}>
      <span class="main-icon">
        <FAIcon icon="sign-out" iconStyle="solid" />
      </span>
      <span class="main-text">Logout</span>
    </div>
  </div>
{/if}

{#if showDropdown}
  <div
    class="dropdown-content"
    use:clickOutside
    on:click_outside={() => {
      console.log("small dropdown");
      showDropdown = false;
    }}
  >
    <div style="pointer-events: none;" class="element">
      <span>{userEmail ? userEmail : ""}</span>
    </div>
    <div class="element" on:click={doLogout}>
      <span class="icon">
        <FAIcon icon="user" iconStyle="solid" />
      </span>
      <span>Logout</span>
    </div>
  </div>
{/if}

<style>
  div.initials {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-size: 14px;
    line-height: 21px;
    color: #ffffff;
    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;

    align-items: center;
    text-align: center;
    justify-content: center;
    display: inline-flex;

    background: #76808b;
    width: 40px;
    height: 40px;
    border-radius: 50%;
    margin-right: 0.5rem;
  }

  .element > .icon {
    padding-right: 0.5rem;
  }

  .element {
    cursor: pointer;
  }

  .dropdown-content {
    position: fixed;
    right: 4rem;
    display: block;

    background: #ffffff;
    box-shadow: 0px 4px 15px 2px rgba(23, 31, 70, 0.12);
    border-radius: 5px;

    z-index: 999999;
  }

  .dropdown-content div {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.25px;

    /* Black */
    color: #2a2f34;

    padding-left: 1rem;
    padding-right: 1rem;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
  }

  .main-dropdown-content {
    position: fixed;
    display: block;
    top: 5rem;
    right: 4.5rem;

    background: #ffffff;
    box-shadow: 0px 4px 15px 2px rgba(23, 31, 70, 0.12);
    border-radius: 5px;

    z-index: 999999;
  }

  .main-avatar-text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-size: 14px;
    line-height: 21px;
    color: #2a2f34;
    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;

    align-items: center;
    text-align: center;
    justify-content: center;
    display: inline-flex;

    border-bottom: 0.5px solid #b3c1d0;
    box-sizing: border-box;
  }

  .main-dropdown-content div {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    /* identical to box height, or 150% */
    letter-spacing: 0.25px;

    /* Black */
    color: #2a2f34;

    padding-left: 1rem;
    padding-right: 1rem;
    padding-top: 0.5rem;
    padding-bottom: 0.5rem;
  }

  .main-element {
    display: flex;
    position: relative;
  }

  .main-icon {
    color: #76808b;
    justify-content: flex-start;
  }

  .main-text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #2a2f34;
    display: flex;
    width: 100%;
    justify-content: flex-end;
  }
  .mr-0 {
    margin-right: 0 !important;
  }
  .description {
    font-family: "Nunito", sans-serif;
    margin: 0;
    padding: 0;
    display: none;
  }
  .avatar-group {
    display: flex;
    align-items: center;
    gap: 0.2rem;
  }
  .dropdown-content div:hover {
    background: #e9f1fa;
  }
  .icon {
    color: #76808b;
  }
  .clickable {
    cursor: pointer;
  }

  .__avatar__container-bubble {
    position: relative;
    top: 14px;
    left: -19px;
  }

  @media only screen and (max-width: 767px) {
    .description {
      display: block;
    }
    .avatar-group {
      flex-direction: column;
      gap: 0.2rem;
    }
    .desktop-only {
      display: none;
    }

    .__avatar__container-bubble {
      position: relative;
      top: 0;
      left: 0;
    }
  }
</style>
