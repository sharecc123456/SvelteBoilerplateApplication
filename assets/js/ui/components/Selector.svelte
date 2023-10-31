<script>
  import Dropdown from "./Dropdown.svelte";

  export let options = [
    { text: "File", icon: "file-alt", iconStyle: "solid", value: "file" },
    { text: "Data", icon: "keyboard", iconStyle: "solid", value: "data" },
    { text: "Task", icon: "tasks", iconStyle: "solid", value: "task" },
  ];

  export let value;
  let index = options.findIndex((x) => x.value === value);
  export let defaultIndex = index != -1 ? index : 0,
    classes = "",
    style,
    parentClasses = "";

  let chosenElement = options[defaultIndex].text;
  value = options[defaultIndex].value;

  function dropdownElementify(options) {
    let i = 0;
    return options.map((e) => {
      // icon & iconStyle are disabled due to padding and alignment issues
      return {
        text: e.text,
        ret: i++,
      };
    });
  }
</script>

<div class="container" {style}>
  <Dropdown
    text={chosenElement}
    clickHandler={(ret) => {
      chosenElement = options[ret].text;
      value = options[ret].value;
    }}
    elements={dropdownElementify(options)}
    {classes}
    {parentClasses}
  />
</div>

<style>
  .container {
    width: 100%;
  }
</style>
