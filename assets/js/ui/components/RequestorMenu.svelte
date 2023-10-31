<script>
  import { onMount } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";

  import { featureEnabled } from "Helpers/Features";
  import { checkIfReviewsPending } from "BoilerplateAPI/Review";
  import {
    has_unread_notification,
    count_unread_notification,
  } from "./../../store";
  import ChooseCompanyModal from "../modals/ChooseCompanyModal.svelte";

  export let hash;
  let preferences_active = false;
  let suborg_active = false;
  let showChooseCompany = false;
  let notifications_active = false;

  let state = [
    {
      text: "Start / Send",
      icon: "plane",
      iconStyle: "far",
      link: "#directsend",
      enabled: true,
      notifications: 0,
      active: true,
    },
    {
      text: "Dashboard",
      icon: "tasks",
      link: "#dashboard",
      iconStyle: "fas",
      enabled: true,
      notifications: 0,
      active: false,
    },
    {
      text: "Checklists",
      icon: "clipboard-list",
      link: "#checklists",
      enabled: true,
      iconStyle: "fas",
      notifications: 0,
      active: false,
    },
    {
      text: "Components",
      icon: "copy",
      iconStyle: "far",
      link: "#templates",
      enabled: true,
      notifications: 0,
      active: false,
    },
    {
      text: "Contacts",
      icon: "address-book",
      iconStyle: "fas",
      link: "#recipients",
      notifications: 0,
      enabled: true,
      active: false,
    },
    {
      text: "Review",
      icon: "glasses",
      iconStyle: "far",
      link: "#reviews",
      enabled: true,
      notifications: 0,
      active: false,
    },
    {
      text: "Internal Only",
      icon: "radiation",
      iconStyle: "fas",
      link: "#internal",
      notifications: 0,
      enabled: featureEnabled("internal_development"),
      active: false,
    },
    {
      text: "Preferences",
      icon: "user-cog",
      iconStyle: "fas",
      link: "#preferences",
      notifications: 0,
      enabled: false,
      active: false,
    },
  ];

  function activate(i, link) {
    preferences_active = false;
    suborg_active = false;
    notifications_active = false;
    for (let o of state) {
      o.active = false;
    }

    if (link == "#preferences") {
      preferences_active = true;
    }
    state[i].active = true;

    window.location.hash = link;
  }

  let reviewItemsPromise = checkIfReviewsPending();

  onMount(() => {
    for (let i = 0; i < state.length; i++) {
      let o = state[i];
      if (o.link == hash) {
        activate(i, o.link);
      }
    }
  });

  function markAllUnactive() {
    for (let i = 0; i < state.length; i++) {
      state[i].active = false;
    }
  }
  export let hover = false;
</script>

<div
  class="container"
  on:mouseover={() => (hover = true)}
  on:focus={() => (hover = true)}
  on:mouseout={() => (hover = false)}
  on:blur={() => (hover = false)}
