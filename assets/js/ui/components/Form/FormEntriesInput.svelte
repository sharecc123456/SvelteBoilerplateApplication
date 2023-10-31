<script>
  import { formEntryString } from "BoilerplateAPI/Form";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import ConfirmationDialog from "Components/ConfirmationDialog.svelte";

  import Card from "../Card.svelte";
  import FormElementRenderer from "./FormElementRenderer.svelte";

  export let formData = {};
  export let entries = [];
  export let expandedEntries = {};

  const collapsedAll = () => {
    for (const key in expandedEntries) {
      if (expandedEntries.hasOwnProperty(key)) {
        expandedEntries[key] = false;
      }
    }
  };

  let deleteIndex = -1;
  let showRemoveWarning = false;

  const handleShowRemoveWarning = (index) => {
    deleteIndex = index;
    showRemoveWarning = true;
  };

  const handleRemoveEntry = (index) => {
    entries = [
      ...entries.slice(0, index),
      ...entries.slice(index + 1, entries.length),
    ];
    deleteIndex = -1;
    showRemoveWarning = false;
  };
</script>

{#each entries as entry, index}
  <div class="entry-wrapper">
    <div class="cardSpacing">
      <Card isHeader={true}>
        <div class="collapsed-entry">
          <div
            class="answer header"
            on:click={() => (expandedEntries[index] = !expandedEntries[index])}
          >
            {#if expandedEntries[index]}
              <FAIcon color={true} icon="circle-minus" iconSize="large" />
            {:else}
              <FAIcon color={true} icon="circle-plus" iconSize="large" />
            {/if}

            Entry {index + 1}{expandedEntries[index]
              ? ""
              : ": " + formEntryString(entry)}
          </div>
          <span
            style="margin-right: 16px"
            on:click={() => (expandedEntries[index] = false)}
          />
          <span class="pointer" on:click={() => handleShowRemoveWarning(index)}>
            <FAIcon color={true} icon="trash" iconSize="large" />
          </span>
        </div>
      </Card>
    </div>
    {#if expandedEntries[index]}
      {#each formData.formFields as field}
        <div class="cardSpacing">
          <FormElementRenderer
            question={field}
            bind:entryValue={entry[field.id]}
            entryInput={true}
          />
        </div>
      {/each}
    {/if}
  </div>
{/each}

<div class="entry-wrapper" on:click={collapsedAll}>
  <div class="cardSpacing">
    <Card isHeader={true}>
      <div class="collapsed-entry">
        <div class="answer header">New Entry</div>
      </div>
    </Card>
  </div>
  {#each formData.formFields as question}
    <div class="cardSpacing">
      <FormElementRenderer bind:question />
    </div>
  {/each}
</div>

{#if showRemoveWarning}
  <ConfirmationDialog
    question="Are you sure you want to remove?"
    requiresResponse={true}
    yesText="Yes"
    noText="No, Cancel"
    yesColor="primary"
    noColor="white"
    on:yes={() => {
      handleRemoveEntry(deleteIndex);
    }}
    on:close={() => {
      showRemoveWarning = false;
    }}
  />
{/if}

<style>
  .pointer {
    cursor: pointer;
  }

  .entry-wrapper {
    margin-top: 1rem;
    position: relative;
  }

  .cardSpacing {
    padding-top: 12px;
  }

  .answer {
    font-size: 20px;
    letter-spacing: 0.1px;
    color: #202124;
    font-weight: 400;
  }

  .answer.header {
    margin-right: auto;
    flex-grow: 1;
    cursor: pointer;
  }

  .collapsed-entry {
    display: flex;
    justify-content: flex-end;
    align-items: center;
  }
</style>
