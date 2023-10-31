<script>
  import { createEventDispatcher } from "svelte";

  import FAIcon from "./FAIcon.svelte";

  export let isSmall = false; // smaller padding
  export let tag = {};
  export let handleTagClick = () => {};
  export let icon = "lock";
  export let allowDeleteTags = false;
  export let backgroundColor = "#fff";

  const dispatch = createEventDispatcher();
</script>

<li
  id={tag.id}
  style={`background: ${backgroundColor}`}
  class="custom-tag"
  class:small={isSmall}
  on:click={() => handleTagClick(tag)}
>
  {#if allowDeleteTags}
    <div
      class="cross bolder-icon"
      on:click|stopPropagation={() => {
        dispatch("onRemoveTag", tag);
      }}
    >
      <FAIcon icon="times-circle" iconStyle="solid" iconSize="large" />
    </div>
  {/if}
  {#if tag.flags === 0}
    <span style="font-size: 10px;"><FAIcon {icon} /></span>
  {/if}
  {tag.name}
</li>

<style>
  :root {
    --background: #fff;
    --font-color: #7f7f7f;
    --purple: #6f42c1;
    --gray-dark: #343a40;
  }

  .custom-tag {
    color: var(--font-color);
    display: inline-block;
    position: relative;
    font-size: 12px;
    letter-spacing: 1.2px;
    margin: 4px 8px 4px 0;
    padding: 6px 9px;
    transition: all 0.5s ease;
    font-weight: 600;
    border-radius: 10px;
    border: 2px solid var(--font-color);
    font-family: sans-serif;
    margin-right: "4px";
  }

  .custom-tag.small {
    padding: 2px 4px;
  }

  .custom-tag:hover {
    background-color: #474745 !important;
    color: white !important;
    cursor: pointer;
  }

  .custom-tag .cross {
    position: absolute;
    top: -12px;
    right: -5px;
    z-index: 11;
    color: #db5244;
    display: none;
  }

  .custom-tag:hover .cross {
    display: block;
  }

  @media only screen and (max-width: 768px) {
    .custom-tag {
      font-size: 9px;
      letter-spacing: 0.1px;
      margin: 4px 8px 4px 0;
      padding: 6px 9px;
      border-radius: 7px;
    }
  }
</style>
