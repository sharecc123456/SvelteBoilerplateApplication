<script>
  import FaIcon from "../../atomic/FAIcon.svelte";
  import Logo from "./Logo.svelte";
</script>

<div class="container">
  <Logo />
  <div class="bad-container__box">
    <div class="notification has-text-centered is-danger">
      <h1 class="title has-text-centered">
        <span><FaIcon icon="exclamation-triangle" /> </span>
        Invalid Signature
      </h1>
      <br />
      <div class="subtitle">
        The signature hash you provided was not found in Boilerplate. Please try
        re-entering the code. If it fails again, it means that the document may
        not have been actually signed or it may have been tampered with.
        <center>
          <strong>You should not trust the document!</strong>
        </center>
        <div class="contract-void__icon">
          <img src="/images/contract_void.svg" alt="Invalid Signature Icon" />
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  .container {
    width: 100%;
    height: 100%;
    background-color: #fcfdff;
  }

  .bad-container__box {
    width: 70%;
    margin: 0 auto;
  }

  .title {
    margin-top: 0px;
    font-weight: 600;
    font-size: 48px;
    line-height: 56px;
  }

  .subtitle {
    font-size: 22px;
    line-height: 26px;
  }

  .notification.is-danger {
    background-color: #ed4337;
    color: #fff;
  }

  .notification {
    background-color: #f5f5f5;
    border-radius: 4px;
    padding: 1.25rem 2.5rem 0 1.5rem;
    position: relative;
  }

  .contract-void__icon {
    margin: auto;
    width: 126px;
    height: 115px;
  }

  .contract-void__icon > img {
    margin: auto;
    width: 100%;
    height: 100%;
  }

  .has-text-centered {
    text-align: center !important;
  }
</style>
