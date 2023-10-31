<script>
  import { createEventDispatcher, onMount } from "svelte";
  import { getCompanyId } from "Helpers/Features";
  import Button from "../../atomic/Button.svelte";
  import DocumentTag from "../../pages/requestor_portal/DocumentTag.svelte";
  export let newR, recps;
  import FAIcon from "Atomic/FAIcon.svelte";
  import PhoneNumberInput from "Components/PhoneNumberInput.svelte";
  const dispatch = createEventDispatcher();
  let company_id = 0;
  export let submitClicked = false;
  export let tagsSelected = [];

  function submit() {
    submitClicked = true;
    dispatch("submit");
  }

  function onEmailEntered() {
    dispatch("keyPressed");
  }

  function getCompanies(obj) {
    const companies = obj.map((recp) => recp.company);
    return [...new Set(companies)];
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

  onMount(async () => {
    company_id = await getCompanyId();
  });
</script>

<form on:submit|preventDefault={submit}>
  <div class="columns">
    <div class="column">
      <div class="form-group ">
        <label for="Email"
          ><span class="is-required">Email</span>
          <span
            style="color: {validate_email(newR.email.toLowerCase())
              ? !newR.email
                ? 'grey'
                : 'red'
              : 'green'};"
          >
            <span style="color: grey; padding-left: 0.25rem;"
              >Enter a Valid Email</span
            >
            {#if !newR.email}
              <!-- No case for ONLY empty Email -->
            {:else if validate_email(newR.email.toLowerCase())}
              <FAIcon icon="times-circle" /><span
                style="padding-left: 0.25rem;"
              />
            {:else}
              <span style="color: green; padding-left: 0.25rem;"
                >This looks like an email</span
              >
              <FAIcon icon="check-circle" /><span style="padding-left: 0rem;" />
            {/if}
          </span>
        </label>
        <input
          id="Email"
          bind:value={newR.email}
          on:keyup={onEmailEntered}
          class="text-input"
          type="email"
          placeholder="person@example.com"
        />
      </div>

      <div class="form-group">
        <label class="is-required" for="first_name">First Name</label>

        <input
          id="first_name"
          bind:value={newR.newRecipientFirstName}
          class="text-input"
          type="text"
          placeholder="John"
        />
        {#if newR.newRecipientFirstName.length > 40}
          <div class="errormessage" id="name">
            {"Character limit (40) reached."}
          </div>
        {/if}
      </div>
    </div>
    <div class="column">
      <div class="form-group">
        <label for="last_name">Last Name</label>
        <input
          id="last_name"
          bind:value={newR.newRecipientLastName}
          class="text-input"
          type="text"
          placeholder="Doe"
        />
        {#if newR.newRecipientLastName.length > 40}
          <div class="errormessage" id="name">
            {"Character limit (40) reached."}
          </div>
        {/if}
      </div>

      <div class="form-group">
        <label for="Company">Company / Org.</label>
        <input
          id="Company"
          list="companies"
          bind:value={newR.organization}
          class="text-input"
          type="text"
          placeholder="ACME, Inc."
        />
        <datalist id="companies">
          {#each getCompanies(recps) as company}
            <option value={company} />
          {/each}
        </datalist>
        {#if newR.organization.length > 40}
          <div class="errormessage" id="name">
            {"Character limit (40) reached."}
          </div>
        {/if}
      </div>
      <div class="form-group">
        <label for="phone_number">Phone Number</label>
        <PhoneNumberInput bind:value={newR.phone_number} />
      </div>
      <div class="form-group">
        <label for="start_date">Start Date</label>
        <!-- please change bind value accordingly to like  newR.start_date -->
        <input
          style="width: 95%;
                padding: 10px;
                border: 1px solid #b3c1d0;
                border-radius: 5px;"
          maxlength="4"
          pattern="[1-9][0-9]{3}"
          max={"9999-12-31"}
          type="date"
          onfocus="this.showPicker()"
          bind:value={newR.start_date}
        />
      </div>
      <div class="form-group">
        <label for="tags">Tags</label>
        {#if company_id != 0}
          <DocumentTag
            companyID={company_id}
            tagType={"recipient"}
            templateTagIds={newR.tags?.id}
            bind:tagsSelected
          />
        {/if}
      </div>
    </div>
  </div>
  <div style="display: flex;">
    <span
      on:click={() => {
        newR.email = "";
        newR.newRecipientFirstName = "";
        newR.newRecipientLastName = "";
        newR.organization = "";
        newR.phone_number = "";
        newR.start_date = "";
        dispatch("cancel");
      }}
      class="addBtn"
    >
      <Button text="Cancel" color="white" />
    </span>
    <span class="addBtn" />
    <span class="addBtn">
      <Button
        type="submit"
        text="Add Contact"
        disabled={newR.newRecipientFirstName.trim() == "" ||
          newR.email.trim() == "" ||
          newR.newRecipientLastName.length > 40 ||
          newR.newRecipientFirstName.length > 40 ||
          newR.organization.length > 40 ||
          submitClicked ||
          validate_email(newR.email.toLowerCase()) ||
          validate_phone_number(newR.phone_number)}
      />
    </span>
  </div>
</form>

<style>
  input::-webkit-calendar-picker-indicator {
    opacity: 100;
  }
  .columns {
    display: flex;
    flex-direction: column;
    gap: 0rem;
  }
  .column {
    flex: 1;
  }
  .form-group {
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
    margin-bottom: 1rem;
  }
  .form-group label {
    margin-bottom: 0.5rem;
  }

  .is-required::after {
    content: "*";
    color: red;
    padding-left: 4px;
  }

  .text-input {
    background: #ffffff;
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;
    padding-left: 1rem;
    height: 40px;
    width: 100%;
    /* width: 202px; */
  }

  .addBtn {
    width: 50%;
    align-self: flex-end;
  }
  .errormessage {
    display: inline-block;
    color: #cc0033;
    font-size: 12px;
    font-weight: bold;
    line-height: 15px;
    margin-bottom: -15px;
  }

  @media only screen and (max-width: 767px) {
    .addBtn {
      width: 50%;
      align-self: start;
    }
  }
</style>
