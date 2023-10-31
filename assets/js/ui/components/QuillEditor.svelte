<script>
  import { onMount } from "svelte";

  const MAX_LENGTH = 500;


  export let quill;
  export let defaultValue;

  let qEditor;
  let textLength = 0;
  export let toolbarOptions = [
    [{ header: 2 }, "blockquote", "link"],
    ["bold", "italic", "underline", "strike"],
    [{ list: "ordered" }, { list: "bullet" }],
    [{ align: [] }],
  ];

  onMount(async () => {
    const { default: Quill } = await import("quill");
    quill = new Quill(qEditor, {
      modules: {
        toolbar: toolbarOptions,
      },
      theme: "snow",
      placeholder: "Add instructions, details, or links.",
      bounds: document.querySelector(".editor-wrapper"),
      scrollingContainer: document.querySelector(".editor-wrapper")
    });

    quill.on("text-change", function (delta, old, source) {
      textLength = quill.getLength()
      if (textLength > MAX_LENGTH) {
        quill.deleteText(MAX_LENGTH - 1, quill.getLength());
      }
    });
  });
</script>

<svelte:head>
  <link href="//cdn.quilljs.com/1.3.6/quill.snow.css" rel="stylesheet" />
</svelte:head>

<div class="editor-wrapper">
  Count: {textLength}/{MAX_LENGTH}
  <div bind:this={qEditor}>
    {#if defaultValue}
      {@html defaultValue}
    {/if}
  </div>
</div>

<style>
  .editor-wrapper {
    max-height: 60vh;
    overflow-y: auto;
  }
</style>
