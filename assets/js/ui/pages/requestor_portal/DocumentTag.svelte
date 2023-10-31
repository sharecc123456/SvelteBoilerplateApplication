<script>
  import { onMount } from "svelte";
  import {
    getDocumentTag,
    createDocumentTag,
    getDocumentTagById,
  } from "../../../api/documentTag";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import Tag from "../../atomic/Tag.svelte";
  import AutoComplete from "simple-svelte-autocomplete";

  export let companyID = null;
  export let templateTagIds = [];
  export let tagsSelected = [];
  export let tagType = "document";
  let tags = [];

  const getTags = async (cId) => {
    return await getDocumentTag(cId, tagType);
  };

  const createTag = async (cId, tag) => {
    return await createDocumentTag(cId, tag, tagType);
  };

  const getTagById = async (tagId) => {
    console.log(`getTagById(tagId: ${tagId}, tagType: ${tagType})`);
    return await getDocumentTagById(tagId, tagType);
  };

  const handleRemoveTag = (tag) => {
    tagsSelected = tagsSelected.filter((x) => x.id !== tag.id);
  };

  onMount(async () => {
    tags = await getTags(companyID);

    if (templateTagIds.length > 0) {
      const totalSelectedTags = [...templateTagIds];
      tagsSelected = tags.filter((x) => totalSelectedTags.includes(x.id));
    }

    const crossElement = document.getElementsByClassName(
      "autocomplete-clear-button"
    );
    // showClear props in autocomplete is not working
    crossElement[0] && crossElement[0].remove();
  });

  const handleNewTag = async (tagName) => {
    const res = await createTag(companyID, { name: tagName, flags: 1 });
    if (res.ok) {
      const { id: tagId } = await res.json();
      const newTag = await getTagById(tagId);

      // Alert: Dropdown behaviour encountered onCreate handler autocomplete
      // first, the tag list is not updated when a async method is called to get all tags
      // tags = await getTags(companyId) -> dropdown not updated
      // the order of the new tag is really important
      // if you revert the tags addition as tags = [newTag, ...tags] only newly created tag is rendered in the dropdown
      // very weird behaviour, stuck in this hell for 2 hours
      tags = [...tags, newTag];
      return newTag;
    } else {
      showToast("Error! Try Again", 1000, "error", "MM");
    }
  };
</script>

<div>
  {#if tagsSelected.length > 0}
    <ul class="custom-tags">
      {#each tagsSelected as tag}
        <Tag
          {tag}
          allowDeleteTags={true}
          on:onRemoveTag={(evt) => handleRemoveTag(evt.detail)}
        />
      {/each}
    </ul>
  {/if}
  <div class="input-box">
    <AutoComplete
      multiple={true}
      matchAllKeywords={false}
      items={tags}
      labelFieldName="name"
      showClear={false}
      create={true}
      debug={false}
      hideArrow={false}
      createText={"Tag doesn't exist, create one?"}
      onCreate={handleNewTag}
      placeholder="Add or select tags"
      bind:selectedItem={tagsSelected}
    >
      <div slot="tag" let:item />
    </AutoComplete>
  </div>
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .custom-tags {
    list-style: none;
    margin: 0;
    overflow: hidden;
    padding: 10px 0 5px 0;
  }

  .input-box :global(.input) {
    color: black;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-size: 14px;
    line-height: 21px;
    outline: none;
  }

  .input-box :global(.input-container) {
    height: auto;
    border-radius: 4px;
    border: 1px solid #fff;
    padding-left: 0 !important;
    padding-right: 0 !important;
    display: flex;
    flex-wrap: wrap;
    align-items: stretch;
    background-color: #fff;
  }
  .input-box :global(.autocomplete-list) {
    padding-bottom: 2rem;
    max-height: 100px;
  }
</style>
