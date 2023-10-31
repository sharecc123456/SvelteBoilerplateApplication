<script>
  import Button from "../../atomic/Button.svelte";
  export let handleFileClick = () => {};
  export let filereq = {};
  import { createEventDispatcher } from "svelte";
  import { getValidUrlLink } from "../../../helpers/util";
  const dispatch = createEventDispatcher();

  const handleOnProgressEvents = (buttonClicked) => {
    dispatch("onProgressEvent", {
      buttonClicked,
    });
  };

  let isClicked = false;
</script>

{#if filereq.type == "file"}
  <div
    on:click={() => {
      handleFileClick();
    }}
  >
    {#if filereq.flags === 4}
      <Button text="Add files" />
      <!-- Open status -->
    {:else if filereq.state.status == 0}
      <Button text="Upload" />
    {:else if filereq.state.status == 1}
      <!-- in-progress req -->
      <div class="actionbtnGroup">
        <span on:click={() => handleOnProgressEvents("submit")}>
          <Button color="primary" text={"Submit"} ignore={true} /></span
        >
        <span
          style="margin-left: 10px"
          on:click={() => handleOnProgressEvents("preview")}
        >
          <Button color="light" text={"Preview"} />
        </span>
      </div>
    {:else if filereq.state.status == 2 || filereq.state.status == 4}
      <!-- submitted or completed requests  -->
      <Button color="gray" text="View" />
    {:else}
      <!-- marked unavailable or returned from review -->
      <Button
        color={filereq.state.status === 5 ? "gray" : "primary"}
        text="Upload"
      />
    {/if}
  </div>
{:else if filereq.type == "task"}
  {#if filereq.link.url && filereq.link.url.trim() !== ""}
    <a href={getValidUrlLink(filereq.link.url)} target="_blank">
      <span on:click={() => (isClicked = true)}>
        <Button
          text={filereq.link?.name != "" ? filereq.link?.name : "Start"}
          color="primary"
          icon="link"
        />
      </span>
    </a>
  {/if}
  <span on:click={handleFileClick}>
    {#if filereq.state.status == 0}
      <Button text="Mark as Done" color={isClicked ? "primary" : "white"} />
    {:else}
      <!-- <Button color="gray" text="Details" /> -->
    {/if}
  </span>
{:else}
  <span on:click={handleFileClick}>
    {#if filereq.state.status == 0}
      <Button text="Fill" color="primary" />
    {:else if filereq.state.status == 2}
      <Button color="gray" text="Update" />
    {:else if filereq.state.status == 4 || filereq.state.status == 5}
      <!-- <Button color="gray" disabled={true} text="Update" /> -->
    {:else}
      <Button color="primary" text="Update" />
    {/if}
  </span>
{/if}

<style>
  a {
    text-decoration: none;
  }
  .actionbtnGroup {
    width: 100%;
    display: flex;
    justify-content: flex-end;
    align-items: center;
  }
  @media only screen and (max-width: 425px) {
    .actionbtnGroup {
      align-items: unset;
    }
  }
</style>
