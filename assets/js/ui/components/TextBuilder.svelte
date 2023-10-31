<script>
  import Tag from "Atomic/Tag.svelte";
  import { onMount } from "svelte";

  // tags is an array of {display: whattodisplay, internal: whatistheapi}
  export let tags = [];

  // final value that will be exported
  export let value = "";

  // placeholder text for the textfield.
  export let placeholder = "";

  let segments = [];

  let inputElm;

  function addTag(tag) {
    let n = {
      type: "tag",
      tag: tag,
      id: Math.random() * 100000,
      internal: tag.internal,
      text: tag.display,
    };
    segments.push(n);
    segments = segments;

    value = "/" + segments.map((s) => s.internal).join("/");
  }

  function _addText(val, update) {
    let n = {
      type: "userinput",
      id: Math.random() * 100000,
      internal: val,
      text: val,
    };

    segments.push(n);
    segments = segments;
    if (update) value = "/" + segments.map((s) => s.internal).join("/");
  }

  function addText(e, update = true) {
    if (e.key == "Enter") {
      let val = inputElm.value;
      _addText(val, update);
      inputElm.value = "";
    }
  }

  function removeTag(e, update = true) {
    let tag = e.detail;
    segments = segments.filter((x) => x.id != tag.id);
    if (update) value = "/" + segments.map((s) => s.internal).join("/");
  }

  onMount(() => {
    // construct the segments based on value
    let _segments = value.split("/");
    _segments.forEach((s) => {
      if (s == "/" || s == "") return;

      let tag = tags.find((t) => s == t.internal);
      if (tag != null) {
        // this is a variable
        addTag(tag, false);
      } else {
        _addText(s, false);
      }
    });
  });
</script>

<div class="container">
  <div class="final-input">
    {#each segments as segment}
      <Tag
        backgroundColor="#dddddd"
        on:onRemoveTag={removeTag}
        allowDeleteTags={true}
        tag={{ id: segment.id, flags: 1, name: "/" }}
      />
      {#if segment.type == "userinput"}
        <Tag
          backgroundColor="#eeeeee"
          on:onRemoveTag={removeTag}
          allowDeleteTags={true}
          tag={{ id: segment.id, flags: 1, name: segment.text }}
        />
      {/if}
      {#if segment.type == "tag"}
        <Tag
          on:onRemoveTag={removeTag}
          allowDeleteTags={true}
          tag={{ id: segment.id, flags: 1, name: segment.text }}
        />
      {/if}
    {/each}
  </div>
  <div class="input">
    <input
      class="input"
      on:keydown={addText}
      bind:this={inputElm}
      {placeholder}
    />
  </div>
  <div class="tags">
    {#each tags as tag}
      <span on:click={addTag(tag)}>
        <Tag tag={{ id: 0, flags: 1, name: tag.display }} />
      </span>
    {/each}
  </div>
</div>

<style>
  input.input {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    background: #ffffff;

    width: 100%;
    min-width: 100%;
    max-width: 100%;
    text-align: left;
    /* Gray 300 */
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;

    padding-left: 1rem;
  }
</style>
