<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import { formStore } from "../../../stores/formStore";
  import Switch from "../Switch.svelte";

  export let hideRemove = false;
  export let question;
  export let index;
</script>

<div class="container">
  <hr />
  <div class="commands">
    <div
      class="action"
      on:click={() => {
        formStore.addQuestion(index);
      }}
    >
      <FAIcon icon="plus" />
      <span class="title">Add Question</span>
    </div>
    <div
      class="action"
      on:click={() => {
        formStore.addInstruction(index);
      }}
    >
      <FAIcon icon="plus" />
      <span class="title">Add section Header/Instruction</span>
    </div>

    {#if !hideRemove}
      <div
        class="action"
        on:click={() => {
          formStore.handleRemove(index);
        }}
      >
        <FAIcon icon="trash" />
      </div>
      <div
        style="border-right: 1px solid #b3c1d0;
      height: 32px;"
      />

      {#if question.type !== "instruction"}
        <div
          style="display: flex;
      align-items: center;"
        >
          <span>
            <Switch text="Required" bind:checked={question.required} />
          </span>
        </div>
      {/if}

      <!-- Order stuff -->
      <div class="action" on:click={() => formStore.moveUp(index)}>
        <FAIcon icon="up" iconStyle="regular" />
      </div>
      <div class="action" on:click={() => formStore.moveDown(index)}>
        <FAIcon icon="down" iconStyle="regular" />
      </div>
    {/if}
  </div>
</div>

<style>
  .container {
    margin-top: 30px;
  }

  .commands {
    display: flex;
    gap: 16px;
    flex-direction: row-reverse;
    font-size: 19px;
    align-items: center;
  }

  .action {
    display: flex;
    align-items: center;
    cursor: pointer;
  }

  .title {
    font-size: 14px;
    margin-left: 5px;
  }

  @media only screen and (max-width: 767px) {
    .commands {
      gap: 0.5rem;
      font-size: 1rem;
      flex-wrap: wrap;
    }

    .title {
      font-size: 1rem;
      margin-left: 2px;
    }
  }
</style>
