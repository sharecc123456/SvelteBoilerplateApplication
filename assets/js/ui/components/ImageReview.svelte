<script>
  import { heicConvert } from "../../heicConverter";
  import { isHeicImageType } from "../../helpers/fileHelper";
  import { createEventDispatcher } from "svelte";
  import { Circle } from "svelte-loading-spinners";

  export let theReview = null;
  export let reviewType = null;

  const convertHeicImage = async (rType, rId) => {
    return await fetch(`/review${rType}/${rId}/download/review`)
      .then((res) => res.blob())
      .then((blob) => heicConvert(blob))
      .then((conversionResult) => {
        var url = URL.createObjectURL(conversionResult);
        return url;
      });
  };

  const dispatch = createEventDispatcher();
</script>

<div class="image">
  {#if !isHeicImageType(theReview.filename)}
    <img
      src={`/review${reviewType}/${theReview.id}/download/review`}
      on:load={dispatch("loaded")}
      alt="Request"
    />
  {:else}
    {#await convertHeicImage(reviewType, theReview.id)}
      <Circle size="16" color="black" />
    {:then url}
      <img src={url} on:load={dispatch("loaded")} alt="Request" />
    {/await}
  {/if}
</div>

<style>
  .image img {
    display: block;
    width: 90%;
    margin: auto;
  }
</style>
