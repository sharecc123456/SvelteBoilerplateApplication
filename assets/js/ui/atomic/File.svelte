<script>
  import { createEventDispatcher } from "svelte";

  export let name = "filen_name.jpg";
  export let type = "auto";
  export let showDelete = true;

  const dispatch = createEventDispatcher();

  if (type == "auto") {
    if (
      name.includes(".jpg") ||
      name.includes(".png") ||
      name.includes(".jpeg")
    ) {
      type = "image";
    } else if (name.includes(".docx") || name.includes(".doc")) {
      type = "word";
    } else if (name.includes(".pdf") || name.includes(".pdfa")) {
      type = "pdf";
    } else {
      type = "default";
    }
  }

  function dispatchDeleteEvent() {
    dispatch("fileDeleted");
  }
</script>

<div class="container">
  <div class="img">
    {#if type == "image"}
      <i class="far fa-image" />
    {:else if type == "word"}
      <i class="far fa-file-word" />
    {:else if type == "pdf"}
      <i class="far fa-file-pdf" />
    {:else if type == "default"}
      <i class="far fa-file-alt" />
    {/if}
  </div>
  <div class="text">
    {name}
  </div>
  {#if showDelete}
    <div on:click={dispatchDeleteEvent} class="closer">
      <i class="fa-solid fa-trash" />
    </div>
  {/if}
</div>

<style>
  .container {
    display: flex;
    align-items: center;
  }
  .img {
    color: #606972;
    width: 30px;
    height: 30px;
  }
  .text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: normal;
    font-size: 18px;
    line-height: 22px;
    /* identical to box height, or 133% */
    letter-spacing: 0.02em;

    /* Gray 700 */
    color: #606972;

    /* Inside Auto Layout */
    margin: 5px 0px;
  }
  .text {
    flex: 1;
  }

  .closer {
    color: rgb(255, 95, 95);
  }

@media only screen and (max-width: 767px) {
  .text {
    font-size: 16px;
  }
}
</style>
