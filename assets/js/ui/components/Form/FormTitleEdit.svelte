<script>
  /*
    This component is always at the first element of the form. Can't delete.
    User must add a title
*/
  import TextField from "../TextField.svelte";

  export let formElement;
  export let repeatEntriesBlocked = false;
</script>

<div class="content">
  <div>
    <!-- svelte-ignore a11y-label-has-associated-control -->
    <label>Form title <span class="required">*</span></label>
    <TextField text="Form Title" bind:value={formElement.title} />
  </div>

  <div style="margin-top: 15px;">
    <!-- svelte-ignore a11y-label-has-associated-control -->
    <label>Form description</label>
    <TextField text="Form description" bind:value={formElement.description} />
  </div>
  <div class="field">
    <input
      type="checkbox"
      id="repeat-entries"
      disabled={repeatEntriesBlocked}
      bind:checked={formElement.has_repeat_entries}
    />
    <label class="cursor-pointer" for="repeat-entries">
      Set form for repeat entries of standard questions, i.e. list the name and
      age of every driver
    </label>
  </div>
  {#if formElement.has_repeat_entries}
    <div class="field">
      <div class="name">
        <input
          type="checkbox"
          id="repeat-vertical"
          disabled={repeatEntriesBlocked}
          bind:checked={formElement.has_repeat_vertical}
        />
        <label class="cursor-pointer" for="repeat-vertical">
          Vertical Entry
        </label>
      </div>
    </div>
    <div style="margin-top: 15px;">
      <label for="">Repeat Label</label>
      <TextField
        text="Form description"
        disabled={repeatEntriesBlocked}
        bind:value={formElement.repeat_label}
      />
    </div>
  {/if}
</div>

<style>
  .content {
    display: flex;
    flex-direction: column;
  }
  .required {
    color: rgb(221, 38, 38);
  }

  .field {
    margin-top: 15px;
  }

  .cursor-pointer {
    cursor: pointer;
  }
</style>
