<script>
  import {
    dashboard_filter_modal,
    add_contact_modal,
    user_guide_modal,
  } from "./../../store";
  import { featureEnabled } from "Helpers/Features";
  import { checkIfReviewsPending } from "BoilerplateAPI/Review";
  import FAIcon from "../atomic/FAIcon.svelte";
  import UserGuide from "../pages/requestor_portal/UserGuide.svelte";
  export let hash;

  let active_submenu;

  $: if (hash) {
    hash = hash;
    active_submenu = false;
    $user_guide_modal = false;
  }

  let menus = [
    {
      name: "Dashboard",
      url: "#dashboard",
      icon: "tasks",
    },
    {
      name: "Contacts",
      url: "#recipients",
      icon: "address-book",
    },
    {
      name: "action",
      url: "#checklists",
      icon: "plus-circle",
    },
    {
      name: "Checklists",
      url: "#checklists",
      icon: "clipboard-list",
    },
    {
      name: "Review",
      url: "#reviews",
      icon: "glasses",
    },
  ];

  let sub_menus = [];

  let disabledActionBtnSections = [];

  let reviewItemsPromise = checkIfReviewsPending();

  $: route = hash.split("?")[0];
  $: {
    sub_menus = [
      {
        name: "Start/Send",
        enable: true,
        icon: "plane",
        action: () => {
          $user_guide_modal = true;
          active_submenu = false;
        },
      },
      {
        name: "Dashboard filter",
        enable: route == "#dashboard",
        icon: "filter",
        action: () => {
          $dashboard_filter_modal = true;
        },
      },
      {
        name: "New contact",
        enable: true,
        icon: "plus-circle",
        action: () => {
          window.location.hash = "#recipients";
          $add_contact_modal = true;
        },
      },
      {
        name:
          route == "#checklists" ? "Create new checklist" : "Send checklist",
        enable: featureEnabled("requestor_allow_checklist_creation"),
        icon: "paper-plane",
        action: () => {
          if (route == "#checklists") {
            window.location.hash = "#checklists/new";
          } else {
            window.location.hash = "#checklists";
          }
        },
      },
    ];
  }
</script>

<nav class="bottom-navbar">
  {#each menus as { name, url, icon }}
    {#if name == "action"}
      {#if !disabledActionBtnSections.includes(hash)}
        <span
          on:click|preventDefault={() => {
            active_submenu = !active_submenu;
          }}
          class="links action-button"
        >
          <FAIcon {icon} iconStyle="solid" iconSize="3x" />
        </span>
      {/if}
    {:else}
      <a href={url} class="links {hash.includes(url) ? 'active' : ''}">
        {#if name == "Review"}
          {#await reviewItemsPromise then reviewItems}
            {#if reviewItems.exists}
              <div class="item-notification">
                <FAIcon
                  icon="exclamation-circle"
                  iconStyle="solid"
                  iconSize="large"
                />
              </div>
            {/if}
          {/await}
        {/if}
        <FAIcon {icon} iconStyle="solid" iconSize="large" />
        <span>
          <i>{name}</i>
        </span>
      </a>
    {/if}
  {/each}
</nav>
<div class="submenu {active_submenu ? 'active-submenu' : ''}">
  {#each sub_menus as { name, icon, enable, action }}
    {#if enable}
      <span class="links action-button" on:click={action}>
        <FAIcon {icon} iconStyle="solid" iconSize="large" />
        <span>
          {name}
        </span>
      </span>
    {/if}
  {/each}
</div>

{#if $user_guide_modal}
  <UserGuide useAsComponent={true} />
{/if}

<style>
  .bottom-navbar {
    display: none;
  }

  .submenu {
    display: none;
  }
  span i {
    font-style: normal;
  }

  @media (max-width: 767px) {
    .submenu {
      position: fixed;
      display: flex;
      bottom: 0;
      left: 0;
      right: 0;
      z-index: 50;
      background: #fff;
      display: flex;
      justify-content: space-between;
      font-size: 0.75rem;
      box-shadow: 0 -1px 3px rgba(0, 0, 0, 0.1);
      padding: 1rem 0 0.5rem;
      font-family: "Nunito", sans-serif;
      font-style: normal;
      transition: all 0.3s ease-in-out;
    }
    .active-submenu {
      bottom: 67px;
      z-index: 101;
    }
    .active-submenu::after {
      content: "";
      position: absolute;
      width: 0;
      height: 0;
      box-sizing: border-box;
      border: 10px solid black;
      border-color: transparent;
      z-index: 10;
      transform-origin: 0 0;
      transform: rotate(45deg) translate3d(55%, -55%, 0);
      transition: transform 0.3s cubic-bezier(0.1, 0.82, 0.25, 1);
      border-color: transparent transparent #eee #eee;
      box-shadow: -1px 1px 0px #aaa;
      transform: rotate(-45deg);
      left: calc(50% - 15px);
      bottom: -20px;
    }

    .bottom-navbar {
      position: fixed;
      bottom: 0;
      left: 0;
      right: 0;
      z-index: 100;
      background: #fff;
      display: flex;
      justify-content: space-between;
      font-size: 0.75rem;
      box-shadow: 0 -1px 3px rgba(0, 0, 0, 0.1);
      padding: 1rem 0 0.5rem;
      font-family: "Nunito", sans-serif;
      font-style: normal;
    }

    .links {
      width: 100%;
      display: block;
      padding: 0.3rem 0.5rem;
      text-align: center;
      color: grey;
      text-decoration: none;
      position: relative;
      box-sizing: border-box;
    }
    .links span {
      display: block;
    }
    .item-notification {
      position: absolute;
      top: -5px;
      right: 30px;
      color: red;
    }
    .action-button {
      padding: 0;
      color: #000;
      cursor: pointer;
    }

    .active {
      color: #000;
      font-weight: bold;
    }
    .active span i {
      padding-bottom: 5px;
      border-bottom: 1px solid rgba(0, 0, 0, 0.4);
    }
  }
</style>
