<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Button from "../atomic/Button.svelte";
  import Tag from "../atomic/Tag.svelte";
  import TextField from "../components/TextField.svelte";
  import { getChecklists } from "BoilerplateAPI/Checklist";
  import ModalContainer from "./ModalContainer.svelte";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;
  export let disableRSDsChecklists = false; // disable checklists containing RSD templates
  export let hideRSDsChecklists = false; // hide the above
  export let buttonText = "Select & Next"; // text to dispaly on the blue button
  export let instructions = "";
  const handle_keydown = (e) => {
    if (e.key === "Escape") {
      close();
      return;
    }

    if (e.key === "Tab") {
      // trap focus
      const nodes = modal.querySelectorAll("*");
      const tabbable = Array.from(nodes).filter((n) => n.tabIndex >= 0);

      let index = tabbable.indexOf(document.activeElement);
      if (index === -1 && e.shiftKey) index = 0;

      index += tabbable.length + (e.shiftKey ? -1 : 1);
      index %= tabbable.length;

      tabbable[index].focus();
      e.preventDefault();
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  let checklists = getChecklists();

  let search_value;
  let selection_list = [];
  let currently_selected = undefined;
  export let default_selection_list = selection_list;

  function submitSelection() {
    dispatch("selectionMade", {
      checklistId: currently_selected,
    });
  }

  function cannotAddMore(checklists) {
    let firstArr = checklists.map((x) => x.id);
    let secondArr = default_selection_list;
    firstArr.sort();
    secondArr.sort();

    return (
      firstArr.length === secondArr.length &&
      firstArr.every((value, index) => value === secondArr[index])
    );
  }

  function handleSelection(id) {
    if (currently_selected == id) {
      currently_selected = null;
    } else {
      currently_selected = id;
    }
  }
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <ModalContainer {modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          <span>
            Select Checklist <span class="sm-hide">to Assign</span>
          </span>
          <span on:click={close}>
            <slot name="closer" />
          </span>
          <slot name="buttons" />
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>

        {#if instructions != ""}
          <span style="font-size: 14px; color: #7e858e;">
            {instructions}
          </span>
        {/if}

        <div
          style={instructions != "" && "margin-top: 1rem"}
          class="inner-preamble"
        >
          <span style="grid-area: a;">
            <TextField
              bind:value={search_value}
              icon="search"
              text="Search Checklists"
            />
          </span>
        </div>
      </div>

      <div class="content">
        <div class="table">
          <div class="tr th">
            <div class="td toggle" />
            <div class="td name name-hd">Checklist Name</div>
            <!-- <div class="td name name-hd description">Description</div> -->
            <div class="td date">Date Created</div>
            <div class="td date">Last Modified</div>
            <!-- <div class="td toggle" /> -->
          </div>
          {#await checklists}
            <p>Loading checklists...</p>
          {:then cls}
            {#each cls as cl}
              {#if cl.name.toLowerCase().includes(search_value.toLowerCase())}
                {#if hideRSDsChecklists && cl.has_rspec}
                  <!-- nothing -->
                {:else if disableRSDsChecklists && cl.has_rspec}
                  <div
                    class="tr disabledChecklist"
                    title="Cannot bulk send checklists that contain personalized documents."
                  >
                    <div class="td toggle">
                      {#if currently_selected == cl.id}
                        <span>
                          <FAIcon icon="dot-circle" />
                        </span>
                      {:else}
                        <span>
                          <FAIcon icon="circle" iconStyle="regular" />
                        </span>
                      {/if}
                    </div>
                    <div class="td name">
                      <p>{cl.name}</p>
                      <p class="name__desc">{cl.description}</p>
                      {#if cl?.tags.length > 0}
                        <div class="name__desc truncate">
                          <ul class="reset-style">
                            {#each cl.tags as tag}
                              <Tag
                                tag={{ ...tag, selected: true }}
                                listTags={true}
                              />
                            {/each}
                          </ul>
                        </div>
                      {/if}
                    </div>
                    <div class="td date">{cl.inserted_at}</div>
                    <div class="td date">{cl.updated_at}</div>
                    <!-- <div class="td toggle" /> -->
                  </div>
                {:else}
                  <div
                    class="tr cursor-pointer"
                    on:click={() => handleSelection(cl.id)}
                  >
                    <div class="td toggle">
                      {#if currently_selected == cl.id}
                        <span>
                          <FAIcon icon="dot-circle" />
                        </span>
                      {:else}
                        <span>
                          <FAIcon icon="circle" iconStyle="regular" />
                        </span>
                      {/if}
                    </div>
                    <div class="td name">
                      <p>{cl.name}</p>
                      <p class="name__desc">{cl.description}</p>
                      {#if cl?.tags.length > 0}
                        <div class="name__desc truncate">
                          <ul class="reset-style">
                            {#each cl.tags as tag}
                              <Tag
                                tag={{ ...tag, selected: true }}
                                listTags={true}
                              />
                            {/each}
                          </ul>
                        </div>
                      {/if}
                    </div>
                    <div class="td date">{cl.inserted_at}</div>
                    <div class="td date">{cl.updated_at}</div>
                    <!-- <div class="td toggle" /> -->
                  </div>
                {/if}
              {/if}
            {/each}
            {#if cls.length == 0}
              <div class="tr-full">
                <p>There are no available checklists. Start by creating one.</p>
              </div>
            {/if}
          {:catch error}
            <p>Failed to load checklists...</p>
          {/await}
        </div>
      </div>
    </div>

    <div class="footer">
      <span class="assign-selected" on:click={close}>
        <Button color="white medium" text="Cancel" />
      </span>
      <span
        class="assign-selected"
        on:click={currently_selected != undefined && submitSelection()}
      >
        <Button
          color="secondary medium"
          text={buttonText}
          disabled={currently_selected == undefined}
        />
      </span>
    </div>
  </ModalContainer>
</div>

<style>
  .reset-style {
    padding-left: 0px;
    margin: 0px;
  }
  .disabledChecklist {
    background: #b3c1d0 !important;
    border-color: #b3c1d0 !important;
    cursor: not-allowed !important;
  }

  .inner-preamble {
    display: grid;
    box-sizing: border-box;
    grid-template-rows: 1fr;
    grid-template-columns: minmax(0, 1fr);
    grid-template-areas: "a";
    justify-items: stretch;
    justify-content: center;
    column-gap: 0.5rem;
  }

  .table {
    /* padding-top: 2rem; */
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    width: 100%;
  }

  .th {
    display: none;
    position: sticky;
    top: 114px;
    background: #ffffff;
    padding-top: 0.5rem;
  }

  .th > .td {
    justify-content: left;
    align-items: left;

    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 16px;
    letter-spacing: 0.01em;
    text-transform: capitalize;
    color: #7e858e;

    margin-bottom: 0.5rem;
  }

  .tr {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .tr:not(.th) {
    background: #ffffff;
    border: 0.5px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 10px;
    padding: 1rem;
    margin-bottom: 1rem;
  }

  .td {
    display: flex;
    flex-flow: row nowrap;
    flex: 1 0 0;
    min-width: 0px;
  }

  .tr-full {
    display: flex;
    flex-flow: column nowrap;

    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 16px;
    letter-spacing: 0.01em;
    color: #7e858e;

    justify-content: center;
    align-items: center;
  }

  .td.toggle {
    flex-grow: 0;
    flex-basis: 40px;
    width: 40px;
    user-select: none;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
    cursor: pointer;
  }

  .td.name {
    flex-grow: 2;
    display: flex;
    flex-flow: column nowrap;
    /* display: grid;
    grid-template-columns: 1fr 1fr;
    align-items:center; */
  }
  .td.date {
    display: none;
  }
  .td.name-hd {
    display: flex;
  }
  .td.name > p {
    padding: 0;
    margin: 0;
    width: 250px;
  }

  .td.name > p:nth-child(1) {
    font-size: 14px;
    line-height: 24px;
    color: #171f46;
  }

  .td.name > p:nth-child(2) {
    font-size: 12px;
    line-height: 24px;
    color: #7e858e;
  }

  .td.date {
    justify-content: center;
  }

  :not(.th) > .td.date {
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #2a2f34;
  }

  .inner-content {
    position: sticky;
    top: 0;
    z-index: 10;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
    /* padding-right: 0.6875em; */
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-direction: column;
  }

  .modal-x {
    /* position: absolute; */

    font-size: 24px;
    left: calc(100% - 4em);
    top: 0.85em;

    cursor: pointer;
  }
  .name__desc {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .cursor-pointer {
    cursor: pointer;
  }
  .footer {
    position: sticky;
    bottom: -18px;
    z-index: 98;
    background: #ffffff;
    padding-top: 1rem;
    padding-bottom: 2rem;
    height: 20px;
    display: flex;
    justify-content: space-between;
  }

  @media only screen and (min-width: 640px) {
    .tr {
      padding-left: 1rem;
      padding-right: 1rem;
    }
  }
  @media only screen and (min-width: 780px) {
    .td.date {
      justify-content: center;
      display: flex;
    }
    .inner-preamble {
      display: grid;
      grid-template-rows: 1fr;
      grid-template-columns: 1fr;
      grid-template-areas: "a";
      justify-items: stretch;
      column-gap: 1rem;
    }
    .inner-preamble > span {
      max-width: 100%;
    }
    .td.name {
      width: 200px;
    }

    .td.name {
      grid-template-columns: 1fr;
    }
  }

  @media only screen and (max-width: 767px) {
    .modal-x {
      align-self: flex-start;
      margin-top: -16px;
    }
    .modal-header {
      font-size: 1.2rem;
      padding-top: 0;
    }

    .assign-selected {
      position: absolute;
      right: 15px;
      left: 15px;
      bottom: 0px;
      width: unset;
    }
    .footer {
      display: block;
    }
    .inner-content {
      padding-bottom: 0rem;
    }
  }
</style>
