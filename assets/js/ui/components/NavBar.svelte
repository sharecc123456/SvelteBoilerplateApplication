<script>
  export let avatarInitials = "LK";
  export let header = "";
  export let backLink = "";
  export let backLinkHref = "#";
  export let backLinkAction = null;
  export let leftText = "";
  export let leftTextBig = "";
  export let longLeft = false;
  export let isRecipient = false;
  export let showLogo = true;
  export let hasMiddleTextIcon = false;
  export let middleTextIconProps = {};
  export let middleText = "";
  export let middleSubText = "";
  export let navbar_spacer_classes = "";

  export let buttonText = "";
  export let buttonColor = "primary";
  export let buttonDisabled = false;
  export let showCompanyLogo = true;
  export let leftBottomText;

  export let windowType = "requestor";
  export let checklistInfo = "";

  export let showTooltip = false;
  export let tooltipMessage = "";
  export let thirdLine = null;

  export let elements = null;
  import Dropdown from "../components/Dropdown.svelte";
  import Avatar from "../atomic/Avatar.svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Button from "../atomic/Button.svelte";
  import { createEventDispatcher } from "svelte";
  import {
    sessionStorageGet,
    sessionStorageHas,
    sessionStorageSave,
  } from "../../helpers/sessionStorageHelper";
  let dispatch = createEventDispatcher();
  export let renderOnlyIcon = false;
  export let isOnline = false;

  async function getInitials() {
    let key = `${windowType}_info`;
    let user_struct = {};
    if (sessionStorageHas(key)) {
      user_struct = sessionStorageGet(key);
    } else {
      let request = await fetch(`/n/api/v1/user/me?type=${windowType}`);
      user_struct = await request.json();
      sessionStorageSave(key, user_struct);
    }
    let name = user_struct.name;
    return name
      .match(/(\b\S)?/g)
      .join("")
      .match(/(^\S|\S$)?/g)
      .join("")
      .toUpperCase();
  }

  async function handleMultipleCompaniesClick(ret) {
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
      window.location = "/n/recipient";
    } else {
      alert("An error occured");
      console.log(request);
    }
  }

  getInitials().then((initials) => {
    avatarInitials = initials;
  });

  const handleBackLink = () => {
    backLinkAction && backLinkAction();
    window.location.href = backLinkHref;
  };
</script>

