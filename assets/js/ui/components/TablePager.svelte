<script>
  import FAIcon from "Atomic/FAIcon.svelte";

  export let page = 1;
  export let totalPages = 1;
  export let handlePrevPage = () => {};
  export let handleNextPage = () => {};
</script>

<div class="pagination-container">
  <div class="pagination-actions">
    <div on:click={handlePrevPage}>
      <FAIcon icon="backward" iconStyle="solid" />
    </div>
    <div>{page}</div>
    <div on:click={handleNextPage}>
      <FAIcon icon="forward" iconStyle="solid" />
    </div>
  </div>
  <div>Total Pages: {totalPages}</div>
</div>

<style>
  .pagination-container {
    display: flex;
    justify-content: center;
    align-items: center;
    flex-direction: column;
    gap: 0.5rem;
    color: #76808b;
  }

  .pagination-actions {
    display: flex;
    justify-content: center;
    align-items: center;
  }

  .pagination-actions > div {
    padding: 0.5rem;
    border: 0.5px solid #e2e2e2;
    cursor: pointer;
  }

  .pagination-actions > div:first-child {
    border-top-left-radius: 5px;
    border-bottom-left-radius: 5px;
  }
  .pagination-actions > div:last-child {
    border-top-right-radius: 5px;
    border-bottom-right-radius: 5px;
  }
</style>
