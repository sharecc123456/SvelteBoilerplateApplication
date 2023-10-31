<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  export let title = "";
  export let description = "";
  export let icon = "";
  export let iconSize = "";

  const dispatch = createEventDispatcher();
  const openEditDialog = () => dispatch("openEditDialog");
</script>

{#if title}
  <div class="template-info">
    <div class="template-info-text">
      <h2>
        Setup: {title}
      </h2>
      <span on:click={openEditDialog}>
        {#if icon != ""} <FAIcon {iconSize} {icon} /> {/if}
      </span>
    </div>
    {#if description && description !== "[Not set]"}
      <p style="margin: 1px">
        ({description})
      </p>
    {/if}
  </div>
{/if}

<style>
  .template-info {
    display: flex;
    justify-content: center;
    flex-direction: column;
    align-items: center;
    font-size: 12px;
    width: 100%;
  }
  .template-info-text {
    width: 100%;
  }

  @media only screen and (max-width: 1024px) {
    h2 {
      overflow: hidden;
      text-overflow: ellipsis;
      width: 85%;
    }
    p {
      overflow: hidden;
      text-overflow: ellipsis;
      width: 100%;
    }
  }
  @media only screen and (max-width: 767px) {
    h2 {
      line-height: 20px;
      font-size: 18px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      width: 450px;
    }
    p {
      line-height: 16px;
      font-size: 14px;
      overflow: hidden;
      text-overflow: ellipsis;
      width: 450px;
    }
  }
  @media only screen and (max-width: 425px) {
    h2 {
      font-size: 14px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      width: 250px;
    }
    p {
      font-size: 10px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      width: 260px;
    }
  }
</style>
