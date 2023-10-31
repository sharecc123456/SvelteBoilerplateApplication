<script>
  import FAIcon from "../atomic/FAIcon.svelte";
  export let elements = ["Select", "Edit", "Match", "Complete"];
  export let current = 2;
</script>

<div class="container">
  {#each elements as elem, idx}
    <div
      class="element"
      class:current={current == idx}
      class:done={idx < current}
    >
      <span class="icon">
        {#if current < idx}
          <FAIcon iconSize="large" iconStyle="regular" icon="circle" />
        {:else if current == idx}
          <span style="font-size: 24px;"> &#9680; </span>
        {:else}
          <FAIcon iconSize="large" icon="circle" />
        {/if}
      </span>
      <p>{elem}</p>
    </div>
    {#if idx != elements.length - 1}
      <hr />
    {/if}
  {/each}
</div>

<style>
  hr {
    width: 60px;
    height: 0.5px;
    margin: 0px 5px;
    color: #b3c1d0;
  }

  .element {
    font-style: normal;
    font-weight: 600;
    font-size: 16px;
    line-height: 16px;
    color: #b3c1d0;

    display: flex;
    flex-flow: row nowrap;
    flex-grow: 0;
    align-items: center;
  }

  .element > .icon {
    padding-right: 0.5rem;
  }

  .element.current {
    font-weight: 600;
    font-size: 16px;
    line-height: 16px;
    color: #4badf3;
  }

  .element.done {
    font-weight: 600;
    font-size: 16px;
    line-height: 16px;
    color: #2a2f34;
  }

  .container {
    display: flex;
    flex-flow: row nowrap;
    flex-grow: 0;
    align-items: center;
  }
  @media only screen and (max-width: 425px) {
    .element {
      font-size: 12px;
    }
    .element.done {
      font-size: 12px;
    }
    .element.current {
      font-size: 12px;
    }
    hr {
      width: 30px;
    }
  }
  @media only screen and (max-width: 425px) {
    hr {
      width: 10px;
    }
  }
</style>
