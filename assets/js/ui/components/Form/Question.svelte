<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import TextField from "../TextField.svelte";
  import Button from "../../atomic/Button.svelte";
  import { formStore } from "../../../stores/formStore";
  import TextArea from "../TextArea.svelte";
  import AutoComplete from "simple-svelte-autocomplete";

  export let question;
  export let questionIndex;
  export let mergedLabels = [];
  export let allowSes = false;

  function handleLabelCreate(keyword) {
    if (allowSes) {
      console.error("handleLabelCreate: allowSes = TRUE! Invalid state.");
      return keyword;
    }

    return keyword;
  }

  const formTypes = [
    { label: "Short answer", type: "shortAnswer" },
    { label: "Long answer", type: "longAnswer" },
    { label: "Date", type: "date" },
    { label: "Checkboxes", type: "checkbox" },
    { label: "Multiple choice", type: "radio" },
    { label: "Yes/No", type: "decision" },
    { label: "Numeric", type: "number" },
  ];
</script>

<div class="content">
  <div class="questionBox">
    <div class="input">
      <span>Question</span><span class="required">*</span>
      {#if question.title.length < 45}
        <TextField
          focused={true}
          type="text"
          text={"Question"}
          bind:value={question.title}
        />
      {:else}
        <TextArea
          rows="3"
          text={"Question"}
          focused={true}
          bind:value={question.title}
          maxlength="380"
        />
      {/if}
    </div>
    <div class="questionType">
      <span>Question Type</span>
      <select
        class="select"
        bind:value={question.type}
        on:change={() => {
          formStore.handleChangeFormType(question.type, questionIndex);
        }}
      >
        {#each formTypes as formType}
          <option value={formType.type}>
            {formType.label}
          </option>
        {/each}
      </select>
    </div>
  </div>
  <div class="label-input">
    <label for="">Label (for form filling mapping)</label>
    <span class="AutoCompleteStyle">
      <AutoComplete
        matchAllKeywords={true}
        items={mergedLabels}
        create={!allowSes}
        onCreate={handleLabelCreate}
        bind:selectedItem={question.label}
      />
    </span>
  </div>
  <div class="answerContainer">
    {#if question.type == "shortAnswer"}
      <span class="answer">
        <TextField type="text" text="Short answer" disabled />
      </span>
    {:else if question.type == "date"}
      <span class="answer">
        <TextField type="text" text="yyyy-mm-dd" disabled />
      </span>
    {:else if question.type == "longAnswer"}
      <span class="answer">
        <TextArea text="Long answer" disabled />
      </span>
    {:else if question.type == "number"}
      <span class="answer">
        <TextField type="number" text="Numeric answer" disabled />
      </span>
    {:else}
      {#each question.options as val, index}
        <div class="optionsContainer">
          {#if question.type == "checkbox"}
            <div class="icon">
              <FAIcon icon="square" iconStyle="regular" />
            </div>
          {:else}
            <div class="icon">
              <FAIcon icon="circle" iconStyle="regular" />
            </div>
          {/if}
          <div>
            <TextField
              text={val.length === 0 ? `Option ${index + 1}` : val}
              bind:value={val}
            />
          </div>

          <!-- Dont allow to delete the last element -->
          {#if question.options.length > 1}
            <div
              class="addOption tooltip"
              on:click={() => formStore.removeOption(questionIndex, index)}
            >
              <FAIcon icon="times" iconStyle="regular" />
              <span class="tooltiptext">Remove</span>
            </div>
          {/if}
        </div>
      {/each}
      <div class="addButton">
        <span
          on:click={() => {
            formStore.addOption(questionIndex);
          }}
        >
          <Button text="Add option" icon="plus" />
        </span>
      </div>
    {/if}
  </div>
</div>

<style>
  .content {
    display: flex;
    flex-direction: column;
  }

  .questionBox {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
  }

  .select {
    width: 120px;
    height: 30px;
    /* margin-top: 20px; */
    border: 1px solid #b3c1d0;
    border-radius: 5px;
    font-family: "Nunito", sans-serif;
    font-style: normal;
  }

  .input {
    width: 100%;
  }

  .label-input {
    margin-top: 15px;
    width: 70%;
    display: flex;
    flex-direction: column;
  }

  .AutoCompleteStyle :global(.autocomplete-input) {
    background: #ffffff;
    width: 100%;
    text-align: left;
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;
    padding-left: 1rem;
  }

  .AutoCompleteStyle :global(.hide-arrow) {
    width: 100%;
  }

  .answerContainer {
    margin-top: 25px;
  }

  .icon {
    padding-right: 1rem;
    filter: drop-shadow(1px 2px 4px rgba(102, 71, 186, 0.18));
    font-size: 20px;
    color: #4a5158;
  }
  .optionsContainer {
    display: flex;
    flex-direction: row;
    align-items: center;
    margin-bottom: 15px;
  }

  .addOption {
    font-size: 20px;
    margin-left: 15px;
    cursor: pointer;
  }

  .tooltip {
    position: relative;
  }
  .tooltip .tooltiptext {
    visibility: hidden;
    width: max-content;
    background-color: black;
    color: #fff;
    text-align: center;
    border-radius: 6px;
    padding: 6px 6px;
    position: absolute;
    z-index: 1;
    bottom: 0%;
    left: 120%;
    right: 0%;
    font-size: 10px;
  }

  .tooltip:hover .tooltiptext {
    visibility: visible;
  }

  .addButton {
    display: flex;
    margin-top: 25px;
  }

  .required {
    color: rgb(221, 38, 38);
  }

  @media (max-width: 767px) {
    .questionBox {
      display: flex;
      align-items: flex-start;
      flex-direction: column;
      justify-content: space-between;
      gap: 1rem;
      font-size: 14px;
    }

    .questionType {
      display: flex;
      flex-direction: column;
    }
  }
</style>
