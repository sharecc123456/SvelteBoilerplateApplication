<script>
  export let isOnline = true;
</script>

<div id="center-div">
  <div class="bubble">
    <span
      class:online-color={isOnline}
      class:offline-color={!isOnline}
      class="bubble-outer-dot"
    />
  </div>
</div>

<style>
  :root {
    --positive: #30a24c;
    --positive-background: #3e4042;
  }

  .online-color {
    background-color: var(--positive);
  }

  .offline-color {
    background-color: var(--positive-background);
  }

  .bubble {
    display: block;
    position: absolute;
    cursor: pointer;
  }

  .bubble .bubble-outer-dot {
    margin: 1px;
    display: block;
    text-align: center;
    opacity: 1;
    width: 12px;
    height: 12px;
    border-radius: 50%;
  }

  #center-div {
    position: absolute;
    top: 0;
    right: 0;
    bottom: 0;
    left: 0;
    margin: auto;
    width: 14px;
    height: 14px;
  }
</style>
