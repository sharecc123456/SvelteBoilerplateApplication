<script>
  import Button from "../../atomic/Button.svelte";
  export let docreq = {};
  export let clickDocumentButton = () => {};
  export let assignment = {};
  export let stateToText = () => {};

  function getQueryStrings() {
    const name = `name=${encodeURIComponent(assignment.name)}`;
    const ref = assignment.recipient_reference
      ? `&ref=${encodeURIComponent(assignment.recipient_reference)}`
      : "";

    return `${name}${ref}`;
  }
</script>

{#if docreq.is_info}
  <div style="margin-left: 40px;">
    <a href={`#view/${assignment.id}/${docreq.id}`}>
      <Button
        text="View"
        color={docreq.state.status == 4 || docreq.state.status == 2
          ? "gray"
          : "primary"}
      />
    </a>
  </div>
{:else}
  <div on:click={() => clickDocumentButton(docreq)}>
    {#if docreq.state.status == 2 || docreq.state.status == 4}
      <div class="actionbtnGroup">
        <a href={`#submission/view/1/${assignment.id}/${docreq.completion_id}`}>
          <Button color="light" text={stateToText(docreq.state.status, true)} />
        </a>
        <span
          style="margin-left: 10px"
          on:click={() => {
            window.location = `/completeddocument/${assignment.id}/${docreq.completion_id}/download`;
          }}
        >
          <Button color="light" icon="download" text={"Download"} />
        </span>
      </div>
    {:else if docreq.is_iac && docreq.state.status == 0}
      <a
        href={`#iac/fill/${docreq.iac_document_id}/${
          assignment.id
        }?${getQueryStrings()}`}
      >
        <Button text={stateToText(docreq.state.status, true)} />
      </a>
    {:else if docreq.is_iac && docreq.state.status == 3}
      <a
        href={`#iac/fill/${docreq.iac_document_id}/${
          assignment.id
        }?${getQueryStrings()}&reason=${docreq.return_comments}`}
      >
        <Button text={stateToText(docreq.state.status, true)} />
      </a>
    {:else}
      <div>
        <Button text={stateToText(docreq.state.status, true)} />
      </div>
    {/if}
  </div>
{/if}

<style>
  a {
    text-decoration: none;
  }
  .actionbtnGroup {
    width: 100%;
    display: flex;
    justify-content: flex-end;
    align-items: center;
  }
  @media only screen and (max-width: 425px) {
    .actionbtnGroup {
      align-items: unset;
    }
  }

  @media only screen and (min-width: 481px) and (max-width: 1280px) {
    .actionbtnGroup {
      width: 100%;
      display: flex;
      justify-content: flex-end;
      align-items: center;
      flex-direction: column;
      gap: 8px;
      margin-left: 15px;
    }
  }
</style>