>
  <div class="menu">
    <div class="logo">
      <img
        class="large-logo"
        class:large-logo-hover={hover}
        src="/images/phoenix.png"
        alt="logo"
      />
      <img
        class="small-logo"
        class:small-logo-hover={hover}
        src="/images/logo_small.png"
        alt="logo"
      />
    </div>
    <div class="menu-items">
      <div class="main-items">
        {#each state as item, i}
          {#if item.enabled}
            <a
              href={item.link}
              class="item"
              class:is-active={item.active}
              on:click|preventDefault={() => {
                activate(i, item.link);
              }}
            >
              <div class:item-icon-hover={hover} class="item-icon">
                <i class="{item.iconStyle} fa-fw fa-{item.icon}" />
              </div>
              <div class:item-text-hover={hover} class="item-text">
                {item.text}
              </div>
              {#if i == 5}
                {#await reviewItemsPromise then reviewItems}
                  {#if reviewItems.exists}
                    <div
                      class:desktop-hover={hover}
                      class="item-notification desktop"
                    >
                      <span class="notification">
                        <FAIcon
                          icon="exclamation-circle"
                          iconStyle="solid"
                          iconSize="large"
                        />
                      </span>
                    </div>
                    <div
                      class:mobile-hover={hover}
                      class:collapse-menu={!hover}
                      class="item-notification mobile"
                    >
                      <span class="notification">
                        <FAIcon
                          icon="exclamation-circle"
                          iconStyle="solid"
                          iconSize="sm"
                        />
                      </span>
                    </div>
                  {/if}
                {/await}
              {/if}
            </a>
          {/if}
        {/each}
      </div>
      <div class="bottom-items">
        <div
          class="bottom-item has-bottom-space"
          class:is-active={notifications_active}
          on:click={() => {
            notifications_active = true;
            preferences_active = false;
            suborg_active = false;
            markAllUnactive();
            window.location = "#notifications";
          }}
        >
          <div class:item-icon-hover={hover} class="item-icon">
            <i class="fas fa-fw fa-bell" />
          </div>
          <div class:item-text-hover={hover} class="item-text">Alerts</div>
          {#if $has_unread_notification}
            <span class="notification-count">
              {$count_unread_notification}
            </span>
          {/if}
        </div>
        <div
          class="bottom-item has-bottom-space"
          class:is-active={preferences_active}
          on:click={() => {
            preferences_active = true;
            suborg_active = false;
            notifications_active = false;
            markAllUnactive();
            window.location = "#admin";
          }}
        >
          <div class:item-icon-hover={hover} class="item-icon">
            <i class="fas fa-fw fa-user-cog" />
          </div>
          <div class:item-text-hover={hover} class="item-text">Admin</div>
        </div>
        <div
          class="bottom-item has-bottom-space"
          class:is-active={suborg_active}
          on:click={() => {
            suborg_active = true;
            preferences_active = false;
            notifications_active = false;
            showChooseCompany = true;
            markAllUnactive();
          }}
        >
          <div class:item-icon-hover={hover} class="item-icon">
            <i class="fas fa-fw fa-repeat" />
          </div>
          <div class:item-text-hover={hover} class="item-text">Switch Org</div>
        </div>
        <div
          class="bottom-item has-bottom-space"
          on:click={() => {
            window.location = "/logout";
            window.sessionStorage.removeItem("showOnceGuideDialog");
          }}
        >
          <div class:item-icon-hover={hover} class="item-icon">
            <i class="fas fa-fw fa-sign-out" />
          </div>
          <div class:item-text-hover={hover} class="item-text">Log Out</div>
        </div>
      </div>
    </div>
  </div>
</div>

{#if showChooseCompany}
  <ChooseCompanyModal
    on:close={() => {
      showChooseCompany = false;
      window.sessionStorage.removeItem("boilerplate_company");
      window.location.reload();
    }}
  />
{/if}

<style>
  .container {
    position: fixed;
    left: 0px;
    top: 0px;
    /* border-right: 1px solid black; */
    height: 100%;
    box-shadow: 5px 0px 40px 6px rgba(25, 84, 140, 0.08);
    overflow: hidden;
    width: 40px;
  }

  @media (max-width: 767px) {
    .container {
      display: none;
    }
  }

  .menu-items,
  .main-items {
    display: flex;
    flex-flow: column nowrap;
    align-items: left;
  }

  .bottom-items {
    justify-content: space-between;
  }

  .menu-items {
    justify-content: space-between;
    height: 100%;
  }

  .menu {
    height: 100%;
    display: flex;
    flex-flow: column nowrap;
  }

  .logo > img {
    max-width: 240px;
    height: 30px;
    margin-top: 3rem;
    padding-bottom: 2rem;
  }

  .logo {
    height: 120px;
    justify-content: center;
    display: flex;
    flex-flow: row nowrap;
  }
  .item {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    cursor: pointer;
    padding-top: 0.5rem;
    margin-bottom: 0.5rem;
    padding-bottom: 0.5rem;
    text-decoration: none;
  }

  .item:hover,
  .bottom-item:hover {
    background: rgb(228, 228, 228);
  }

  .bottom-item {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    cursor: pointer;
    padding-top: 0.5rem;
    margin-top: 1rem;
  }

  .has-bottom-space {
    margin-bottom: 0.5rem;
    padding-bottom: 0.5rem;
  }

  .bottom-item.is-active .item-text,
  .bottom-item.is-active .item-icon,
  .item.is-active .item-text,
  .item.is-active .item-icon {
    color: #ffffff;
  }

  .bottom-item.is-active,
  .item.is-active {
    background: #4a5158;
  }

  .item-icon {
    padding: 0 0.6rem;
    font-size: 16px;
    line-height: 24px;
    color: #76808b;
    /* flex-basis: auto; */
    flex: 0 0 0;
    align-items: center;
  }

  .item-icon-hover {
    padding: 0 1.6rem;
  }

  :global(.padded) {
    padding-left: 215px;
  }
  .item-text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;
    color: #76808b;
    margin-left: 0;
    flex: 0 0 auto;
    align-items: center;

    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    -o-user-select: none;
    user-select: none;
  }

  .item-notification {
    align-items: center;

    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 16px;
    line-height: 24px;

    width: 100%;
    text-align: right;
    padding-right: 10%;
  }

  .notification {
    color: #db5244;
    border-radius: 50px;
    padding: 2px 5px;
  }

  .notification-count {
    font-family: "Nunito", sans-serif;
    background: #db5244;
    font-size: 12px;
    color: #fff;
    border-radius: 50px;
    padding: 0px 5px;
    margin-left: 1.5rem;
  }

  .relative {
    position: relative;
  }

  .item-text {
    display: none;
  }
  .large-logo {
    display: none;
  }
  .small-logo {
    display: block;
    width: auto;
  }

  /* .item-icon {
    padding-left: 1rem;
  } */
  @media screen and (min-width: 1024px) {
    .container:hover {
      width: 200px;
    }
    .large-logo {
      display: none;
      width: 180px;
      height: auto !important;
    }

    .large-logo-hover {
      display: block;
    }
    .item {
      justify-content: initial;
    }

    .small-logo {
      display: block;
    }

    .small-logo-hover {
      display: none;
    }

    .item-text {
      display: none;
    }

    .item-text-hover {
      display: block;
    }

    .mobile {
      display: block;
    }

    .desktop {
      display: none;
    }

    .mobile-hover {
      display: none;
    }

    .desktop-hover {
      display: block;
    }

    .collapse-menu {
      display: block;
      position: absolute;
      margin-bottom: 1rem;
    }
  }

  @media only screen and (max-width: 1024px) {
    .desktop {
      display: none;
    }

    .has-bottom-space:last-child {
      margin-bottom: 0;
      padding-bottom: 2 px;
    }

    .item {
      position: relative;
      justify-content: center;
    }
    .mobile.item-notification {
      position: absolute;
      top: 0;
      padding-right: 0px;
    }

    .item-icon {
      padding: 0;
    }

    .bottom-item {
      justify-content: center;
    }

    .notification-count {
      position: absolute;
      top: 0px;
      right: 0px;
      margin-left: unset;
    }
  }

  @media (max-height: 720px) {
    .has-bottom-space {
      padding-top: 0rem;
      padding-bottom: 0rem;
    }
  }
</style>
