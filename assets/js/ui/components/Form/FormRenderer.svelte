<script>
  import FormElementRenderer from "./FormElementRenderer.svelte";
  import FormEntriesRenderer from "./FormEntriesRenderer.svelte";

  import FormTitleRenderer from "./FormTitleRenderer.svelte";
  import Instruction from "./Instruction.svelte";

  export let form = {
    title: "",
    description: "",
    formFields: [],
  };

  export let isPreview = false;
  export let isRequestorReview = false;
  export let isPrefill = false;
</script>

<FormTitleRenderer title={form.title} description={form.description} />

{#if form.has_repeat_entries && !isPreview}
  <FormEntriesRenderer formData={form} />
{:else}
  {#each form.formFields as question}
    {#if question.type === "instruction"}
      <Instruction instruction={question} mode="view" />
    {:else}
      <div class="cardSpacing">
        <FormElementRenderer
          {isPrefill}
          {question}
          readOnly={!isPrefill || isPreview}
          {isRequestorReview}
        />
      </div>
    {/if}
  {/each}
{/if}

<style>
  .cardSpacing {
    padding-top: 12px;
  }
</style>
