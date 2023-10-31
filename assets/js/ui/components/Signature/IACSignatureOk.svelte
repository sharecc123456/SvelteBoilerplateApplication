<script>
  import Logo from "./Logo.svelte";
  export let signerName
  export let signerEmail;
  export let auditIP;
  export let documentTitle;
  export let insertedAt;
  console.log(signerEmail)
</script>

<div class="container">
  <Logo />
  <div class="signature-ok-container__box">
    <div class="box">
      <h1 class="title has-text-centered">
        Boilerplate Signature Verification
      </h1>
      <h2 class="subtitle has-text-centered">
        The signature hash you provided was verified. See below for details.
      </h2>
      <div style="display: flex; justify-content: space-between;">
        <div class="container__table">
          <div class="table__body">
            <div class="table__row">Signer</div>
            <div class="table__row">{signerName}</div>
          </div>
          <div class="table__body">
            <div class="table__row">Signer Email</div>
            <div class="table__row">{signerEmail}</div>
          </div>
          <div class="table__body">
            <div class="table__row">Signing IP Address</div>
            <div class="table__row">{auditIP}</div>
          </div>
          <div class="table__body">
            <div class="table__row">Signature Timestamp</div>
            <div class="table__row">{insertedAt.replace("T", " ")}</div>
          </div>
          <div class="table__body">
            <div class="table__row">Document Title</div>
            <div class="table__row">{documentTitle || ""}</div>
          </div>
        </div>
        <div>
          <img src="/images/contract_ok.svg" alt="OK Signature Icon" />
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .container {
    max-width: 1334px;
    flex-grow: 1;
    margin: 0 auto;
    position: relative;
    width: auto;
    font-family: sans-serif;
  }

  .box {
    background-color: #fff;
    border-radius: 6px;
    box-shadow: 5px 10px 18px #888888;
    color: #757763;
    display: block;
    padding: 1.25rem;
  }

  .title {
    color: #363636;
    font-size: 2rem;
    font-weight: 600;
    line-height: 1.5;
  }

  .has-text-centered {
    text-align: center;
  }

  .title,
  .subtitle {
    word-break: break-all;
  }

  .subtitle {
    color: #757763;
    font-size: 1.25rem;
    font-weight: 400;
    line-height: 1.25;
  }

  .title:not(.is-spaced) + .subtitle {
    margin-top: -1.25rem;
  }

  .container__table {
    border-collapse: collapse;
    border-spacing: 0;
  }

  .table__body {
    display: table-row-group;
  }

  .table__row {
    display: table-cell;
  }

  .container__table .table__body {
    background-color: rgba(0, 0, 0, 0);
  }

  .container__table {
    background-color: #fff;
    color: #363636;
    display: table;
    border-collapse: collapse;
    border-spacing: 0;
  }

  .container__table .table__row {
    border: 1px solid #dbdbdb;
    border-width: 0 0 1px;
    padding: 0.5em 0.75em;
    vertical-align: top;
  }

  .container__table .table__row:not([align]) {
    text-align: left;
  }
</style>
