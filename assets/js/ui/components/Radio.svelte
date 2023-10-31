<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";
  import { createEventDispatcher } from "svelte";
  const dispatch = createEventDispatcher();

  export let elements;
  export let selectedValue = 0;
  export let disable = false;
  export let disableReason = "Disabled!";
  export let showDisabledText = true;
  export let type;

  const handleClick = (value) => {
    console.log({ value });
    if (disable) {
      if (showDisabledText) {
        showToast(disableReason, 2000, "error", "MM");
      }
      dispatch("disabled", value);
    } else {
      selectedValue = value;
      dispatch("change", value);
    }
  };

  const onKeyDown = (event) => {
    let opt = event.target.querySelector(".value-text").innerHTML;
    console.log({ opt, event });
    switch (event.code) {
      case "Space":
        event.preventDefault();
      case "Enter":
        handleClick(opt);
        break;
      case "ArrowUp":
        const PrevElement = document.getElementById(event.target.id)
          .parentElement.previousSibling;
        if (PrevElement.classList) {
          PrevElement.firstChild.focus();
        }
        break;
      case "ArrowDown":
        const NextElement = document.getElementById(event.target.id)
          .parentElement.nextSibling;
        if (NextElement.classList) {
          NextElement.firstChild.focus();
        }
        break;
    }
  };
</script>

<div class="container">
  <!-- https://github.com/sveltejs/svelte/issues/894 -->
  {#each Object.entries(elements) as [key, val]}
    <div class="element">
      <div
        class="button"
        tabindex="0"
        id={`radio__${Math.floor(Math.random() * 1000)}`}
        on:keydown={onKeyDown}
        on:click={() => handleClick(val)}
        style={disable ? "cursor:not-allowed;" : ""}
      >
        {#if selectedValue == val}
          <span>
            <FAIcon icon="dot-circle" iconStyle="solid" />
          </span>
        {:else}
          <span>
            <FAIcon icon="circle" iconStyle="regular" />
          </span>
        {/if}
        <span class="text value-text" style={disable ? "color: #848485;" : ""}>
          {#if type == "Form"}
            {val}
          {:else if type != "Template"}
            {key}
          {:else}
            <span style="font-weight: bolder;">
              {key.split(".")[0]}.
            </span>
            {key.split(".")[1]}
          {/if}
        </span>
      </div>
    </div>
  {/each}
</div>

{#if $isToastVisible}
  <ToastBar />
{/if}

<style>
  .text {
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #4a5158;
  }

  .button {
    display: flex;
    gap: 16px;
    padding-right: 1rem;
    filter: drop-shadow(1px 2px 4px rgba(102, 71, 186, 0.18));
    font-size: 20px;
    color: #4a5158;
    cursor: pointer;
    user-select: none;
    -webkit-touch-callout: none;
    -webkit-user-select: none;
    -khtml-user-select: none;
    -moz-user-select: none;
    -ms-user-select: none;
  }

  .element {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    padding-bottom: 1rem;
    word-break: break-word;
  }
</style>
