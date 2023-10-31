<script>
  /*This component is rendering one form element. This is for preview for the user when he setup the form or review and the fill for the user.*/
  import Card from "../Card.svelte";
  import TextField from "../TextField.svelte";
  import Radio from "../Radio.svelte";
  import CheckboxInput from "./CheckboxInput.svelte";
  import TextArea from "../TextArea.svelte";
  import Flatpickr from "svelte-flatpickr";
  import "flatpickr/dist/flatpickr.css";
  import "flatpickr/dist/themes/light.css";
  import Instruction from "./Instruction.svelte";

  //question object
  export let question;
  export let entryInput = false;
  export let entryValue = undefined;
  export let isRequestorReview = false;
  // are we rendering for prefill? if true, allow them to edit the _DEFAULT VALUE_.

  //set if element is readOnly(disable the fields)
  export let readOnly = false;

  function handleChange({ detail }) {
    console.log(detail);
    if (entryInput) {
      entryValue = detail[0];
    } else {
      question.value = detail[0];
    }
  }
</script>

<Card>
  <div class="inner-content">
    {#if question.type == "shortAnswer" && !question.is_numeric}
      <div class="question">
        <span class="question-title">
          {question.title}
          {#if question.required}
            <span class="required">*</span>
          {/if}
        </span>
      </div>
      <div style="margin-top: 15px; margin-bottom: 15px">
        {#if entryInput}
          <TextField
            type="text"
            disabled={readOnly}
            text={readOnly ? "Preview of text field" : ""}
            bind:value={entryValue}
          />
        {:else if question.value && question.value.length < 45}
          <TextArea
            disabled={readOnly}
            rows="3"
            text={readOnly ? "Preview of text area" : ""}
            focused={true}
            bind:value={question.value}
            maxlength="101"
          />
        {:else}
          <TextField
            focused={true}
            type="text"
            disabled={readOnly}
            text={readOnly ? "Preview of text field" : ""}
            bind:value={question.value}
          />
        {/if}
      </div>
    {:else if question.type == "longAnswer"}
      <div class="question">
        <span class="question-title">
          {question.title}
          {#if question.required}
            <span class="required">*</span>
          {/if}
        </span>
      </div>
      <div style="margin-top: 15px; margin-bottom: 15px">
        {#if entryInput}
          <TextArea
            disabled={readOnly}
            rows="8"
            text={readOnly ? "Preview of text area" : ""}
            bind:value={entryValue}
          />
        {:else}
          <TextArea
            disabled={readOnly}
            rows="8"
            text={readOnly ? "Preview of text area" : ""}
            bind:value={question.value}
          />
        {/if}
      </div>
    {:else if question.type == "date"}
      <div class="question">
        <span class="question-title">
          {question.title}
          {#if question.required}
            <span class="required">*</span>
          {/if}
        </span>
      </div>
      <div style="margin-top: 15px; margin-bottom: 15px">
        {#if readOnly}
          <TextField
            type="text"
            disabled={true}
            value={question?.value
              ? question.value.split("T")[0]
              : "yyyy-mm-dd"}
          />
        {:else if entryInput}
          <div class="date-input">
            <Flatpickr bind:value={entryValue} on:change={handleChange} />
          </div>
        {:else}
          <div class="date-input">
            <Flatpickr bind:value={question.value} on:change={handleChange} />
          </div>
        {/if}
      </div>
    {:else if question.type == "checkbox"}
      <div class="question">
        <span class="question-title">
          {question.title}
          {#if question.required}
            <span class="required">*</span>
          {/if}
        </span>
      </div>
      <div style="margin-top: 15px">
        {#if entryInput}
          <CheckboxInput
            {readOnly}
            options={question.options}
            bind:values={entryValue}
          />
        {:else}
          <CheckboxInput
            {readOnly}
            options={question.options}
            bind:values={question.values}
          />
        {/if}
      </div>
    {:else if question.type == "radio" || question.type == "decision"}
      <div class="question">
        <span class="question-title">
          {question.title}
          {#if question.required}
            <span class="required">*</span>
          {/if}
        </span>
      </div>
      <div style="margin-top: 15px;">
        {#if entryInput}
          <Radio
            type="Form"
            elements={question.options}
            disable={readOnly}
            bind:selectedValue={entryValue}
          />
        {:else}
          <Radio
            type="Form"
            elements={question.options}
            disable={readOnly}
            bind:selectedValue={question.value}
          />
        {/if}
      </div>
    {:else if question.type == "number" || question.is_numeric}
      <div class="question">
        <span class="question-title">
          {question.title}
          {#if question.required}
            <span class="required">*</span>
          {/if}
        </span>
      </div>
      <div style="margin-top: 15px; margin-bottom: 15px">
        {#if entryInput}
          <TextField
            type="number"
            disabled={readOnly}
            text={readOnly ? "Preview of numeric field" : ""}
            bind:value={entryValue}
          />
        {:else}
          <TextField
            type="number"
            disabled={readOnly}
            text={readOnly ? "Preview of numeric field" : ""}
            bind:value={question.value}
          />
        {/if}
      </div>
    {:else if question.type == "instruction"}
      <Instruction instruction={question} mode="view" />
    {:else}
      <!--Message for the future developers. MJ-->
      Invalid question type set, please extend the form! (type: {question.type})
    {/if}
    <div class="question-id">
      Id: {question.id}
      {isRequestorReview ? `Label: ${question.label}` : ""}
    </div>

    {#if !readOnly || question.type !== "instruction"}
      <div class="error">
        {#if (question.type === "radio" || question.type === "checkbox" || question.type == "decision") && question.required}
          {#if !(entryInput ? entryValue?.length : question.values?.length)}
            Input is required
          {/if}
        {:else if question.type === "date" && question.required}
          {#if entryInput ? entryValue === undefined : question.value === null}
            Input is required
          {/if}
        {:else if question.type == "number"}
          {#if !(entryInput ? entryValue : question.value)}
            Input is required
          {:else if isNaN(entryInput ? entryValue : question.value) && question.is_numeric}
            Input must be a number
          {/if}
        {:else if question.type === "date"}
          {#if !(entryInput ? entryValue : question.value) && question.required}
            Input is required
          {/if}
        {:else if question.required && !(entryInput ? entryValue?.trim().length : question.value?.trim().length)}
          Input is required
        {/if}
      </div>
    {/if}
  </div>
</Card>

<style>
  .error {
    font-size: 0.9rem;
    color: #f61313;
  }

  .inner-content {
    display: flex;
    flex-direction: column;
    justify-content: left;
  }

  .date-input :global(.flatpickr-input) {
    background: #ffffff;
    width: 100%;
    min-width: 100%;
    max-width: 100%;
    text-align: left;
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;
    padding: 0.5rem 1rem;
  }

  :global(.flatpickr-calendar) {
    font-family: Nunito, sans-serif;
  }

  :global(.flatpickr-day.selected) {
    background: #2a2f34 !important;
    -webkit-box-shadow: none;
    box-shadow: none;
    color: #fff;
    border-color: #2a2f34 !important;
  }

  :global(.flatpickr-months .flatpickr-next-month:hover svg) {
    fill: #2a2f34 !important;
  }
  .question {
    font-size: 16px;
    letter-spacing: 0.1px;
    line-height: 24px;
    color: #202124;
    font-weight: 400;
    display: -webkit-box;
    display: -webkit-flex;
    display: flex;
    flex-flow: row nowrap;
    width: 100%;
    word-break: break-word;
    justify-content: space-between;
  }

  .question-id {
    color: #848484;
    font-size: 10px;
  }

  .required {
    color: #d93025;
    -webkit-box-flex: 1 1 16px;
    -webkit-flex: 1 1 16px;
    flex: 1 1 16px;
    margin-right: 24px;
    padding-left: 0.25em;
  }
</style>
