<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  export let content = "",
    classes = "",
    style = "",
    has_icon = false;
  export let icon = "",
    iconStyle = "regular",
    iconSize = "small";
</script>

<span class="tag {classes}" {style}>
  {#if has_icon}
    <span>
      <FAIcon {icon} {iconStyle} {iconSize} />
    </span>
  {/if}
  <span>
    {content}
  </span>
</span>

<style>
  .tag {
    align-items: center;
    border-radius: 0.375em;
    display: inline-flex;
    font-size: 0.75rem;
    height: 1.5rem;
    justify-content: center;
    line-height: 1.5;
    padding: 0 0.75em;
    white-space: nowrap;
    background-color: #828282;
    color: #fff;
    gap: 0.25rem;
  }
</style>
