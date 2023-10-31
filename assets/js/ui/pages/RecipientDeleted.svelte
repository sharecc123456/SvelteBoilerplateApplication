<script>
</script>

<form class="container">
  <div class="logo">
    <img src="/images/phoenix.png" alt="Boilerplate Logo" />
  </div>

  <div class="text">
    Your account was removed by the requester likely because all requests have
    been fulfilled. Please contact the requester with any questions.
  </div>
</form>

<style>
  .logo {
    width: 50%;
    padding-bottom: 5rem;
  }

  .logo > img {
    width: 100%;
  }
  .container {
    position: fixed;
    top: 0;
    left: 0;
    display: flex;
    flex-flow: column nowrap;
    justify-content: center;
    align-items: center;
    width: 100%;
    height: 100%;
    background-color: #fcfdff;
  }
  .text {
    font-family: "Nunito", sans-serif;
    font-weight: 400;
    font-size: 18px;
    line-height: 28px;
    color: #2a2f34;
    max-width: 35%;
    text-align: center;
    padding: 0 24px;
  }

  @media only screen and (max-width: 780px) {
    .text {
      max-width: none;
      padding: 0 24px;
    }
  }
</style>
