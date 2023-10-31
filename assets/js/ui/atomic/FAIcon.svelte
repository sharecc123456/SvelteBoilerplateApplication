<script>
  export let icon = "bell";
  export let iconStyle = "solid";
  export let iconSize = "";
  export let rightPad;
  export let leftPad;
  export let floatLeft;
  export let hide = false;
  export let color = false;
  export let colordark = false;
  var fasStyle;
  var fasSize;
  switch (iconStyle) {
    case "solid":
      fasStyle = "fas";
      break;
    case "light":
      fasStyle = "fal";
      break;
    case "duotone":
      fasStyle = "fad";
      break;
    case "regular":
      fasStyle = "far";
      break;
    default:
      fasStyle = "fas";
      break;
  }

  switch (iconSize) {
    case "extrasmall":
      fasSize = "fa-xs";
      break;
    case "small":
      fasSize = "fa-sm";
      break;
    case "large":
      fasSize = "fa-lg";
      break;
    case "2x":
      fasSize = "fa-2x";
      break;
    case "3x":
      fasSize = "fa-3x";
      break;
    case "5x":
      fasSize = "fa-5x";
      break;
    case "7x":
      fasSize = "fa-7x";
      break;
    case "10x":
      fasSize = "fa-10x";
      break;
    default:
      fasSize = "";
      break;
  }
</script>

<span>
  <i
    class="{fasStyle} fa-{icon} {fasSize}"
    class:rightPad
    class:leftPad
    class:floatLeft
    class:hide
    class:color
    class:color-dark={colordark}
  />
</span>

<style>
  .rightPad {
    padding-right: 0.75rem;
  }

  .hide {
    display: none;
  }

  .color {
    color: #76808b;
  }

  .color-dark {
    color: #46404b;
  }

  .leftPad {
    padding-left: 0.75rem;
  }

  .floatLeft {
    float: left;
  }

  @media only screen and (max-width: 425px) {
    .floatLeft {
      float: unset;
    }
  }
</style>
