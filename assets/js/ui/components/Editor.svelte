<script>
  import { onMount, onDestroy } from "svelte";
  import { Editor } from "@tiptap/core";
  import StarterKit from "@tiptap/starter-kit";
  import FAIcon from "Atomic/FAIcon.svelte";
  import CharacterCount from "@tiptap/extension-character-count";

  const MAX_LENGTH = 500;

  export let setEditorText;
  export let defaultValue;

  let editor;
  let element;

  onMount(async () => {
    editor = new Editor({
      element: element,
      extensions: [
        StarterKit,
        CharacterCount.configure({
          limit: MAX_LENGTH,
        }),
      ],
      content: defaultValue || "Start Typing ...",
      onTransaction: () => {
        // force re-render so `editor.isActive` works as expected
        editor = editor;
      },
      autofocus: true,
      onUpdate: ({ editor: _e }) => {
        const content = _e.getHTML();
        setEditorText(content);
      },
    });
  });

  onDestroy(() => {
    if (editor) {
      editor.destroy();
    }
  });
</script>

{#if editor}
  <div
    style="margin-bottom: 1rem;"
    class:error={editor.storage.characterCount.characters() === MAX_LENGTH}
  >
    {editor.storage.characterCount.characters()}/{MAX_LENGTH} characters
  </div>
  <span
    on:click={() => editor.chain().focus().toggleBold().run()}
    class:active={editor.isActive("bold")}
  >
    <FAIcon icon="bold" />
  </span>
  <span
    on:click={() => editor.chain().focus().toggleItalic().run()}
    class:active={editor.isActive("italic")}
  >
    <FAIcon icon="italic" />
  </span>
  <span
    on:click={() => editor.chain().focus().toggleStrike().run()}
    class:active={editor.isActive("strike")}
  >
    <FAIcon icon="strikethrough" />
  </span>
  <span
    on:click={() => editor.chain().focus().setParagraph().run()}
    class:active={editor.isActive("paragraph")}
  >
    <FAIcon icon="paragraph" />
  </span>
  <span
    on:click={() => editor.chain().focus().toggleOrderedList().run()}
    class:active={editor.isActive("orderedList")}
  >
    <FAIcon icon="list-ol" />
  </span>
  <span
    on:click={() => editor.chain().focus().toggleBulletList().run()}
    class:active={editor.isActive("bulletList")}
  >
    <FAIcon icon="list-ul" />
  </span>
  <span on:click={() => editor.chain().focus().undo().run()}>
    <FAIcon icon="undo" />
  </span>
  <span on:click={() => editor.chain().focus().redo().run()}>
    <FAIcon icon="redo" />
  </span>
{/if}

<div bind:this={element} class="editor" />

<style>
  span {
    border: 1px solid gray;
    border-radius: 3px;
    padding: 2px 5px;
    cursor: pointer;
    margin-right: 7px;
  }

  span.active {
    background: black;
    color: white;
  }

  :global(.ProseMirror) {
    border: 1px solid gray;
    border-radius: 3px;
    margin-top: 1rem;
    padding-inline: 0.5rem;
  }

  .error {
    color: red;
  }
</style>
