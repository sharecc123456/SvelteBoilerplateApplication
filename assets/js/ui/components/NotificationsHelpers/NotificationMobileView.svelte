<script>
  import { createEventDispatcher } from "svelte";
  import FAIcon from "../../atomic/FAIcon.svelte";
  import Panel from "../Panel.svelte";
  import Button from "../../atomic/Button.svelte";

  export let notification, getXdaysFrom, actionButtonTypes;

  const dispatch = createEventDispatcher();

  $: style = `
  padding: 0.5rem 1rem;
  margin-top: 0.5rem;
  width: auto;
  border-radius: 0.2;
  position: relative;
  background: ${notification.read ? "#fff" : "#f5d8cb !important"};
`;

  let panelProps = {
    title: true,
    collapsible: true,
    custom_title: true,
    custom_toolbar: true,
    has_z_index: false,
    allowHandlePanelClick: true,
    classes: "max-height-20",
  };
</script>

<Panel
  {style}
  {...panelProps}
  headerClasses="cursor-pointer"
  on:panel_click={() => {
    dispatch("notificationClick", notification);
  }}
>
  <div slot="custom-title">
    <div class="panel-title">
      <div class="panel-text">
        <span class="title-text">{notification.title || ""} </span>
        <span class="subtitle-text">{notification.message || ""} </span>
        <span class="subtitle-text"
          >{getXdaysFrom(notification["inserted_at"])}
        </span>
      </div>
    </div>
  </div>

  <div slot="custom-toolbar" class="custom-toolbar">
    <div
      class="remove"
      on:click|stopPropagation={() => {
        dispatch("removeNotification", notification);
      }}
    >
      <FAIcon icon="times-circle" iconStyle="regular" iconSize="large" />
    </div>
  </div>

  <div
    slot="sub-header"
    style="margin-top: 0.5rem"
    on:click={() => {
      dispatch("notificationActions", notification);
    }}
  >
    <Button {...actionButtonTypes[notification["type"]]} />
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
  .remove {
    color: #df1a1a;
  }
</style>
