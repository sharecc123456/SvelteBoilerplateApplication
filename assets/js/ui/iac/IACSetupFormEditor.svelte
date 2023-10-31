<script>
  import { onMount } from "svelte";
  import FormElementRenderer from "../components/Form/FormElementRenderer.svelte";
  import FormTitleEdit from "../components/Form/FormTitleEdit.svelte";
  import FormTitleRenderer from "../components/Form/FormTitleRenderer.svelte";
  import { formStore } from "../../stores/formStore";
  import FormCommands from "../components/Form/FormCommands.svelte";
  import Instruction from "../components/Form/Instruction.svelte";
  import Question from "../components/Form/Question.svelte";
  import Card from "../components/Card.svelte";
  import Button from "../atomic/Button.svelte";
  import {
    formCreateShadow,
    formUpdateShadow,
    getFormById,
  } from "BoilerplateAPI/Form";

  export let iacField = undefined;
  export let showTableForm;
  let isPreview = false;
  let currentIndex = 0;
  let isFormCreate = false;
  function isFormValid() {
    return true;
  }

  async function handleAddForm() {
    if (
      $formStore.questions.title == undefined ||
      $formStore.questions.title == null ||
      $formStore.questions.title == ""
    ) {
      alert("Form Title cannot be empty - please add a title.");
      return;
    }
    formStore.addForm();
    let reply = await formCreateShadow($formStore.forms[0], iacField.id);
    if (reply.ok) {
      let data = await reply.json();
      console.log({ handleAddFormReply: data });
      iacField.repeat_entry_form_id = data.form_id;
      showTableForm = false;
    } else {
      console.log({ handleAddFormReply: reply });
      alert("failed to create shadow form, see js console.");
    }
  }

  async function handleUpdateForm() {
    if (
      $formStore.questions.title == undefined ||
      $formStore.questions.title == null ||
      $formStore.questions.title == ""
    ) {
      alert("Form Title cannot be empty - please add a title.");
      return;
    }
    formStore.addForm();
    let reply = await formUpdateShadow($formStore.forms[0], iacField.id);
    if (reply.ok) {
      let data = await reply.json();
      console.log({ handleUpdateFormReply: data });
      showTableForm = false;
    } else {
      console.log({ handleUpdateFormReply: reply });
      alert("failed to update shadow form, see js console.");
    }
  }

  onMount(() => {
    console.log(iacField);
    if (iacField.repeat_entry_form_id) {
      // load the form
      getFormById(iacField.repeat_entry_form_id).then((x) => {
        if (x.ok) {
          x.json().then((form) => {
            console.log({ msg: "IACSetupFormEditor/form", form: form });
            formStore.loadForms([form]);
            formStore.selectForm(0);
            isFormCreate = false;
          });
        } else {
          alert("failed to load existing form!");
        }
      });
    } else {
      // setup the form editor
      formStore.reset();
      formStore.addDetails(
        "", // title
        "", // description
        true, // has_repeat_entries
        false, // has_repeat_vertical
        iacField.label // form_repeat_label
      );
      isFormCreate = true;
    }
  });
</script>

<main id="anchor-top" class="mainContainer">
  <div class="innerContent">
    <div class="form-container">
      <div class="desktop-only">
        {#if !isPreview}
          <h1>Table Editor</h1>
        {:else}
          <h1>Table Preview</h1>
        {/if}
      </div>

      <div class="mobile-only-form form-title">
        <span class="form-heading"
          >{!isPreview ? `Table Editor` : `Table Preview`}</span
        >
      </div>

      <div class="form-body">
        <div style="padding-top: 12px;">
          {#if !isPreview}
            <Card isHeader={true}>
              <FormTitleEdit
                repeatEntriesBlocked={true}
                formElement={$formStore.questions}
              />
              <FormCommands hideRemove={true} />
            </Card>
          {:else}
            <FormTitleRenderer
              title={$formStore.questions.title}
              description={$formStore.questions.description}
            />
          {/if}
        </div>
        {#if $formStore.questions.formFields !== undefined}
          {#each $formStore.questions.formFields as question, index}
            <div style="padding-top: 12px;">
              {#if !isPreview}
                <Card
                  setSelected={() => {
                    currentIndex = index;
                  }}
                  isSelected={currentIndex == index ? true : false}
                >
                  {#if question.type === "instruction"}
                    <Instruction instruction={question} />
                  {:else}
                    <Question
                      {question}
                      allowSes={false}
                      mergedLabels={[]}
                      questionIndex={index}
                    />
                  {/if}
                  <FormCommands {question} {index} />
                </Card>
              {:else if question.type === "instruction"}
                <Instruction instruction={question} mode="view" />
              {:else}
                <FormElementRenderer {question} readOnly={true} />
              {/if}
            </div>
          {/each}
        {/if}
        {#if isFormCreate}
          <div
            style="display: flex;
    justify-content: center;
    height: 50px;
    align-items: flex-end;"
          >
            <span
              style="width: 50%;"
              on:click={() => {
                if (isFormValid()) {
                  if (isFormCreate) {
                    handleAddForm();
                    return;
                  }

                  handleUpdateForm();
                }
              }}
            >
              <Button color="secondary" text={"Create Form"} />
            </span>
          </div>
        {:else}
          <div
            style="display: flex;
    justify-content: center;
    height: 50px;
    align-items: flex-end;"
          >
            <span
              style="width: 50%;"
              on:click={() => {
                if (isFormValid()) {
                  handleUpdateForm();
                } else {
                  alert("Invalid form");
                }
              }}
            >
              <Button color="secondary" text={"Update Form"} />
            </span>
          </div>
        {/if}
      </div>
    </div>
  </div>
</main>

<style>
  .mainContainer {
    display: flex;
    justify-content: center;
    padding: 70px;
    padding-top: 0px;
  }

  .innerContent {
    width: 650px;
    font-family: "Nunito", sans-serif;
  }

  .form-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
  }

  .mobile-only-form {
    display: none !important;
  }
  .form-title {
    display: flex;
    width: 100%;
    justify-content: space-around;
  }
  .form-body {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
  }
  .form-heading {
    justify-content: center;
    font-size: 1.5rem;
  }

  @media only screen and (max-width: 767px) {
    .desktop-only {
      display: none;
    }
    .mainContainer {
      padding: 70px 10px;
    }
    .innerContent {
      max-width: 100%;
    }
  }
</style>
