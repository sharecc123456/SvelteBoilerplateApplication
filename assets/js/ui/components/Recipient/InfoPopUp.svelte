<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import { clickOutside } from "../../../helpers/clickOutside";
  let show = false;
  const toggleShow = () => {
    show = !show;
  };
  export let title = "";
  export let body = "";
</script>

<div class="info">
  <span on:click={toggleShow}>
    <FAIcon icon="info-circle" /> See why
  </span>
  {#if show}
    <div class="info-alert" use:clickOutside on:click_outside={toggleShow}>
      <div class="info-content">
        <h3>{title}</h3>
        <p>
          {body}
        </p>
        <div class="info-close desktop" on:click={toggleShow}>
          <FAIcon icon="times" />
        </div>
        <div class="info-close mobile" on:click={toggleShow}>
          <FAIcon icon="times" iconSize="extrasmall" />
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .info {
    margin-left: 8px;
    position: relative;
  }
  .info-content {
    position: relative;
  }

  .info-close {
    position: absolute;
    top: -12px;
    right: -8px;
  }

  .info-alert {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    padding: 1rem;
    border-radius: 10px;
    position: absolute;
    min-width: 250px;
    z-index: 10;
    bottom: 0;
    left: 20px;
  }

  .info-alert h3 {
    margin: 0;
    padding: 0;
    margin-bottom: 4px;
  }

  .info-alert p {
    margin: 0;
    padding: 0;
  }

  .mobile {
    display: none;
  }

  @media only screen and (max-width: 767px) {
    .mobile {
      display: block;
    }
    .desktop {
      display: none;
    }
    .info-alert {
      width: 200px;
      min-width: unset;
    }
    .info-alert h3 {
      font-size: 14px;
      line-height: 18px;
    }

    .info-alert p {
      font-size: 12px;
      line-height: 16px;
    }

    .info span {
      font-size: 14px;
    }
  }
</style>
