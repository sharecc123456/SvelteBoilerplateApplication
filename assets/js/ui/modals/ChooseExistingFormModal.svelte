<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Button from "../atomic/Button.svelte";
  import { formStore } from "../../stores/formStore";
  import { createForm, updateContentsAsync } from "../../api/Form";
  import FormElementRenderer from "../components/Form/FormElementRenderer.svelte";
  import EditFormModal from "./EditFormModal.svelte";
  import FormTitleRenderer from "../components/Form/FormTitleRenderer.svelte";
  import { predefinedExistingForms } from "../../helpers/formConstants";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }
  };

  let modal;

  let showPreviewExistingFormModal = false;

  let existingForms = [
    { title: "Personal Info", description: "" },
    { title: "Business Info", description: "" },
  ];

  export let isRecipientAssign = false;
  export let checklistId;
  export let recipientId;
  export let contents;
  export let callback = () => {};

  const addForm = async () => {
    const formData = { checklist_id: checklistId, ...$formStore.forms[0] };
    console.log(formData);
    console.log($formStore.questions, $formStore.forms);

    const data = await createForm(formData);
    contents.forms.push(data);
    contents = contents;

    try {
      await updateContentsAsync(contents);
    } catch (error) {
      alert(error);
    }
    callback(recipientId, checklistId);
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          Select an existing form and add to the list
          <span on:click={close}>
            <slot name="closer" />
          </span>
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>
        <div class="table">
          <div class="tr th">
            <div class="td icon" />
            <div class="td title">Form Details</div>
            <div class="td icon" />
          </div>
          {#each existingForms as form, index}
            <div class="tr">
              <div class="td icon requests-documents-icon">
                <div>
                  <FAIcon icon="rectangle-list" iconStyle="regular" />
                </div>
              </div>
              <div class="td title request-name">
                <div class="name-container">
                  <div class="name-text">
                    {form.title}
                  </div>
                  <div class="filetype-title">
                    {form.description}
                  </div>
                </div>
              </div>
              <div class="td icon action content-right">
                <span
                  on:click={() => {
                    if (isRecipientAssign) {
                      if (checklistId === undefined) {
                        console.error(
                          "ChecklistId is required as parameter if isRecipientAssign is true, please add it!"
                        );
                        return;
                      }
                      formStore.addExistingForm(
                        predefinedExistingForms[form.title]
                      );
                      addForm();
                      close();
                      return;
                    }

                    formStore.addExistingForm(
                      predefinedExistingForms[form.title]
                    );
                    close();
                  }}
                >
                  <Button text="Add" color="primary" />
                </span>
                <span
                  style="margin-right: 1rem;"
                  on:click={() => {
                    formStore.addExistingForm(
                      predefinedExistingForms[form.title],
                      true
                    );
                    showPreviewExistingFormModal = true;
                  }}
                >
                  <Button text="View" color="secondary" />
                </span>
              </div>
            </div>
          {/each}
        </div>
      </div>
    </div>
  </div>
</div>

{#if showPreviewExistingFormModal}
  <!-- We are using EditFormModal as a template don't be fooled by the name -->
  <EditFormModal
    title="Form View"
    on:close={() => {
      formStore.resetQuestions();
      showPreviewExistingFormModal = false;
    }}
  >
    <div style="display: flex; justify-content: center">
      <div style="width: 650px;">
        <div style="padding-top: 12px;">
          <!-- We are always reseting the forms and until we have them locally we are selecting the first element.-->
          <FormTitleRenderer
            title={$formStore.questions.title}
            description={$formStore.questions.description}
          />
          {#each $formStore.questions.formFields as question}
            <div style="padding-top: 12px;">
              <FormElementRenderer {question} readOnly={true} />
            </div>
          {/each}
        </div>
      </div>
    </div>
  </EditFormModal>
{/if}

<style>
  .table {
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
  }

  .th {
    display: none;
  }

  .th > .td {
    justify-content: left;
    align-items: center;

    font-weight: 600;
    font-size: 14px;
    line-height: 16px;
    color: #606972;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .td.title {
    flex: 0.67 1 0;
    flex-grow: 2;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
  }

  .td.icon {
    display: flex;
    flex-grow: 0;
    flex-basis: 48px;
    max-width: 250px;
    color: #76808b;
    font-size: 24px;
    align-items: center;
    text-align: center;
    justify-content: center;
    margin-left: 15px;
    flex-direction: row-reverse;
  }

  .inner-content {
    position: sticky;
    top: 0;
    z-index: 98;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    right: 0%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 98;
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
    padding-right: 0.6875em;
    margin-bottom: 1rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .modal {
    position: absolute;
    left: 50%;
    top: 50%;
    width: 60%;
    min-width: fit-content;
    height: 80%;
    overflow: hidden;
    transform: translate(-50%, -50%);
    /* padding: 1em; */
    background: #ffffff;
    border-radius: 10px;
    z-index: 99;
    padding-top: 0;
    margin-top: 20px;
  }

  .modal-content {
    padding: 1rem;
    display: flex;
    flex-direction: column;
  }

  .modal-x {
    /* position: absolute; */

    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;
    cursor: pointer;
  }

  /* .padding , .td.name-hd{
      display: none;
  } */
  @media only screen and (max-width: 767px) {
    .modal {
      width: 80%;
    }
  }
</style>
