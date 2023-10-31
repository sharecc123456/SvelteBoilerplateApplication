<script>
  import { start_search } from "./../../store";
  import { featureEnabled } from "Helpers/Features";
  import FAIcon from "../atomic/FAIcon.svelte";
  import SearchIcon from "../atomic/SearchIcon.svelte";
  import HamburgerMenu from "./helpers/HamburgerMenu.svelte";
  import ChooseCompanyModal from "../modals/ChooseCompanyModal.svelte";
  import {
    has_unread_notification,
    count_unread_notification,
  } from "./../../store";
  export let hash;
  $: if (hash) {
    hash = hash;
    toggleMenu = false;
  }

  function clickOutside(node) {
    const handleClick = (event) => {
      if (node && !node.contains(event.target) && !event.defaultPrevented) {
        node.dispatchEvent(new CustomEvent("click_outside", node));
      }
    };

    document.addEventListener("click", handleClick, true);

    return {
      destroy() {
        document.removeEventListener("click", handleClick, true);
      },
    };
  }
  let showChooseCompany = false;

  let menus = [
    {
      name: "Start/ Send",
      url: "#directsend",
      icon: "plane",
      iconStyle: "regular",
      enable: true,
    },
    {
      name: "Components",
      url: "#templates",
      icon: "copy",
      iconStyle: "regular",
      enable: true,
    },
    {
      name: "Internal",
      url: "#internal",
      icon: "radiation",
      enable: true,
    },
    {
      name: "Alerts",
      url: "#notifications",
      icon: "bell",
      enable: true,
    },
    {
      name: "Admin",
      url: "#admin",
      icon: "user-cog",
      enable: true,
    },
    {
      name: "Switch Org",
      url: "#",
      icon: "repeat",
      enable: true,
    },
    {
      name: "Logout",
      url: "#signout",
      icon: "sign-out",
      enable: featureEnabled("internal_development"),
    },
  ];

  let hide_search_bar_sections = ["#preferences", "#internal", "#directsend"];
  let filter_search = ["#dashboard"];
  let allow_search_bar = true;

  let toggleMenu = false;
  function handleClickOutside() {
    toggleMenu = false;
  }

  function handleSearch() {
    $start_search = !$start_search;
  }

  $: allow_search_bar = hide_search_bar_sections.includes(hash);

  $: route = hash.split("?")[0];

  $: allow_search_bar = hide_search_bar_sections.includes(hash);
  $: if (hash) {
    $start_search = false;
  }
</script>

<div class="logo {$start_search ? 'min-z-index' : ''}">
  <div class="left">
    <a href="#dashboard">
      <img
        class="logo-img"
        src={$start_search ? "/images/logo_small.png" : "/images/phoenix.png"}
        alt="logo"
      />
    </a>
  </div>
  <div class="right">
    {#if !allow_search_bar}
      <span class="action-icon" on:click={handleSearch}>
        {#if $start_search}
          <FAIcon icon="times-circle" iconStyle="solid" iconSize="large" />
        {:else}
          <SearchIcon />
        {/if}
      </span>
    {/if}

    <HamburgerMenu bind:toggleMenu />
  </div>
</div>

<div class="drawerMenu {toggleMenu ? 'drawerOpen' : ''}">
  <div
    class="drawerContainer"
    use:clickOutside
    on:click_outside={handleClickOutside}
  >
    {#each menus as { name, url, icon, iconStyle, enable }}
      {#if name == "Logout"}
        <a
          class="links {toggleMenu ? 'openLinks' : ''}"
          href={url}
          on:click|preventDefault={() => {
            window.location = "/logout";
          }}
        >
          <p>
            <FAIcon {icon} iconStyle={iconStyle || "solid"} iconSize="large" />
          </p>
          <span>{name}</span>
        </a>
      {:else if name == "Switch Org"}
        <a
          class="links {toggleMenu ? 'openLinks' : ''}"
          href={url}
          on:click|preventDefault={() => {
            showChooseCompany = true;
          }}
        >
          <p>
            <FAIcon {icon} iconStyle={iconStyle || "solid"} iconSize="large" />
          </p>
          <span>{name}</span>
        </a>
      {:else if enable}
        <a
          href={url}
          class="links {toggleMenu ? 'openLinks' : ''} {hash.includes(url)
            ? 'active'
            : ''}"
        >
          <p>
            <FAIcon {icon} iconStyle={iconStyle || "solid"} iconSize="large" />
          </p>
          {#if $has_unread_notification && name == "Alerts"}
            <span>{name}</span>
            <span class="relative">
              <span class="notification-count"
                >{$count_unread_notification}</span
              >
            </span>
          {:else}
            <span>{name}</span>
          {/if}
        </a>
      {/if}
    {/each}
  </div>
</div>

{#if showChooseCompany}
  <ChooseCompanyModal
    on:close={() => {
      showChooseCompany = false;
      window.sessionStorage.removeItem("boilerplate_company");
      window.sessionStorage.removeItem("boilerplate_company_id");
      window.location.reload();
    }}
  />
{/if}

<style>
  .logo,
  .drawerMenu {
    display: none;
  }
  .action-icon {
    color: grey;
    margin-right: 0.8rem;
    cursor: pointer;
  }

  .notification-count {
    font-family: "Nunito", sans-serif;
    position: absolute;
    top: -14px;
    right: 0px;
    background: red;
    font-size: 12px;
    color: #fff;
    border-radius: 50px;
    padding: 0px 5px;
  }

  .relative {
    position: relative;
  }

  @media (max-width: 767px) {
    .logo {
      justify-content: space-between;
      display: flex;
      background: #fff;
      box-shadow: 0 -1px 3px rgba(0, 0, 0, 0.1);
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      z-index: 100;
      padding: 1rem 0;
      font-family: "Nunito", sans-serif;
      font-style: normal;
    }
    .min-z-index {
      z-index: 9;
    }
    .right {
      display: flex;
      justify-content: center;
      align-items: center;
      margin-right: 0.5rem;
    }

    .drawerMenu {
      position: fixed;
      top: 0;
      left: 0;
      width: 0;
      height: 100%;
      background: rgba(0, 0, 0, 0);
      z-index: 99;
      display: block;
      transition: 0.5s;
      font-family: sans-serif;
    }
    .drawerContainer {
      margin-top: 65px;
      height: 100%;
      width: 70%;
      background: rgba(255, 255, 255, 1);
      flex-flow: column;
      align-items: left;
      justify-content: left;
      gap: 10px;
    }

    .drawerOpen {
      width: 100%;
    }

    .logo-img {
      max-width: 220px;
      height: 30px;
      margin-left: 1rem;
    }

    .links {
      width: 100%;
      padding: 0.3rem 0.5rem;
      text-align: center;
      color: grey;
      text-decoration: none;
      cursor: pointer;
      height: 40px;
      display: flex;
      align-items: center;
      justify-content: left;
      margin-left: -250px;
      transition: 0.5s;
    }
    .links span {
      margin-left: 1rem;
    }
    .links p {
      width: 20px;
    }
    .openLinks {
      margin-left: 0;
    }
    .active {
      color: #000;
      font-weight: bold;
    }
  }

  @media (max-width: 400px) {
    .action-icon {
      margin-right: 5px;
    }
  }
</style>
