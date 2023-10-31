<script>
  export let text = "Undefined";
  export let type = "text";
  export let icon = "";
  export let iconStyle = "solid";
  export let focused = false;
  export let blured = false;
  export let invalidInput = false;
  export let elm;
  import { onMount, createEventDispatcher } from "svelte";
  import FAIcon from "../atomic/FAIcon.svelte";
  export let value = "";
  export let width = "100%";
  export let height = "2rem";
  export let float = "none";
  export let dropdownEnabled = false;
  export let dropDownContents = [];
  export let enterCallback = () => {};
  export let focusCallback = () => {};
  export let datalistId = "contents";
  export let disabled = false;
  export let maxlength = null;
  export let reFocused = true;
  export let useFocusCallback = () => {};
  const dispatch = createEventDispatcher();

  onMount(function () {
    if (focused) elm.focus();
    if (blured) elm.blur();
    elm.addEventListener("keydown", (e) => {
      if (e.key !== "Enter") focusCallback();
      else enterCallback();
    });
  });

  function focusAndOpenKeyboard(el, timeout) {
    if (!timeout) {
      timeout = 100;
    }
    if (el) {
      // Align temp input element approximately where the input element is
      // so the cursor doesn't jump around
      var __tempEl__ = document.createElement("input");
      __tempEl__.style.height = 0;
      __tempEl__.style.opacity = 0;
      // Put this temp element as a child of the page <body> and focus on it
      document.body.appendChild(__tempEl__);
      __tempEl__.focus();

      // The keyboard is open. Now do a delayed focus on the target element
      setTimeout(function () {
        el.focus();
        el.click();
        // Remove the temp element
        document.body.removeChild(__tempEl__);
      }, timeout);
    }
  }

  $: {
    if (focused && elm) {
      elm.focus();

      focusAndOpenKeyboard(elm);
    }
  }

  $: {
    if (reFocused) {
      if (focused && elm) {
        elm.focus();

        focusAndOpenKeyboard(elm);
      }
    }
  }
</script>

<div
  class="input-with-icon"
  style={"width: " +
    width +
    ";" +
    "height: " +
    height +
    "; float: " +
    float +
    " "}
>
  {#if icon != ""}
    <span class="input-the-icon">
      <FAIcon {icon} {iconStyle} />
    </span>
  {/if}
  {#if type == "password"}
    <input
      type="password"
      bind:value
      bind:this={elm}
      class:input-icon={icon != ""}
      use:useFocusCallback
      class:input={icon == ""}
      placeholder={text}
      maxlength={maxlength === null ? "255" : maxlength}
      style={"height: " + height + ";"}
    />
  {:else if type == "number"}
    <input
      type="number"
      bind:value
      list={datalistId}
      class:input-icon={icon != ""}
      class:input={icon == ""}
      class:search-input-bar={icon != ""}
      class:errormessage={invalidInput}
      {disabled}
      bind:this={elm}
      placeholder={text}
      maxlength={maxlength === null ? "255" : maxlength}
      style={"height: " + height + ";"}
      on:blur={() => {
        dispatch("blur");
      }}
      use:useFocusCallback
    />
  {:else}
    <!-- 
    Inserting text with the word “search” 
    into the name attribute will prevent 
    Safari from showing the AutoFill icon and keyboard option. 
    This works because Safari performs a regex and maps “search” 
    to an input that does not require the AutoFill.
    #8987

    MJ.
  -->
    <input
      name="search"
      autocomplete="off"
      bind:value
      list={datalistId}
      class:input-icon={icon != ""}
      class:input={icon == ""}
      class:search-input-bar={icon != ""}
      class:errormessage={invalidInput}
      {disabled}
      bind:this={elm}
      placeholder={text}
      maxlength={maxlength === null ? "255" : maxlength}
      style={"height: " + height + ";"}
      on:blur
      use:useFocusCallback
    />
    {#if dropdownEnabled}
      <datalist id={datalistId}>
        {#each dropDownContents as value}
          <option {value} />{/each}
      </datalist>
    {/if}
  {/if}
</div>

<style>
  input::-webkit-calendar-picker-indicator {
    opacity: 100;
  }
  .input-icon {
    background: #ffffff;
    width: 100%;
    height: 2rem;
    text-align: left;
    /* Gray 300 */
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;

    padding-left: 50px;
  }

  .input {
    background: #ffffff;

    width: 100%;
    min-width: 100%;
    max-width: 100%;
    text-align: left;
    /* Gray 300 */
    border: 1px solid #b3c1d0;
    box-sizing: border-box;
    border-radius: 5px;

    padding-left: 1rem;
  }

  .input-the-icon {
    position: absolute;
    padding-top: 0.4rem;
    padding-left: 1rem;
    color: #76808b;
  }

  .errormessage {
    border-color: #cc0033;
  }

  .search-input-bar {
    padding-right: 25px;
  }

  input:hover {
    border: 1px solid #4badf3;
    box-sizing: border-box;
    border-radius: 5px;
  }

  input {
    font-size: inherit;
  }

  .input-with-icon {
    font-family: "Nunito", sans-serif;
    font-style: normal;
  }

  @media only screen and (max-width: 767px) {
    input {
      font-size: 14px;
    }
  }
</style>
