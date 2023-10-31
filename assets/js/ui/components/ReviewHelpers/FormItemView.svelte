<script>
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";

  export let data;
  export let checklistId;
  let status = 1;

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
    headerLeftClasses: "flex-2",
    classes: "max-height-20",
  };
  $: status = data.status || 1;
</script>

<Panel {style} {...panelProps} headerClasses="cursor-pointer">
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
        <FAIcon iconStyle="regular" icon="rectangle-list" iconSize="2x" />
      </div>
      <div class="panel-text">
        <span class="title-text">{data.title}</span>
        <span class="subtitle-text flex-column">
          <span>{data.description}</span>
          <span>Submitted: &nbsp; {data.submitted} </span>
        </span>
      </div>
    </div>
  </div>

  <div slot="sub-header" style="margin-top: 0.5rem;">
    <a href={`#review/${checklistId}/form/${data.id}`}>
      <Button color="primary" text="Review" />
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
</style>
