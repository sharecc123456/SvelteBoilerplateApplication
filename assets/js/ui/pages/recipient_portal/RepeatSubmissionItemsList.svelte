<script>
  import Button from "../../atomic/Button.svelte";
  import { createEventDispatcher } from 'svelte';

  const dispatch = createEventDispatcher();

  function dispatchCreateChecklist(event) {
      console.log(event)
        dispatch('clickedCreateChecklist', {
            clickedContent: content
        });
    }
  export let content;
</script>

<li class="header-checklist__items items-position">
  <div class="header-checklist__container">
    <div class="header-checklist__content">
      <h4 class="title">{content.name}</h4>
      <!-- <p class="header-checklist__description">{content.subject}</p> -->
    </div>
    <div style="margin: auto;" 
        on:click={dispatchCreateChecklist}>
      <Button text="Select" color="primary" centerButton={true}/>
    </div>
  </div>
</li>

<style>
  .header-checklist__items {
    padding: 0 13px 0 16px;
  }

  .header-checklist__items:hover {
    background-color: #ededed;
  }

  .header-checklist__items:first-child {
    padding-top: unset;
  }

  .header-checklist__container {
    display: flex;
    flex-direction: row;
    align-items: flex-start;
    padding: 10px 0 8px 8px;
    height: inherit;
    cursor: pointer;
  }

  .header-checklist__content {
    margin-right: 6px;
    padding-top: 4px;
    width: 250px;
  }

  .header-checklist__items:not(:last-child) .header-checklist__container {
    border-bottom: 1px solid #dae2ee;
  }

  .header-checklist__items:first-child .header-checklist__container {
    padding-top: 8px;
  }
</style>