<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import RecipientTaskDescription from "Components/Recipient/RecipientTaskDescription.svelte";

  export let data, showToast, checklistId, requestId, acceptIt, returnIt;
  export let handleTaskReturn = () => {};
  export let processTaskReview = () => {};

  let status = 1;
  const dispatch = createEventDispatcher();

  const statusIcon = [
    { icon: "bug", iconStyle: "regular", iconSize: "small", text: "Bugged 0" },
    { icon: "circle", iconStyle: "regular", iconSize: "small", text: "New" },
    {
      icon: "check-circle",
      iconStyle: "solid",
      iconSize: "small",
      text: "Accepted",
    },
    { icon: "undo", iconStyle: "solid", iconSize: "small", text: "Returned" },
    { icon: "bug", iconStyle: "regular", iconSize: "small", text: "Bugged 4" },
    {
      icon: "xmark",
      iconStyle: "solid",
      iconSize: "small",
      text: "Unavailable",
    },
    { icon: "bug", iconStyle: "regular", iconSize: "small", text: "Bugged 6" },
    { icon: "bug", iconStyle: "regular", iconSize: "small", text: "Bugged 7" },
  ];

  const style = `
  padding: 0.5rem 1rem;
  margin-top: 0.5rem;
  width: auto;
  border-radius: 0.2;
  position: relative;
`;

  let panelProps = {
    title: true,
    custom_title: true,
    has_z_index: false,
    allowHandleHeaderClick: true,
    headerLeftClasses: "flex-2",
    classes: "max-height-20",
  };
  $: status = data.status || 1;
</script>

<Panel
  {style}
  {...panelProps}
  on:header_click={() => {
    dispatch("showTaskDetails", { itemData: data });
  }}
  headerClasses="cursor-pointer"
>
  <div slot="top_title" class="top-title is-open">
    <span>
      <FAIcon {...statusIcon[status]} />
    </span>
    <span>
      {statusIcon[status]?.text || "Status"}
    </span>
  </div>
  <div slot="custom-title" style="margin-top: 1.5rem;">
    <div class="panel-title">
      <div class="status">
        {#if data.request_type == "file"}
          <FAIcon icon="paperclip" iconStyle="regular" iconSize="2x" />
        {:else if data.request_type == "data"}
          <FAIcon icon="font-case" iconStyle="regular" iconSize="2x" />
        {:else if data.request_type == "task"}
          <FAIcon icon="thumbtack" iconStyle="regular" iconSize="2x" />
        {/if}
      </div>
      <div class="panel-text">
        <span class="title-text">{data.full.name}</span>
        <span class="subtitle-text flex-column">
          {#if data.request_type == "task"}
            <span>
              <RecipientTaskDescription description={data.description} />
            </span>
          {/if}

          {#if data.request_type == "file"}
            {#if data.status == 5}
              <span>Unavailable: - {data.return_reason} </span>
            {/if}
          {:else if data.request_type == "data"}
            <span
              >Contact input: <span
                on:copy={() => {
                  showToast(`Copied to clipboard.`, 1000, "default", "MM");
                }}
                style="cursor: auto;">{data.filename}</span
              >
            </span>
          {/if}
          <span>Submitted: &nbsp; {data.submitted} </span>
        </span>
      </div>
    </div>
  </div>

  <div slot="sub-header" style="margin-top: 0.5rem;">
    {#if data.request_type == "data" || data.status == 5}
      <div class="button-group">
        <span
          on:click={() => {
            requestId = data.id;
            returnIt();
          }}
        >
          <Button color="danger" text="Reject" />
        </span>

        <span
          on:click={() => {
            requestId = data.id;
            acceptIt();
          }}
        >
          <Button color="secondary" text="Accept" />
        </span>
      </div>
    {/if}
    {#if data.request_type == "file" && data.status != 5}
      {#if data.status == 2}
        <a href={`/reviewrequest/${data.id}/download/review`}>
          <Button color="gray" text="View" />
        </a>
      {:else}
        <a href={`#review/${checklistId}/request/${data.request_id}`}>
          <Button color="primary" text="Review" />
        </a>
      {/if}
    {/if}
    {#if data.request_type == "task"}
      <div class="button-group">
        <span
          on:click={() => {
            requestId = data.id;
            handleTaskReturn(data);
          }}
          style="width: 100%;"
        >
          <Button color="danger" text="Reject" />
        </span>

        <span
          on:click={() => {
            requestId = data.id;
            processTaskReview(data);
          }}
          style="width: 100%;"
        >
          <Button color="secondary" text="Accept" />
        </span>
      </div>
    {/if}
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    width: 100%;
  }
  a {
    text-decoration: none;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
    width: 100%;
  }
  .title-text {
    color: black;
    font-size: 1rem;
    font-weight: 500;
    font-family: "Nunito", sans-serif;
  }
  .subtitle-text {
    color: #828282;
    font-size: 0.8rem;
    font-weight: 400;
    font-family: "Nunito", sans-serif;
  }
  .flex-column {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
  }
  .status {
    margin-right: 1rem;
    color: #7e858e;
  }

  .top-title {
    background-color: #828282;
    position: absolute;
    top: 0;
    width: 100%;
    left: 0;
    display: flex;
    justify-content: center;
    z-index: 1;
    padding: 0.2rem 0;
    gap: 0.5rem;
  }

  .is-open {
    background-color: #dfdfdf;
    color: #000;
    font-weight: 700;
  }
  .button-group {
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }
  .button-group span {
    width: 100%;
  }
</style>
