<script>
  export let scrollY;
  let background_page_header;
  $: {
    if (background_page_header) {
      if (scrollY < 65) {
        background_page_header.style.height = "0px";
      } else {
        background_page_header.style.height = "10px";
      }
    }
  }
</script>

<div class="background-page-header" bind:this={background_page_header} />

<style>
  .background-page-header {
    background: #fcfdff;
    position: sticky;
    top: 0;
    z-index: 10;
  }
</style>
