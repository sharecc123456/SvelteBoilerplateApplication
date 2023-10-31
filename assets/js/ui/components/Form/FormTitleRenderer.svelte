<script>
  /*
    Needed to create an other component because on recipient side title and description is not in the questions(formFields) array.
    In the formElementRenderer we are checking the title but it is only for the requestor side because title and description is in the same array with questions.

    MJ.
    */

  import Card from "../Card.svelte";

  export let title;
  export let description;
</script>

<Card isHeader={true}>
  <div class="title">
    {title}
  </div>
  <div class="description">
    {description}
  </div>
</Card>

<style>
  .title {
    font-size: 32px;
    font-weight: 400;
    color: #202124;
    line-height: 135%;
    word-break: break-word;
  }

  .description {
    white-space: pre-wrap;
    font-family: Roboto, Arial, sans-serif;
    font-size: 14px;
    font-weight: 400;
    letter-spacing: 0.2px;
    line-height: 20px;
    color: #202124;
    margin-top: 12px;
  }
</style>
