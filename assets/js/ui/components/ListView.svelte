<script>
  import { createEventDispatcher } from "svelte";
  import { convertUTCToLocalDateString } from "../../helpers/dateUtils";
  import FAIcon from "../atomic/FAIcon.svelte";
  import Tag from "./DashboardHelpers/Tag.svelte";

  const dispatch = createEventDispatcher();
  export let data = [];
  export let metadata = {};
  export let header = "Version History";
  export let hideX = false;
  export let showViewLink = true;

  let modal;

  const close = () => dispatch("close");
  const getSubmissionViewLink = (assignmentId, custId) => {
    return `#submission/view/6/${assignmentId}/${custId}?newTab=true&filePreview=true`;
  };
</script>

<svelte:window />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    <div class="modal-header">{header}</div>
    <div class="modal-subheader">{metadata.name}</div>
    <div class="modal__content__body">
      <ul>
        {#each data as item, index}
          <li>
            <span>
              Version: {item.version} - {convertUTCToLocalDateString(
                item.inserted_at
              )}
            </span>
            {#if showViewLink}
              <span
                class="external-link"
                on:click={() => {
                  const hash = getSubmissionViewLink(
                    metadata.assignmentId,
                    item.customization_id
                  );
                  window.open(hash, "_blank");
                }}><FAIcon icon="external-link" /></span
              >
            {/if}
            {#if index === 0 || index === data.length - 1}
              <Tag
                content={`${index === 0 ? "Send To Contact" : "Original"}`}
                classes="tag-text"
              />
            {/if}
          </li>
        {/each}
      </ul>
    </div>
    <div on:click={close} class="modal-x" class:hideX>
      <i class="fas fa-times" />
    </div>
  </div>
</div>

<style>
  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
    z-index: 11;
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
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    width: calc(100vw - 4em);
    max-width: 32em;
    max-height: calc(100vh - 4em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
    z-index: 12;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
  }

  .modal-x {
    position: absolute;
    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;

    cursor: pointer;
  }

  .modal-subheader {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 24px;
    letter-spacing: 0.15px;
  }

  .external-link {
    cursor: pointer;
    display: inline-block;
  }

  @media only screen and (max-width: 640px) {
    .modal-subheader {
      font-size: 14px;
      line-height: 20px;
      letter-spacing: 0.15px;
    }

    .modal {
      top: 40%;
      width: calc(100vw - 5em);
    }
    .modal-content {
      margin: 0;
      padding: 0;
    }
    .modal-header {
      font-size: 18px;
    }
    .modal-x {
      font-size: 18px;
    }
  }
</style>
