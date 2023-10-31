<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";
  import Tag from "../../atomic/Tag.svelte";

  export let data, submitted_date, submitted_time;

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
    headerLeftClasses: "flex-2",
    classes: "max-height-20",
  };
</script>

<Panel {style} {...panelProps} headerClasses="cursor-pointer">
  <div
    slot="top_title"
    class="top-title is-open"
    class:is-completed={data.fully_submitted}
  >
    <span>
      <FAIcon icon="exclamation-circle" iconStyle="regular" iconSize="small" />
    </span>
    <span>
      {data.fully_submitted ? "Full" : "Partial"} Submission
    </span>
  </div>
  <div slot="custom-title" style="margin-top: 1.5rem;">
    <div class="panel-title">
      <div class="panel-text">
        <span class="title-container">
          <span class="title-text">{data?.checklist?.name || ""} </span>
        </span>
        <span class="subtitle-text flex-column">
          <span>{data?.checklist?.description || ""} </span>
          <span>{data.recipient.name} ({data.recipient.company}) </span>
          <span>{data.recipient.email}</span>
          {#if data.requestor_description}
            <span>Reference: &nbsp; {data?.requestor_description || ""} </span>
          {/if}
          {#if data.recipient_description}
            <span
              >Recipient-Ref: &nbsp; {data?.recipient_description || ""}
            </span>
          {/if}
          <span>Submitted: &nbsp; {submitted_date} {submitted_time} </span>
        </span>
      </div>
    </div>
  </div>

  <div slot="sub-header" style="margin-top: 0.5rem">
    {#if data.tags}
      <ul class="reset-style">
        {#each data.tags as tag}
          <Tag
            isSmall={true}
            tag={{ ...tag, selected: true }}
            listTags={true}
          />
        {/each}
      </ul>
    {/if}
    <a href={`#review/${data.contents_id}`}>
      <Button text="Review" />
    </a>
  </div>
</Panel>

<style>
  .panel-title {
    display: flex;
    align-items: center;
    width: 100%;
  }
  .panel-text {
    display: flex;
    flex-direction: column;
    width: 100%;
  }
  a {
    text-decoration: none;
  }

  .reset-style {
    margin: 0;
    padding: 0;
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
    background-color: #f5d8cb;
    color: #000;
    font-weight: 700;
  }
  .is-completed {
    background-color: #d1fae5;
    color: #000;
    font-weight: 700;
  }
  .title-container {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
</style>
