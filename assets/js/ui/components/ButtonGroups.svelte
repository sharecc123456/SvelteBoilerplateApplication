<script>
  export let classes = "";
</script>

<div class="buttons {classes}">
  <slot/>
</div>

<style>
  .buttons{
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
  }
  @media (max-width: 400px) {
    .flex-direction-column{
      flex-direction: column;
    }
  }
</style>