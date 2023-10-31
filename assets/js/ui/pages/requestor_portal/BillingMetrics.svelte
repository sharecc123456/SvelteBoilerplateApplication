<script>
  import { onMount } from "svelte";
  export let tableData = {};

  const tableHeaders = {
    blank: { label: "", index: 0 },
    week: { label: "Last 7 days", index: 1 },
    last_month: { label: "Previous month", index: 3 },
    current_month: { label: "Month-to-date", index: 2 },
    current_year: { label: "Year-to-date", index: 6 },
    lifetime: { label: "Lifetime", index: 7 },
    current_quarter: { label: "Current quarter", index: 4 },
    last_quarter: { label: "Last quarter", index: 5 },
  };

  const metricsConfig = {
    active_recipients: { label: "Active contacts", order: 1 },
    deleted_recipients: { label: "Deleted contacts", order: 5 },
    total_recipients: { label: "Total contacts", order: 6 },
    checklists_sent: { label: "Checklists sent", order: 10 },
    rspec_documents_processed: { label: "Custom docs sent (RSDs)", order: 15 },
    generic_documents_processed: { label: "Generic docs sent", order: 20 },
    signature_processed: { label: "Signatures", order: 25 },
    files_uploaded: { label: "Files uploads", order: 30 },
    data_inputs: { label: "Data inputs", order: 35 },
    task_completed: { label: "Tasks completed", order: 40 },
    forms_processed: { label: "Forms processed", order: 45 },
    total: {
      label: "Total Requests Processed",
      order: 50,
      style: "font-weight: bolder",
    },
    forms_answered: { label: "Questions completed", order: 55 },
  };

  /**
   * Table configurations
   */
  let columnHeadings = [];
  const metricsKeys = Object.keys(metricsConfig).sort(function (a, b) {
    return metricsConfig[a]["order"] - metricsConfig[b]["order"];
  });

  const sortedtableHeaders = () => {
    const headerKeys = Object.keys(tableHeaders);
    columnHeadings = [...headerKeys].sort(
      (a, b) => tableHeaders[a]["index"] - tableHeaders[b]["index"]
    );
  };

  const calculateTotalRequests = [
    "rspec_documents_processed",
    "signature_processed",
    "forms_processed",
    "task_completed",
    "data_inputs",
    "files_uploaded",
    "generic_documents_processed",
    "total",
  ];

  onMount(() => {
    sortedtableHeaders();
  });
</script>

<div class="table-container">
  <table class="blueTable">
    <caption align="center">Usage metrics</caption>
    <thead>
      <tr>
        {#each columnHeadings as heading}
          <th>{tableHeaders[heading]["label"]}</th>
        {/each}
      </tr><tr />
    </thead>
    <tbody>
      {#each metricsKeys as metrics}
        <tr
          class:metric-calculated-field={calculateTotalRequests.includes(
            metrics
          )}
          style={metricsConfig[metrics]["style"] || ""}
        >
          <td>{metricsConfig[metrics]["label"]}</td>
          <td>{tableData["week"][metrics] || 0}</td>
          <td>{tableData["current_month"][metrics] || 0}</td>
          <td>{tableData["last_month"][metrics] || 0}</td>
          <td>{tableData["current_quarter"][metrics] || 0}</td>
          <td>{tableData["last_quarter"][metrics] || 0}</td>
          <td>{tableData["current_year"][metrics] || 0}</td>
          <td>{tableData["lifetime"][metrics] || 0}</td>
        </tr>
      {/each}
    </tbody>
  </table>
</div>

<style>
  table,
  th,
  td {
    border: 1px solid;
    border-collapse: collapse;
    margin-bottom: 10px;
  }

  td {
    color: #4a5157;
  }

  .table-container {
    width: 100%;
    overflow: auto;
  }

  table.blueTable {
    border: 1px solid #1c6ea4;
    background-color: #eeeeee;
    text-align: center;
    border-collapse: collapse;
    min-width: calc(100% - 20px);
  }
  table.blueTable td,
  table.blueTable th {
    border: 1px solid #aaaaaa;
    padding: 3px 2px;
  }
  table.blueTable tbody td {
    font-size: 13px;
  }
  table.blueTable tr:nth-child(even) {
    background: #d0e4f5;
  }
  table.blueTable thead {
    background: #1c6ea4;
    background: -moz-linear-gradient(
      top,
      #5592bb 0%,
      #327cad 66%,
      #1c6ea4 100%
    );
    background: -webkit-linear-gradient(
      top,
      #5592bb 0%,
      #327cad 66%,
      #1c6ea4 100%
    );
    background: linear-gradient(
      to bottom,
      #5592bb 0%,
      #327cad 66%,
      #1c6ea4 100%
    );
    border-bottom: 2px solid #444444;
  }
  table.blueTable thead th {
    font-size: 15px;
    font-weight: bold;
    color: #ffffff;
    border-left: 2px solid #d0e4f5;
  }
  table.blueTable thead th:first-child {
    border-left: none;
  }

  .metric-calculated-field {
    background-color: #bfbfbf !important;
  }

  table.blueTable tbody tr td:first-child {
    text-align: left !important;
  }
</style>
