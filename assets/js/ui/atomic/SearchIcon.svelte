<script>
  import FAIcon from "./FAIcon.svelte";
</script>

<span class="tooltip">
  <FAIcon icon="search" iconStyle="solid" iconSize="large" />
  <span class="tooltiptext">Search this page</span>
</span>

<style>
  .tooltip {
    position: relative;
    display: inline-block;
  }

  .tooltip .tooltiptext {
    visibility: hidden;
    width: 150px;
    background-color: #4a5157;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 5px 0;

    /* Position the tooltip */
    position: absolute;
    z-index: 1;
    bottom: 105%;
    left: 50%;
    margin-left: -75px;
  }

  .tooltip:hover .tooltiptext {
    visibility: visible;
  }
  @media only screen and (max-width: 767px) {
    .tooltip .tooltiptext {
      display: none;
    }
  }
</style>
