<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import Button from "../atomic/Button.svelte";
  import TextField from "../components/TextField.svelte";
  import DocumentTag from "../pages/requestor_portal/DocumentTag.svelte";
  import FAIcon from "Atomic/FAIcon.svelte";
  import PhoneNumberInput from "Components/PhoneNumberInput.svelte";
  import { onMount } from "svelte";
  import { todayDate } from "../../helpers/dateUtils";
  import { getCompanyId } from "Helpers/Features";
  export let responseBoxTextA = "";
  export let responseBoxTextB = "";
  export let responseBoxTextC = "";
  export let responseBoxTextD = "";
  export let responseBoxTextE = "";
  export let responseBoxTextF = "";
  export let responseBoxTags = [];
  export let companies = [];
  export let duplicateAssign = false;
  export let SearchEmail = "";
  export let submitClicked = false;
  export let tagsSelected = [];

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;
  let company_id = 0;
  let today;
  onMount(async () => {
    responseBoxTextA = SearchEmail;
    today = todayDate();
    company_id = await getCompanyId();
  });
  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  function submit() {
    submitClicked = true;
    if (responseBoxTextD == "") {
      responseBoxTextD = "-";
    }

    dispatch("message", {
      email: responseBoxTextA,
      firstName: responseBoxTextB,
      lastName: responseBoxTextC,
      organization: responseBoxTextD,
      phone_number: responseBoxTextE,
      start_date: new Date(responseBoxTextF),
      tags: responseBoxTags,
    });
  }
  function validate_email(email) {
    if (
      /(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])/.test(
        email
      )
    ) {
      return false; // Returns false as in this is disabled is false and the button is enabled
    }
    return true;
  }

  function validate_phone_number(phone_number) {
    if (
      /^[\+]?[(]?[0-9]{3}[)]?[-\s\.]?[0-9]{3}[-\s\.]?[0-9]{4,6}$/im.test(
        phone_number
      ) ||
      phone_number.length == 0
    ) {
      return false;
    }

    return true;
  }
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    <span
      class="modal-header"
      style="display: flex;
    flex-direction: column;"
    >
      <span> Add A New Contact </span>
      <span
        class="modal-subheader message"
        style="font-weight: bold; color: #76808B"
      >
        To show previously deleted contacts, go to Contacts tab and switch 'show
        deleted contacts'.
      </span>
    </span>

    <div class="modal-subheader">
      Email<span class="required">&nbsp;*</span>
      <span
        style="color: {validate_email(responseBoxTextA.toLowerCase())
          ? !responseBoxTextA
            ? 'grey'
            : 'red'
          : 'green'};"
      >
        <span style="color: grey; padding-left: 0.25rem;"
          >Enter a Valid Email</span
        >
        {#if !responseBoxTextA}
          <!-- No case for ONLY Empty Email -->
        {:else if validate_email(responseBoxTextA.toLowerCase())}
          <FAIcon icon="times-circle" /><span style="padding-left: 0.25rem;" />
        {:else}
          <span style="color: green; padding-left: 0.25rem;"
            >This looks like an email</span
          >
          <FAIcon icon="check-circle" /><span style="padding-left: 0rem;" />
        {/if}
      </span>
    </div>
    <div class="input">
      <TextField
        bind:value={responseBoxTextA}
        text={responseBoxTextA == "" ? "person@example.com" : responseBoxTextA}
      />
    </div>
    <div class="modal-subheader">
      First Name<span class="required">&nbsp;*</span>
    </div>
    <div class="input">
      <TextField bind:value={responseBoxTextB} text={"John"} tabIndex="1" />
    </div>
    <div class="modal-subheader">Last Name</div>
    <div class="input">
      <TextField bind:value={responseBoxTextC} text={"Doe"} tabIndex="2" />
    </div>
    <div class="modal-subheader">Company / Org.</div>
    <div class="input">
      <TextField
        bind:value={responseBoxTextD}
        text={"ACME, Inc. (Not Required)"}
        tabIndex="3"
        datalistId="companies"
        dropdownEnabled={true}
        dropDownContents={companies}
      />
    </div>
    <div class="modal-subheader">Phone Number</div>
    <div class="input">
      <PhoneNumberInput bind:value={responseBoxTextE} />
    </div>
    <div class="modal-subheader">Start Date</div>
    <div class="input">
      <input
        style="width: 97%;
                  padding: 8px;
                  border: 1px solid #b3c1d0;
                  border-radius: 5px;"
        maxlength="4"
        pattern="[1-9][0-9]{3}"
        max={"9999-12-31"}
        type="date"
        onfocus="this.showPicker()"
        bind:value={responseBoxTextF}
      />
    </div>
    <div class="modal-subheader">Tags</div>
    <div class="input">
      {#if company_id != 0}
        <DocumentTag
          companyID={company_id}
          tagType={"recipient"}
          templateTagIds={responseBoxTags}
          bind:tagsSelected
        />
      {/if}
    </div>

    {#if duplicateAssign}
      <span class="duplicate-error">Contact has been already added</span>
    {/if}

    <div class="submit-buttons">
      <div on:click={close}>
        <Button color={"gray"} text={"Cancel"} tabIndex="4" />
      </div>

      <div
        on:click={() => {
          if (
            !(responseBoxTextA == "" ||
            responseBoxTextB == "" ||
            responseBoxTextB.length > 40 ||
            responseBoxTextC.length > 40 ||
            responseBoxTextA.length > 40 ||
            responseBoxTextC == "" ||
            submitClicked ||
            validate_email(responseBoxTextA.toLowerCase())
              ? true
              : false || validate_phone_number(responseBoxTextE))
          ) {
            submit();
          }
        }}
      >
        <Button
          color={"primary"}
          text={"Add Contact"}
          disabled={responseBoxTextA == "" ||
          responseBoxTextB == "" ||
          responseBoxTextB.length > 40 ||
          responseBoxTextC.length > 40 ||
          responseBoxTextA.length > 40 ||
          responseBoxTextC == "" ||
          submitClicked ||
          validate_email(responseBoxTextA.toLowerCase())
            ? true
            : false || validate_phone_number(responseBoxTextE)}
          tabIndex="5"
        />
      </div>
    </div>

    <div on:click={close} class="modal-x">
      <i class="fas fa-times" />
    </div>
  </div>
</div>

<style>
  .required {
    color: rgb(221, 38, 38);
  }
  .duplicate-error {
    color: #db5244;
    font-size: 14px;
    text-align: center;
    display: block;
    margin: 1rem 0 0px;
  }
  .modal-subheader {
    font-family: "Nunito", sans-serif;
    padding-top: 1rem;
    font-style: normal;
    font-weight: 400;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
  }

  .submit-buttons {
    display: flex;
    align-items: center;
    margin-top: 1rem;
    justify-content: space-between;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.1);
    z-index: 998;
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
    z-index: 999;
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
  @media only screen and (max-width: 767px) {
    .modal {
      width: 100vw;
      height: 100vh;
    }
    .modal-subheader.message {
      display: none;
    }
  }
</style>
