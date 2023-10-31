<script>
  import { createEventDispatcher, onMount } from "svelte";
  import Button from "../atomic/Button.svelte";
  import { isNullOrUndefined } from "../../helpers/util";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage";

  const dispatch = createEventDispatcher();

  export let expirationInfo = {};
  let expirationDate, dateString;
  let noExpirationDate;
  let modal;
  let radioButtonGroup = 0;
  let now = new Date(),
    month,
    day,
    year;
  export let submitButtonText = "Continue";
  export let isSumbitButtonDisabled = false;

  const NAEXPIRATIONTYPE = "N/A";
  const UNSUREXPIRATIONTYPE = "Unsure";

  const createExpirationProperty = () => {
    formatCalenderDate();
    const hasExpirationInfo = Object.keys(expirationInfo).length > 0;
    if (hasExpirationInfo) {
      const hasExpirationDate = expirationInfo.type === "date";
      if (hasExpirationDate) {
        radioButtonGroup = 0;
        expirationDate = expirationInfo.value;
        return;
      }

      return expirationInfo.value === "N/A"
        ? (radioButtonGroup = 1)
        : (radioButtonGroup = 2);
    } else {
      expirationDate = [year, month, day].join("-");
    }
  };

  const formatCalenderDate = () => {
    (month = "" + (now.getMonth() + 1)),
      (day = "" + (now.getDate() + 1)),
      (year = now.getFullYear());

    if (month.length < 2) month = "0" + month;
    if (day.length < 2) day = "0" + day;

    dateString = [year, month, day].join("-");
  };

  onMount(() => {
    createExpirationProperty();
  });

  export let title = "When does this expire?";
  export let hideX = false;

  const close = () => dispatch("close");
  const submit = () => {
    if (
      isNullOrUndefined(radioButtonGroup) ||
      (radioButtonGroup === 0 && !expirationDate)
    ) {
      return showToast("Error! field cannot be emtpy", 1000, "error", "MM");
    }
    const selectedOptionType = radioButtonGroup === 0 ? "date" : "str";
    const selectedValue =
      radioButtonGroup === 0
        ? expirationDate
        : radioButtonGroup === 1
        ? NAEXPIRATIONTYPE
        : UNSUREXPIRATIONTYPE;
    const data = { type: selectedOptionType, value: selectedValue };
    dispatch("submit", { data });
  };
</script>

<svelte:window />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    <span class="modal-header">{title}</span>
    <div class="modal__content__body">
      <div class="row" on:click={() => (radioButtonGroup = 0)}>
        <label>
          <input
            type="radio"
            bind:group={radioButtonGroup}
            name="radioButtonGroup"
            value={0}
          />
        </label>
        <p class="reset-margin" style="margin-right: 1%">Select date</p>
        <span>
          <input
            type="date"
            min={dateString}
            bind:value={expirationDate}
            disabled={radioButtonGroup !== 0}
            style="font-size: 14px;"
            onfocus="this.showPicker()"
          />
        </span>
      </div>
      <div
        class="row"
        style="width: 20%;"
        on:click={() => {
          radioButtonGroup = 1;
          noExpirationDate = NAEXPIRATIONTYPE;
        }}
      >
        <label>
          <input
            type="radio"
            bind:group={radioButtonGroup}
            name="radioButtonGroup"
            value={1}
          />
        </label>
        <span> N/A </span>
      </div>
      <div
        class="row"
        style="width: 20%;"
        on:click={() => {
          radioButtonGroup = 2;
          noExpirationDate = UNSUREXPIRATIONTYPE;
        }}
      >
        <label>
          <input
            type="radio"
            bind:group={radioButtonGroup}
            name="radioButtonGroup"
            value={2}
          />
        </label>
        <span> Unsure </span>
      </div>
    </div>

    <div
      class="submit-buttons"
      style="grid-template-columns: repeat(3, minmax(0, 1fr))"
    >
      <span class="submit-child-buttons" style="grid-area: b;" on:click={close}>
        <Button color="white" text="Back" />
      </span>
      <span
        class="submit-child-buttons"
        style="grid-area: b;"
        on:click={() => (isSumbitButtonDisabled ? () => {} : submit())}
      >
        <Button
          color="secondary"
          text={submitButtonText}
          disabled={isSumbitButtonDisabled}
        />
      </span>
    </div>

    <div on:click={close} class="modal-x" class:hideX>
      <i class="fas fa-times" />
    </div>
  </div>
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .reset-margin {
    margin: 0;
  }

  .row {
    display: flex;
    align-items: center;
    cursor: pointer;
  }

  .modal__content__body {
    margin: 1rem;
    font-family: sans-serif;
    font-size: 1.2rem;
  }

  .modal__content__body > div:not(:last-child) {
    padding-bottom: 5px;
  }

  .modal__content__body > div {
    padding-top: 5px;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 11;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    width: calc(100vw - 4em);
    max-width: 32em;
    max-height: calc(100vh - 4em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 12;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .modal-x {
    position: absolute;
    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;

    cursor: pointer;
  }

  .submit-buttons {
    display: flex;
    flex-direction: column;
  }

  .submit-child-buttons {
    padding-top: 10px;
  }

  @media only screen and (max-width: 640px) {
    .modal {
      top: 40%;
      width: calc(100vw - 5em);
    }
    .modal-content {
      margin: 0;
      padding: 0;
    }
    .modal-header {
      font-size: 18px;
    }
    .modal-x {
      font-size: 18px;
    }
  }
</style>
