<script>
  import FAIcon from "../atomic/FAIcon.svelte";

  export let status = 1;

  let statuses = [
    { icon: "bug", iconStyle: "regular", text: "Bugged 0" },
    { icon: "circle", iconStyle: "regular", text: "New" },
    { icon: "check-circle", iconStyle: "solid", text: "Accepted" },
    { icon: "undo", iconStyle: "solid", text: "Returned" },
    { icon: "bug", iconStyle: "regular", text: "Bugged 4" },
    { icon: "xmark", iconStyle: "solid", text: "Unavailable" },
    { icon: "bug", iconStyle: "regular", text: "Bugged 6" },
    { icon: "bug", iconStyle: "regular", text: "Bugged 7" },
  ];
</script>

<div class="container">
  <div class="icon">
    <FAIcon
      icon={statuses[status].icon}
      iconStyle={statuses[status].iconStyle}
    />
  </div>
  <div class="text">{statuses[status].text}</div>
</div>

<style>
  .container > .icon {
    color: #2a2f34;
    font-size: 14px;
    padding-right: 1rem;
  }

  .container > .text {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 16px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #2a2f34;
  }

  .container {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
  }
</style>
