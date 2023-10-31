<script>
  import FAIcon from "Atomic/FAIcon.svelte";
  export let sortState = (a, b) => {};
  export let assignments = [];
  export let sticky = false;

  const sortType1 = 1; // Recipient Name
  const sortType2 = 1;
</script>

<div class="recipient-info" class:sticky>
  <div class="td chevron" />
  <div class="td name name-head">
    Checklist
    <div
      class="sortable"
      on:click|stopPropagation={() => {
        sortState(assignments, 1);
      }}
    >
      {#if sortType1 == 1}
        <div><FAIcon iconStyle="solid" icon="sort" /></div>
      {:else if sortType1 == 2}
        <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
      {:else if sortType1 == 3}
        <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
      {/if}
    </div>
  </div>
  <div class="td status status-head" style="display: flex;">
    Status
    <div
      class="sortable"
      on:click|stopPropagation={() => {
        sortState(assignments, 2);
      }}
    >
      {#if sortType2 == 1}
        <div><FAIcon iconStyle="solid" icon="sort" /></div>
      {:else if sortType2 == 2}
        <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
      {:else if sortType2 == 3}
        <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
      {/if}
    </div>
  </div>
  <div class="td status status-head" style="display: flex;">
    Next
    <div
      class="sortable"
      on:click|stopPropagation={() => {
        sortState(assignments, 3);
      }}
    >
      {#if sortType2 == 1}
        <div><FAIcon iconStyle="solid" icon="sort" /></div>
      {:else if sortType2 == 2}
        <div><FAIcon iconStyle="solid" icon="sort-up" /></div>
      {:else if sortType2 == 3}
        <div><FAIcon iconStyle="solid" icon="sort-down" /></div>
      {/if}
    </div>
  </div>
  <div class="td actions actions-head desktop-only">Actions</div>
</div>

<style>
  .recipient-info {
    width: 100%;
    display: grid;
    grid-template-columns: 40px 2fr;
    grid-template-rows: 1fr 1fr;
    align-items: center;
    grid-template-areas:
      "a b "
      ". c "
      ". d ";
  }
  @media only screen and (min-width: 640px) {
    .recipient-info {
      grid-template-columns: 40px 1.7fr 1fr 1fr 145px;
      grid-template-areas: "a b c d e";
      grid-template-rows: 1fr;
    }
  }
  .sortable {
    cursor: pointer;
    left: 6px;
    top: 2px;
    position: relative;
    color: #76808b;
  }

  .sticky {
    position: sticky;
    top: 137px;
  }

  .status.status-head {
    /* justify-self: center; */
    display: none;
  }
  .actions-head {
    justify-self: center;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .td.chevron {
    flex-grow: 0;
    flex-basis: 30px;
    width: 30px;
    justify-content: center;
    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;
  }

  .td.name {
    flex-grow: 3;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .td.actions {
    justify-content: flex-start;
    align-items: center;
    flex-grow: 1;
  }

  @media only screen and (min-width: 640px) {
    .td.status {
      display: grid;
      justify-items: start;
    }
  }

  @media only screen and (max-width: 767px) {
    .desktop-only {
      display: none;
    }
    .recipient-info {
      grid-template-columns: 1.7fr 1fr 1fr;
      grid-template-rows: unset;
      grid-template-areas: unset;
    }
    .td.chevron {
      display: none;
    }
    .td.actions {
      display: none;
    }
  }
</style>
