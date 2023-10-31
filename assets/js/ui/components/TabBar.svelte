<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  import { createEventDispatcher } from "svelte";
  export let tabs, current_tab;
  export let container_classes = "";

  const dispatch = createEventDispatcher();

  function changeTab(i) {
    dispatch("changeTab", {
      tab_index: i,
    });
  }
</script>

<ul class="tab-container {container_classes}">
  {#each tabs as { name, icon }, i}
    <li class="tab-list {current_tab == i ? 'active-tab' : ''}">
      <span class="item" on:click={() => changeTab(i)}>
        <i><FAIcon iconStyle="regular" {icon} /></i>
        {name}
      </span>
    </li>
  {/each}
</ul>

<style>
  .sticky {
    position: sticky;
    top: 4.5rem;
    background-color: #fcfdff;
    z-index: 10;
  }

  .sticky-admin {
    top: 6.5rem;
  }

  .margin-x {
    margin: 0 16px !important;
  }
  .tab-container {
    display: grid;
    grid-auto-flow: column;
    justify-content: center;
    list-style: none;
    border-bottom: 1px solid #e6e6e6;
    /* margin: 0 8px; */
    font-family: "Nunito", sans-serif;
  }
  .border-bottom-light {
    border-bottom: 1px solid #fff;
  }
  .tab-list {
    margin-bottom: 1px;
  }
  .item {
    /* background: #fff; */
    display: inline-block;
    padding: 0.5rem 1rem;
    font-weight: 700;
    cursor: pointer;
    color: grey;
  }
  .active-tab {
    background-color: white;
    border: 1px solid #ccc;
    border-bottom: 1px solid #fff;
    border-radius: 5px 5px 0 0;
    margin-bottom: -2px;
    color: #2a2f34;
  }

  @media only screen and (max-width: 767px) {
    .medium .tab-list .item {
      font-size: 16px;
      padding: 0.5rem 1.5rem;
    }
  }
  @media only screen and (max-width: 500px) {
    .item {
      font-size: 12px;
      padding: 0.5rem;
    }
    .medium .tab-list .item {
      font-size: 16px;
      padding: 0.5rem 1.5rem;
    }
  }

  @media only screen and (max-width: 767px) {
    .tab-container {
      justify-content: flex-start;
      padding: 0;
    }
    .item {
      display: flex;
      flex-wrap: wrap;
      justify-content: center;
      font-size: 12px;
      padding: 0.5rem 0.3rem;
      text-align: center;
    }
    .medium .tab-list .item {
      font-size: 16px;
      padding: 0.5rem 1.5rem;
    }
    .tab-container-center-mobile {
      justify-content: center;
    }

    .sticky-admin {
      top: 1rem;
    }
  }
</style>
