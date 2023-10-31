<script>
  export let sticky = false;
</script>

<div class="tr th" class:sticky={sticky}>
  <div class="td chevron" />
  <div class="td name name-head">
    Document Name
  </div>
  <div class="td actions actions-head">Actions</div>
</div>

<style>
  .tr.th {
    display: none;
    border-top: 0.5px solid #b3c1d0;
    /* background: white; */
    background: #f8fafd;
    display: grid;
    grid-template-columns: 40px 10fr 1fr;
    justify-items: start;
  }

  .sticky {
    position: sticky;
    top: 137px;
  }

  .th > .td {
    white-space: normal;
    justify-content: left;
    /* background: #fcfdff; */
    font-weight: 600;
    font-size: 14px;
    line-height: 16px;

    height: 37px;
    align-items: center;
  }

  .tr {
    width: 100%;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0px;
  }

  .td.chevron {
    flex-grow: 0;
    flex-basis: 30px;
    width: 30px;
    justify-content: center;
    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;
  }

  .td.name {
    flex-grow: 3;
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }
  .actions-head {
    justify-self: center;
  }

  .td.actions {
    justify-content: flex-start;
    align-items: center;
    flex-grow: 2;
  }
</style>