<nav>
  <div class="navdiv">
    <div
      class="left"
      class:leftPadded={backLink != ""}
      class:longLeftText={longLeft}
      class:tooltip={showTooltip}
    >
      {#if renderOnlyIcon == true}
        <div
          class="arrow-left-wrapper"
          on:click={() => dispatch("arrowClicked")}
        >
          <FAIcon style="solid" icon="arrow-left" />
        </div>
        {#if showTooltip}
          <span class="tooltiptext">{tooltipMessage}</span>
        {/if}
      {/if}
      {#if backLink != ""}
        <span
          class="backLink"
          style="padding-left: 0rem;"
          on:click|preventDefault={handleBackLink}
        >
          {#if renderOnlyIcon != true}
            <FAIcon style="solid" icon="arrow-left" />
          {/if}
          {#if backLink.trim() != ""}
            <span class="backLink-text">
              {backLink}
            </span>
          {/if}
        </span>
      {/if}

      {#if elements != null}
        <div style="display: flex; align-items: center;">
          <Dropdown
            optionsCenter={true}
            text="Choose Company"
            {elements}
            scrollable={true}
            clickHandler={handleMultipleCompaniesClick}
          />
          <span
            style="padding-left: 0.5rem;
            font-family: Nunito, sans-serif;
            font-size: 14px;"
          >
            {#if leftText != ""}
              {leftText}
            {/if}
          </span>
        </div>
      {:else if leftText != ""}
        <span class="lefttext" style="font-weight: 600;">
          <span>{leftTextBig}</span>
          {leftText}
          {#if leftBottomText != ""}
            <div style="text-align: left;">{leftBottomText}</div>
          {/if}
        </span>
      {/if}
    </div>
    {#if middleText}
      <div class="absolute-middle">
        <div class="absolute-middle-container">
          {#if checklistInfo != ""}
            <div class="desktop-only">{checklistInfo}</div>
          {/if}
          <div>
            {@html middleText}
            {#if hasMiddleTextIcon}
              <span on:click={() => dispatch("handleMiddleTextIcon")}>
                <FAIcon {...middleTextIconProps} />
              </span>
            {/if}
          </div>
          {#if middleSubText}
            <div
              class="mid-sub-text"
              style="font-weight: normal; line-height: 1rem;"
            >
              {@html middleSubText}
            </div>
          {/if}
          {#if thirdLine}
            <div class="mid-third-text">
              {@html thirdLine}
            </div>
          {/if}
        </div>
      </div>
    {/if}

    {#if showCompanyLogo}
      <div class="middle" class:recipientStyle={isRecipient}>
        <slot />
        {#if window.__boilerplate_whitelabel_image != null && window.__boilerplate_whitelabel_image != undefined && showLogo}
          <img src={window.__boilerplate_whitelabel_image} alt="logo" />
        {/if}
        {#if header}
          <span class="header">{header}</span>
        {/if}
      </div>
    {/if}

    <div class="right">
      <slot name="right-slot" />
      {#if buttonText != ""}
        <span
          style="padding-right: 2rem;"
          on:click={() => {
            dispatch("buttonClicked");
          }}
        >
          <Button
            text={buttonText}
            color={buttonColor}
            disabled={buttonDisabled}
          />
        </span>
      {/if}
      <Avatar initials={avatarInitials} {windowType} {isOnline} />
    </div>
  </div>
</nav>

<div class="navbar-spacer {navbar_spacer_classes}" />

<style>
  .middle img {
    position: absolute;
    margin-left: auto;
    margin-right: auto;
    left: 0;
    right: 0;
    text-align: center;
  }
  .tooltip {
    position: relative;
  }
  .tooltip .tooltiptext {
    visibility: hidden;
    width: max-content;
    background-color: #76808b;
    color: #fff;
    text-align: center;
    border-radius: 4px;
    padding: 6px;
    position: absolute;
    z-index: 1;
    bottom: 100%;
    left: -10%;
    right: 0%;
    font-size: 10px;
  }

  .tooltip:hover .tooltiptext {
    visibility: visible;
  }
  nav {
    top: 0;
    left: 0;
    right: 0;
    position: fixed;
    width: 100%;
    overflow: hidden;
    z-index: 100;
    box-shadow: 0px 5px 20px 2px rgba(25, 84, 140, 0.08);
  }
  .absolute-middle {
    font-family: "Lato", sans-serif;
    font-size: 1.125rem;
    line-height: 1.75rem;
    font-weight: bold;
    --tw-text-opacity: 1;
    color: rgba(17, 24, 39, var(--tw-text-opacity));
    text-align: center;
    margin-top: 1rem;
    width: 100%;
  }
  .header {
    font-size: 1.125rem;
    line-height: 1.75rem;
    font-weight: 800;
    --tw-text-opacity: 1;
    color: rgba(17, 24, 39, var(--tw-text-opacity));
  }
  .navdiv {
    position: fixed;
    justify-content: space-between;
    display: grid;
    grid-auto-flow: column;
    align-items: center;
    height: 5rem;
    background: #ffffff;
    width: 100%;
    box-shadow: 0 -1px 3px rgba(0, 0, 0, 0.1);
  }

  .arrow-left-wrapper {
    display: inline;
    cursor: pointer;
    padding-left: 0rem;
    color: #606972;
  }

  .recipientStyle {
    font-size: 16px;
    line-height: 25px;
    font-family: "Lato", sans-serif;
    color: #2a2f34;
  }
  .navbar-spacer {
    padding-bottom: calc(4rem - 8px);
  }
  .middle {
    /* width: 20%; */
    text-align: center;
    display: contents;
  }
  .middle > img {
    object-fit: contain;
    height: 4rem;
  }
  .backLink {
    color: #606972;
    text-decoration: none;
    cursor: pointer;
  }
  .backLink:hover {
    font-weight: 600;
  }
  .backLink-text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    padding-left: 1rem;
  }
  .lefttext {
    font-family: "AVenir Next";
    font-style: normal;
    color: #606972;
  }

  .left {
    text-align: left;
    vertical-align: middle;
    /* width: 40%; */
    margin-left: 3rem;
  }
  .right {
    text-align: right;
    vertical-align: middle;
    display: flex;
    /* padding-right: 4rem; */
    /* width: 40%; */
    margin-right: 3rem;
  }

  .navbar_spacer_pb1_desktop {
    padding-bottom: 1rem;
  }

  .mid-third-text {
    font-weight: normal;
    font-size: 14px;
  }

  @media only screen and (max-width: 767px) {
    .tooltip:hover .tooltiptext {
      visibility: hidden;
    }
    .right {
      margin: 0 1rem 0;
      flex: 0 0 10vw;
      /* padding-left: 1rem; */
    }
    .left {
      margin: 0 1rem 0;
      flex: 0 0 10vw;
    }
    .middle {
      display: flex;
      flex-direction: column;
      justify-content: center;
    }
    .navbar_spacer_pb1 {
      padding-bottom: 1rem;
    }
    .absolute-middle {
      font-size: 1rem;
      line-height: 1.2rem;
      white-space: normal;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      padding-left: 0.5rem;
      white-space: normal;
      margin-top: 0rem;
      max-height: 3.5rem;
    }
    .desktop-only {
      display: none;
    }
    .mid-third-text {
      font-size: 12px;
    }
    .backLink-text {
      display: none;
    }
  }

  @media only screen and (max-width: 650px) {
    .absolute-middle {
      font-size: 0.9rem;
      line-height: 1rem;
      max-height: 3.5rem;
    }

    .middle > img {
      height: 2rem;
      width: 60%;
    }
  }
  @media only screen and (max-width: 500px) {
    .absolute-middle {
      font-size: 0.8rem;
      line-height: 0.9rem;
      max-height: 3.5rem;
    }
  }
  @media only screen and (max-width: 500px) {
    .middle {
      flex-grow: 2;
      font-size: 0.8rem;
    }

    .mid-third-text {
      font-size: 0.8rem;
    }
  }
  @media only screen and (max-width: 400px) {
    .right {
      padding-left: 0px;
      margin-left: 0.1rem;
      margin-right: 0.5rem;
    }
  }
</style>
