<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "./FAIcon.svelte";

  export let barStyle;
  const dispatch = createEventDispatcher();
</script>

<div
  class="container"
  style={barStyle}
  on:click={() => {
    dispatch("click");
  }}
>
  <FAIcon icon="bars" />
</div>

<style>
  .container:hover {
    color: black;
  }

  .container {
    padding-left: 0.5rem;
    color: #76808b;
    cursor: pointer;
    font-size: 24px;
  }
</style>
