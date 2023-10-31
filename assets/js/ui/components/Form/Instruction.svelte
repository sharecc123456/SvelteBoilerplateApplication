<script>
  import TextField from "../TextField.svelte";
  import TextArea from "../TextArea.svelte";

  export let instruction;
  export let mode = "edit";
</script>

<div class="content">
  {#if mode === "edit"}
    <div class="questionBox">
      <div class="input">
        <span>Section header</span>
        <TextField text="Section header" bind:value={instruction.label} />
      </div>
    </div>
    <div class="answerContainer">
      <span class="answer">
        <span>Instructions</span>
        <TextArea
          text="Instructions here"
          bind:value={instruction.description}
        />
      </span>
    </div>
  {:else if mode === "view"}
    <h3 class="mb-1 pt-4 font-bold">{instruction.label}</h3>
    <p>{instruction.description}</p>
  {/if}
</div>

<style>
  .content {
    display: flex;
    flex-direction: column;
  }

  .pt-4 {
    padding-top: 16px;
  }
  .mb-1 {
    margin-bottom: 4px;
  }
  .font-bold {
    font-weight: 700;
  }
  h3,
  p {
    margin: 0;
  }

  .questionBox {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
  }

  .input {
    width: 350px;
  }

  .answerContainer {
    margin-top: 25px;
  }
</style>
