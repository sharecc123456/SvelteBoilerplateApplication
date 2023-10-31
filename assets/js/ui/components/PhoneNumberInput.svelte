<script>
  let target;
  let iti;
  export let value;

  let mountPhoneInput = () => {
    iti = window.intlTelInput(target, {
      separateDialCode: true,
      nationalMode: false,
      formatOnDisplay: true,
    });
  };

  function formatIntlTelInput() {
    if (typeof intlTelInputUtils !== "undefined") {
      // utils are lazy loaded, so must check
      var currentText = iti.getNumber(intlTelInputUtils.numberFormat.E164);
      if (typeof currentText === "string") {
        // sometimes the currentText is an object :)
        iti.setNumber(currentText); // will autoformat because of formatOnDisplay=true
      }
    }

    value = iti.getNumber();
  }
</script>

<svelte:head>
  <link
    rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/17.0.13/css/intlTelInput.css"
  />
  <script
    src="https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/17.0.13/js/utils.js"></script>
  <script
    on:load={mountPhoneInput}
    src="https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/17.0.13/js/intlTelInput.js"></script>
</svelte:head>

<div class="input-with-icon" style={"width: 100%; height: 2.5rem;"}>
  <input
    on:keyup={formatIntlTelInput}
    on:change={formatIntlTelInput}
    type="tel"
    class="input"
    {value}
    bind:this={target}
    maxlength="15"
    style={"height: 2.5rem; width: 100%;"}
  />
</div>

<style>
  .input {
    background: #ffffff;

    width: 100%;
    min-width: 100%;
    max-width: 100%;
    text-align: left;
    /* Gray 300 */
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;

    padding-left: 1rem;
  }

  :global(.iti) {
    width: 100% !important;
  }

  input:hover {
    border: 1px solid #4badf3;
    box-sizing: border-box;
    border-radius: 5px;
  }

  input {
    font-size: inherit;
  }

  .input-with-icon {
    font-family: "Nunito", sans-serif;
    font-style: normal;
  }

  @media only screen and (max-width: 767px) {
    input {
      font-size: 14px;
    }
  }
</style>
