<script>
  import { heicConvert } from "../../heicConverter";
  import { isHeicImageType } from "../../helpers/fileHelper";
  import { Circle } from "svelte-loading-spinners";

  export let item = null;

  const convertHeicImage = async (filename) => {
    return await fetch(`/n/api/v1/dproxy/${filename}`)
      .then((res) => res.blob())
      .then((blob) => heicConvert(blob))
      .then((conversionResult) => {
        var url = URL.createObjectURL(conversionResult);
        return url;
      });
  };
</script>

<div class="image">
  {#if !isHeicImageType(item.filename)}
    <img src={`/n/api/v1/dproxy/${item.filename}`} alt="Request" />
  {:else}
    {#await convertHeicImage(item.filename)}
      <Circle size="16" color="black" />
    {:then url}
      <img src={url} alt="Request" />
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
