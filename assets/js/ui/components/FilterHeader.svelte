<script>
  import { onDestroy } from "svelte";
  import { dashboard_filter_modal } from "./../../store";
  import Button from "../atomic/Button.svelte";
  import { createEventDispatcher } from "svelte";
  import { requestorDashboardStatus } from "../../helpers/util";
  import {
    sessionStorageSave,
    sessionStorageRemove,
  } from "../../helpers/sessionStorageHelper";
  import { FILTERSTRINGSESSIONKEY } from "../../helpers/constants";
  import { calculateDateRanges } from "../../helpers/dateUtils";

  import qs from "qs";

  const dispatch = createEventDispatcher();

  export let assignments = [];
  const CHECKLISTSTATUSKEY = "checkliststatus";
  const RECIPIENTCOMPANY = "organization";
  const DATERANGESOBJECT = [
    { value: "Last 1 Day", range: "day", offset: "1" },
    { value: "Last 1 Week", range: "day", offset: "7" },
    { value: "Last 2 Weeks", range: "weeks", offset: "2" },
    { value: "Last 1 Month", range: "month", offset: "1" },
    { value: "Last 3 Months", range: "month", offset: "3" },
    { value: "Last 6 Months", range: "month", offset: "6" },
    { value: "Last 1 Year", range: "year", offset: "1" },
    { value: "All", range: "year", offset: "12" },
  ];
  const ALLCHECKLISTSTATUS = [0, 1, 2, 3, 4, 7, 9, 10];

  const createElementObj = (text, ret) => {
    return { text, ret };
  };

  const resetDropdownState = (key = "noclass") => {
    // reset dropdown values
    var selects = document.getElementsByTagName("select");
    for (let z = 0; z < selects.length; z++) {
      const sel = selects[z];
      if (sel.className.includes(key)) {
        sel.style.backgroundColor = "aliceblue";
      } else {
        sel.selectedIndex = "0";
        sel.style.backgroundColor = "white";
      }
    }
  };

  const resetFilters = () => {
    addToFilterStore(undefined, undefined);
    sessionStorageRemove(FILTERSTRINGSESSIONKEY);
    return resetDropdownState();
  };

  const applyFilters = () => {
    $dashboard_filter_modal = false;
  };

  const addFilterToSessionStorage = (queryString) => {
    sessionStorageRemove(FILTERSTRINGSESSIONKEY);
    sessionStorageSave(FILTERSTRINGSESSIONKEY, queryString);
  };

  const addToFilterStore = (optionKey, value) => {
    const queryString = qs.stringify(
      { apiKey: optionKey, value: [value] },
      { encode: true }
    );
    const hash = window.location.hash.split("?")[0];
    window.location.hash = `${hash}${queryString ? `?${queryString}` : ""}`;
    isFilteredApplied = true;
    dispatch("filterApplied");
    addFilterToSessionStorage(queryString);
    resetDropdownState(optionKey);
  };

  const getUserElements = (key) =>
    assignments.map((assignment) => {
      return createElementObj(
        assignment.recipient[key],
        assignment.recipient[key]
      );
    });

  const getRecipientCompanyElements = () => {
    const companies = assignments.map(
      (assignment) => assignment.recipient["company"]
    );
    return [...new Set(companies)].map((company) =>
      createElementObj(company, company)
    );
  };

  const getChecklistStatusElements = () => {
    return ALLCHECKLISTSTATUS.map((status) =>
      createElementObj(requestorDashboardStatus(status), status)
    );
  };

  const getDateRangeElements = () => {
    return DATERANGESOBJECT.map((range) => {
      const { value, ...period } = range;
      //stringify object config ;-D
      return createElementObj(value, JSON.stringify(period));
    });
  };

  const handleDateFilters = (evt) => {
    // Just a hack to support objects configurations ;-D
    const dateObj = JSON.parse(evt);
    const { from } = calculateDateRanges(dateObj);
    addToFilterStore("fromDate", from);
  };

  const filterComponents = [
    {
      filterLabel: "Company",
      filterKey: RECIPIENTCOMPANY,
      callback: (evt) => addToFilterStore(RECIPIENTCOMPANY, evt),
      elements: getRecipientCompanyElements(),
    },
    {
      filterLabel: "Checklist Status",
      filterKey: CHECKLISTSTATUSKEY,
      callback: (evt) => addToFilterStore(CHECKLISTSTATUSKEY, evt),
      elements: getChecklistStatusElements(),
    },
    {
      filterLabel: "Time Period",
      filterKey: "fromDate",
      callback: (evt) => handleDateFilters(evt),
      elements: getDateRangeElements(),
    },
    {
      filterLabel: "Requestor",
      filterKey: "email",
      callback: (evt) => addToFilterStore("email", evt),
      elements: getUserElements("email"),
    },
  ];
  let isFilteredApplied = window.location.hash.includes("?");
  let disableResetButton = isFilteredApplied ? false : true;
  $: if (isFilteredApplied) {
    disableResetButton = false;
  }

  onDestroy(() => {
    resetFilters();
  });
