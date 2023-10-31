<script>
  import { onMount } from "svelte";

  export let description = "";

  let showReadMore = false;

  onMount(() => {
    // check task description overflow-y
    const descriptionElement = document.querySelector("#task-description");
    if (
      descriptionElement.offsetHeight < descriptionElement.scrollHeight ||
      descriptionElement.offsetWidth < descriptionElement.scrollWidth
    ) {
      showReadMore = true;
    }
  });
</script>

<div class="wrapper">
  <div
    id="task-description"
    style="max-height:200px; display: inline-flex; height: auto; flex-direction: column"
  >
    {@html description}
  </div>
  {#if showReadMore}
    <span style="color: #4badf3;font-size: 12px;">Read more...</span>
  {/if}
</div>

<style>
  .wrapper {
    font-size: 14px;
    font-family: "Nunito", sans-serif;
    color: #000;
  }
  #task-description {
    margin-top: -12px;
    font-style: normal;
    font-weight: normal;
    font-size: 12px;
    line-height: 24px;
    color: #76808b;

    width: 200px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  @media only screen and (min-width: 1024px) {
    .wrapper {
      width: 300px;
    }
  }
</style>
