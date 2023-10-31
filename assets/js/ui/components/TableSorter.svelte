<script>
  import FAIcon from "Atomic/FAIcon.svelte";

  export let sort = "";
  export let column = "";
  export let sortDirection = "asc";
</script>

{#if sort === column}
  {#if sortDirection === "asc"}
    <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
  {:else}
    <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
  {/if}
{:else}
  <div><FAIcon iconStyle="solid" icon="sort" /></div>
{/if}
