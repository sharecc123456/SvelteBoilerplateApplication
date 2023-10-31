<script>
  import Checkbox from "../Checkbox.svelte";
  export let options = [];
  export let values = [];
  export let readOnly = false;

  const handleClick = (opt) => {
    if (readOnly) return;
    if (valueExists(opt)) {
      removeValue(opt);
    } else {
      addValue(opt);
    }
  };

  const valueExists = (opt) => values?.length && values.includes(opt);

  const removeValue = (opt) => {
    if (!values?.length) return;
    const vIndex = values.findIndex((v) => v === opt);
    if (vIndex != -1) {
      values = [
        ...values.slice(0, vIndex),
        ...values.slice(vIndex + 1, values.length),
      ];
    }
  };

  const addValue = (opt) => {
    if (!values?.length) {
      values = [opt];
    } else {
      values = [...values, opt];
    }
  };

  const onKeyDown = (event) => {
    let opt = event.target.querySelector(".value-text").innerHTML;
    switch (event.code) {
      case "Space":
        event.preventDefault();
      case "Enter":
        handleClick(opt);
        break;
      case "ArrowUp":
        const NextElement = document.getElementById(
          event.target.id
        ).previousSibling;
        if (NextElement.classList) {
          NextElement.focus();
        }
        break;
      case "ArrowDown":
        const PrevElement = document.getElementById(
          event.target.id
        ).nextSibling;
        if (PrevElement.classList) {
          PrevElement.focus();
        }
        break;
    }
  };
</script>

{#each options as opt}
  <div class="container">
    <div
      on:click={() => handleClick(opt)}
      tabindex="0"
      on:keydown={onKeyDown}
      id={`checkbox__${Math.floor(Math.random() * 1000)}`}
    >
      <Checkbox
        text={opt}
        isChecked={values !== undefined &&
          values.length &&
          values.includes(opt)}
        type="Form"
        disable={readOnly}
      />
    </div>
  </div>
{/each}

<style>
  .container {
    display: flex;
    margin-bottom: 1rem;
  }
</style>
