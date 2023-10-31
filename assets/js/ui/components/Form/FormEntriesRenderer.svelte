<script>
  export let formData = {};

  const { formFields, entries } = formData;
</script>

<table class="entry-table">
  <thead>
    <tr>
      {#each formFields as field}
        {#if field.type !== "instruction"}
          <th>
            <div class="content">{field.title}</div>
          </th>
        {/if}
      {/each}
    </tr>
  </thead>
  {#if entries?.length}
    <tbody>
      {#each entries as entry}
        <tr>
          {#each formData.formFields as field}
            {#if field.type !== "instruction"}
              {#if field.is_multiple}
                <td>
                  <div class="content">
                    {#each entry[field.id] as val}
                      <span class="pill">
                        {val}
                      </span>
                    {/each}
                  </div>
                </td>
              {:else}
                <td>
                  <!-- Dont need to show the instruction type here -->
                  {#if typeof entry[field.id] === "undefined"}
                    <span />
                  {:else}
                    <div class="content">
                      {field.type === "date"
                        ? entry[field.id].split("T")[0]
                        : entry[field.id]}
                    </div>
                  {/if}
                </td>
              {/if}
            {/if}
          {/each}
        </tr>
      {/each}
    </tbody>
  {/if}
</table>

<style>
  .entry-table {
    display: block;
    overflow-x: auto;
    font-family: Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    width: 100%;
    margin-top: 1rem;
    box-shadow: rgba(50, 50, 93, 0.25) 0px 2px 5px -1px,
      rgba(0, 0, 0, 0.3) 0px 1px 3px -1px;
  }

  .entry-table td,
  .entry-table th {
    border: 1px solid #ddd;
    padding: 8px;
  }

  .entry-table tr:nth-child(even) {
    background-color: #f2f2f2;
  }

  .entry-table tr:hover {
    background-color: #ddd;
  }

  .entry-table th {
    padding-top: 12px;
    padding-bottom: 12px;
    text-align: left;
    background-color: #4a5158;
    color: white;
  }

  .content {
    display: -webkit-box;
    width: 300px;
    -webkit-line-clamp: 5;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .content:hover {
    z-index: 1;
    width: auto;
    display: inline;
  }

  .pill {
    border-radius: 15px;
    border: 0.5px #ccc solid;
    padding: 0.3rem 0.5rem;
    display: inline-block;
    margin-left: 0.8rem;
  }
</style>
