<script>
  export let minValue = 0;
  export let maxValue = 0;
  export let value = "";
  export let step = 1;
  export let onDecrementHandler = () => {};
  export let onIncrementHandler = () => {};
</script>

<div class="number-input-container">
  <button
    type="button"
    class="button-decrement"
    on:click={onDecrementHandler}
    disabled={value === minValue}
  />
  <div class="number-input">
    <input
      type="number"
      id="number-input"
      name="inputfield"
      class="number-input-box"
      bind:value
      min="1"
      max="180"
      {step}
    />
  </div>
  <button
    type="button"
    class="button-increment"
    on:click={onIncrementHandler}
    disabled={value === maxValue}
  />
</div>

<style>
  :root {
    --color-black: #112c34;
    --color-blue-dark: #65849a;
    --color-mustard-light: #ede6d9;
    --color-white: white;
    --color-mustard-midtone: #9c7830;
    --color-required: rgb(221, 38, 38);
  }

  .number-input-container {
    width: 244px;

    display: grid;
    grid-template-columns: 25% 40% 25%;
  }

  .number-input {
    width: 100%;

    display: flex;
    flex-direction: row;

    background-color: var(--color-white);

    overflow: hidden;
  }

  .number-input-box {
    width: 100%;
    min-width: 90%;
    height: 36px;

    background-color: var(--color-white);

    border: 1px solid var(--color-mustard-light);

    font-size: 16px;
    line-height: 24px;
    text-align: center;
  }

  .number-input-box:focus {
    background-color: white;

    border: 1px solid var(--color-mustard-midtone);

    outline: none;
  }

  /* remove the default appearance spin-buttons */
  input[type="number"]::-webkit-inner-spin-button,
  input[type="number"]::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  input[type="number"] {
    -moz-appearance: textfield;
  }

  button {
    position: relative;

    height: 100%;

    margin-top: 32px;
    padding: 12px 16px;

    background-color: var(--color-white);

    border: 1px solid var(--color-mustard-light);
    border-radius: none;

    cursor: pointer;
  }

  button {
    margin: 0;

    color: var(--color-black);
  }

  button::after,
  button::after {
    content: "";

    position: absolute;

    opacity: 1;

    top: 0;
    left: 0;
    bottom: 0;
    right: 0;

    transition: inherit;

    background-position: center;
    background-repeat: no-repeat;
  }

  .button-decrement:disabled,
  .button-increment:disabled {
    pointer-events: none;
  }

  .button-decrement:disabled::after,
  .button-increment:disabled::after {
    opacity: 0.25;
  }

  .button-decrement::after {
    background-image: url("data:image/svg+xml,%3Csvg width='24' height='24' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M17 12H7' stroke='%23112C34' stroke-width='2' stroke-miterlimit='10' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E%0A");
  }

  .button-increment::after {
    background-image: url("data:image/svg+xml,%3Csvg width='24' height='24' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M12 7V17' stroke='%23112C34' stroke-width='2' stroke-miterlimit='10' stroke-linecap='round' stroke-linejoin='round'/%3E%3Cpath d='M17 12H7' stroke='%23112C34' stroke-width='2' stroke-miterlimit='10' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E%0A");
  }

  .button-decrement {
    border-right: none;
  }

  .button-increment {
    border-left: none;
  }
</style>