</script>

<div class="columns justify-end">
  {#each filterComponents as filterDropdown}
    <div class="column is-narrow">
      <div class="form-group">
        <label for="{filterDropdown.filterLabel}filterLabel"
          >{filterDropdown.filterLabel}</label
        >
        <span id={filterDropdown.filterLabel} class="select is-fullwidth">
          <select
            class={filterDropdown.filterKey}
            on:change={(e) => {
              if (e.target.value) {
                filterDropdown.callback(e.target.value);
              }
            }}
          >
            <option value="">{filterDropdown.filterLabel}</option>
            {#each filterDropdown.elements as element}
              <option value={element.ret}>{element.text}</option>
            {/each}
          </select>
        </span>
      </div>
    </div>
  {/each}
  <div class="columns flex-row column is-narrow action-btn align-self-end">
    <span on:click|stopPropagation={() => resetFilters()}>
      <Button color="danger" text="Reset" disabled={disableResetButton} />
    </span>
    <span class="mobile-only" on:click|stopPropagation={() => applyFilters()}>
      <Button color="secondary" text="Apply" disabled={disableResetButton} />
    </span>
  </div>
</div>

<style>
  .columns {
    display: flex;
    gap: 1rem;
    padding-bottom: 1rem;
  }
  .column {
    flex: 1;
  }
  .is-narrow {
    flex: unset;
    width: unset;
  }
  .justify-end {
    justify-content: flex-end;
  }
  .is-fullwidth {
    width: 100%;
  }
  .is-fullwidth select {
    width: 100%;
  }
  .select {
    display: inline-block;
    max-width: 100%;
    position: relative;
    vertical-align: top;
  }

  option {
    background-color: white !important;
  }
  .select::after {
    border: 3px solid transparent;
    border-radius: 2px;
    border-right: 0;
    border-top: 0;
    content: " ";
    display: block;
    height: 0.625em;
    margin-top: -9px;
    pointer-events: none;
    position: absolute;
    top: 50%;
    transform: rotate(-45deg);
    transform-origin: center;
    width: 0.625em;
  }
  .select::after {
    border-color: #000000;
    right: 1.125em;
    z-index: 4;
  }
  .select select {
    cursor: pointer;
    display: block;
    font-size: 1em;
    max-width: 100%;
    outline: 0;
    -moz-appearance: none;
    -webkit-appearance: none;
    align-items: center;
    border: 1px solid transparent;
    border-radius: 0.375em;
    box-shadow: none;
    display: inline-flex;
    font-size: 1rem;
    height: 2.5em;
    justify-content: flex-start;
    line-height: 1.5;
    padding-bottom: calc(0.5em - 1px);
    padding-left: calc(0.75em - 1px);
    padding-right: calc(0.75em - 1px);
    padding-top: calc(0.5em - 1px);
    position: relative;
    background-color: #fff;
    border-color: #dbdbdb;
    color: #363636;
  }
  .select select:not([multiple]) {
    padding-right: 2.5em;
  }
  .select select:hover {
    border-color: #b5b5b5;
  }
  .form-group {
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
  }
  .form-group label {
    margin-bottom: 0.5rem;
    color: #76808b;
  }
  .action-btn {
    padding-bottom: 0.2rem;
  }
  .align-self-end {
    align-self: flex-end;
  }
  .flex-row {
    flex-direction: row !important;
  }
  .mobile-only {
    display: none;
  }

  @media only screen and (max-width: 767px) {
    .columns {
      flex-direction: column;
      gap: 1rem;
    }
    .action-btn {
      justify-content: space-between;
      align-self: auto;
    }
    .mobile-only {
      display: block;
    }
  }
</style>
