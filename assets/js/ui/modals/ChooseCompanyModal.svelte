<script>
  import { createEventDispatcher, onDestroy } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Button from "../atomic/Button.svelte";
  import TextField from "../components/TextField.svelte";
  import { getCompanies } from "BoilerplateAPI/Recipient";

  const dispatch = createEventDispatcher();
  const close = () => dispatch("close");

  let modal;

  export let selectOne = true;
  export let showSelectionCount = true;
  export let customButtonText = true;
  export let buttonText = "Switch";
  export let title = "Choose Sub-Organization";
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

  let templates = getCompanies().then((data) => {
    let creqi = data.current_requestor_company_id;

    if (creqi != null && creqi != 0) {
      handleSelectRow({ id: creqi }, "add");
    }

    return data.requestor_companies.map((x) => {
      return {
        id: x.id,
        name: x.name,
        description: "",
        inserted_at: "",
        updated_at: "",
      };
    });
  });

  let search_value;
  let selection_list = [];
  let selectedTemplates = [];
  export let default_selection_list = selection_list;
  let selection_count = 0;

  async function submitSelection() {
    if (selection_count == 0) {
      // Must choose at least one suborgs
      alert("Must choose a sub-organization to proceed.");
      return;
    } else {
      await fetch("/n/api/v1/user/restrict", {
        method: "POST",
        credentials: "include",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          companyId: selectedTemplates[0].id,
        }),
      });
      selection_count = 0;
      selection_list = [];
      selectedTemplates = [];
      close();
    }
  }

  function handleSelectRow(tmpl, event) {
    const { id } = tmpl;
    if (event == "remove") {
      selection_list = selection_list.filter((x) => {
        return x != id;
      });
      selectedTemplates = selectedTemplates.filter((x) => {
        return x.id != id;
      });
      selection_count -= 1;
    } else {
      selection_list = [...selection_list, id];
      selectedTemplates = [...selectedTemplates, tmpl];
      selection_count += 1;
    }
  }
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click|self={close}>
  <div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
    <div class="modal-content">
      <div class="inner-content">
        <span class="modal-header">
          {title}

          <span on:click={close}>
            <slot name="closer" />
          </span>
          <div on:click={close} class="modal-x">
            <i class="fas fa-times" />
          </div>
        </span>
        <div class="inner-preamble">
          <div>
            <TextField
              bind:value={search_value}
              icon="search"
              text="Search Sub-Organizations"
            />
          </div>
          <div on:click={() => selection_count !== 0 && submitSelection()}>
            {#if customButtonText}
              <Button
                color="secondary"
                showTooltip={selection_count === 0}
                tooltipExtraPad={true}
                tooltipMessage={"You must choose one before proceeding"}
                disabled={selection_count === 0}
                text={buttonText}
                icon={"repeat"}
              />
            {:else}
              <Button
                color="secondary"
                disabled={selection_count === 0}
                text={"Add Selection" +
                  (showSelectionCount && selection_count > 0
                    ? ` (${selection_count})`
                    : "")}
              />
            {/if}
          </div>
        </div>
        <div class="table">
          <div class="tr th">
            <div class="td toggle" />
            <div class="td name">Sub-Organization</div>
            <div class="td date" />
            <div class="td date desktop" />
            <div class="td date desktop" />
            <div class="td toggle" />
          </div>
        </div>
      </div>

      <div class="content">
        <div class="table">
          {#await templates}
            <p>Loading sub-organizations...</p>
          {:then tmpls}
            {#each tmpls as tmpl}
              {#if !default_selection_list.includes(tmpl.id) && tmpl.name
                  .toLowerCase()
                  .includes(search_value.toLowerCase())}
                <div
                  class="tr cursor-pointer"
                  on:click={() => {
                    if (selection_list.includes(tmpl.id)) {
                      handleSelectRow(tmpl, "remove");
                    } else {
                      if (selectOne && selection_count == 1) {
                        handleSelectRow(selectedTemplates[0], "remove");
                        handleSelectRow(tmpl, "add");
                        return;
                      } else {
                        handleSelectRow(tmpl, "add");
                      }
                    }
                  }}
                >
                  <div class="td toggle">
                    {#if selectOne}
                      {#if selection_list.includes(tmpl.id)}
                        <span>
                          <FAIcon icon="circle-check" />
                        </span>
                      {:else}
                        <span>
                          <FAIcon icon="circle" iconStyle="regular" />
                        </span>
                      {/if}
                    {:else if selection_list.includes(tmpl.id)}
                      <span>
                        <FAIcon icon="check-square" />
                      </span>
                    {:else}
                      <span>
                        <FAIcon icon="square" iconStyle="regular" />
                      </span>
                    {/if}
                  </div>
                  <div class="td name">
                    <p>{tmpl.name}</p>
                    <p>{tmpl.description ?? ""}</p>
                  </div>
                  <div class="td date" />
                  <div class="td date desktop">{tmpl.inserted_at}</div>
                  <div class="td date desktop">{tmpl.updated_at}</div>
                  <div class="td toggle" />
                </div>
              {/if}
            {/each}
          {:catch error}
            <p>Failed to load suborganizations...</p>
          {/await}
        </div>
      </div>

      <span on:click={close}>
        <slot name="closer" />
      </span>
    </div>
  </div>
</div>

<style>
  .content {
    overflow-x: hidden;
  }
  .inner-preamble {
    display: flex;
    align-items: center;
    padding-top: 1rem;
  }

  .inner-preamble > div:first-child {
    flex: 1;
    margin-right: 1rem;
  }

  .table {
    padding-top: 1rem;
    display: flex;
    flex-flow: column nowrap;
    flex: 1 1 auto;
    width: 100%;
    position: relative;
  }

  .th {
    display: none;
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
  }

  .td.name > p {
    padding: 0;
    margin: 0;
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
    padding-right: 0.6875em;
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 1rem;
  }

  .modal {
    font-family: "Nunito", sans-serif;
    position: absolute;
    left: 50%;
    top: 50%;
    width: 60%;
    min-width: fit-content;
    height: 80%;
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 9999;
    padding-top: 0;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-direction: column;
  }

  .modal-x {
    font-size: 24px;
    left: calc(100% - 4em);
    top: 0.85em;

    cursor: pointer;
  }
  .cursor-pointer {
    cursor: pointer;
  }

  @media only screen and (max-width: 767px) {
    .desktop {
      display: none !important;
    }
    .modal {
      width: 100%;
    }
    .modal-header {
      font-size: 1.2rem;
    }
    .inner-preamble {
      flex-direction: column;
      align-items: center;
    }
    .inner-preamble > div:first-child {
      margin-right: 0;
      margin-bottom: 1rem;
    }
    .inner-content {
      padding-bottom: 0rem;
    }
  }
</style>
