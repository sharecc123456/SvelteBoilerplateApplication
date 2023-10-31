<script>
  export let status = 0;
  export let date;
</script>

<div class="doc-status">
  <div>
    {status === 0 ? "Open" : "Submitted"}
  </div>
  <div>{date}</div>
</div>

<style>
  .doc-status {
    display: none;
  }
  @media only screen and (max-width: 767px) {
    .doc-status {
      display: flex;
      justify-content: space-between;
      font-size: 13px;
      color: #2a2f34 !important;
    }
  }
</style>
