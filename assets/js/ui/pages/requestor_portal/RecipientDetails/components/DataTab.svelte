<script>
  import { onMount } from "svelte";
  import ChooseTemplateModal from "../../../../modals/ChooseTemplateModal.svelte";
  import ChooseChecklistModal from "../../../../modals/ChooseChecklistModal.svelte";
  import FaIcon from "../../../../atomic/FAIcon.svelte";
  import TextField from "../../../../components/TextField.svelte";
  import Button from "../../../../atomic/Button.svelte";
  import Modal from "../../../../components/Modal.svelte";
  import {
    recipientAddData
  } from "BoilerplateAPI/Recipient";
  import { getFormById } from "BoilerplateAPI/Form";
  import {
    searchParamObject,
    getJsDateString,
  } from "../../../../../helpers/util";
  import FormFillDataTab from "../../../../components/Form/FormFillDataTab.svelte";
  import ConfirmationDialog from "../../../../components/ConfirmationDialog.svelte";

  export let recipient = {};
  let showAddPoint = false;
  export let showAddOptions = false;
  export let showAddForm = false;
  let addFormType = "add";
  let showFormInput = false;
  let formData = undefined;
  let forms = [];
  let showTableModal = false;

  let editingPID = undefined;
  let editingPVal = "";
  let inputLabel = "",
    inputValue = "";
  export let inHistoryView = false;
  export let filterType = "";
  export let filterParamFs = "";
  export let filterParamCs = "";
  let filterShowText = "";
  let profileData = [];
  // check if there is a filter
  const searchParams = searchParamObject();

  function loadProfileData() {
    profileData = [];
    if (filterType == "fs") {
      filterShowText = searchParams.showText;
      profileData = fetch(`/n/api/v1/recipient/${recipient.id}/data/filter`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({
          form_submission_id: filterParamFs,
          contents_id: null,
        }),
      }).then((x) => x.json());
    } else if (filterType == "cs") {
      filterShowText = searchParams.showText;
      profileData = fetch(`/n/api/v1/recipient/${recipient.id}/data/filter`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({
          contents_id: filterParamCs,
          form_submission_id: null,
        }),
      }).then((x) => x.json());
    } else {
      profileData = fetch(`/n/api/v1/recipient/${recipient.id}/data`).then(
        (x) => x.json()
      );
    }
  }

  onMount(() => {
    filterType = searchParams.filter;
    filterParamFs = searchParams.fs;
    filterParamCs = searchParams.cs;
    loadProfileData();
  });

  function transformTableHeaders(entry) {
    let headers = Object.keys(entry);
    if ("sort_order" in entry[headers[0]]) {
      headers.sort((a, b) => {
        return entry[a].sort_order - entry[b].sort_order;
      });
      return headers.map((x) => {
        return { name: x };
      });
    } else if ("fieldId" in entry[headers[0]]) {
      // sort by field Id
      headers.sort((a, b) => {
        return entry[a].fieldId - entry[b].fieldId;
      });
      return headers.map((x) => {
        return { name: x };
      });
    } else {
      alert("cannot transform the table into headers");
      return undefined;
    }
  }

  function transformTable(entry) {
    let sortedHeaders = transformTableHeaders(entry);
    return sortedHeaders.map((x) => {
      return { name: x, value: entry[x.name].value };
    });
  }

  /*
  let labelCache = undefined;
  async function getAllLabels(keyword) {
    if (labelCache == undefined) {
      let r = await fetch("/n/api/v1/iac/labels");
      if (r.status != 200) {
        console.error(`Error fetching IAC labels: ${r.status}`);
        labelCache = [];
      } else {
        let final = await r.json();
        labelCache = final.map((x) => x.value);
      }
    }

    return labelCache;
  } */

  async function editTable(p_entry) {
    let form_id = p_entry.source.origin_id;
    if (form_id == undefined || form_id == null || form_id == 0) {
      alert("editTable: invalid origin_id");
      return;
    }

    let form_raw = await getFormById(form_id);
    let form = await form_raw.json();
    form.entries = [];
    for (let entry of p_entry.value) {
      let acc = {};
      let accValid = false;
      for (let key in entry) {
        let entry_v = entry[key];
        // HACK: this is not nice at all - let's find the field using its name.....
        let candidateField = form.formFields.find((x) => x.title == key);
        if (candidateField != undefined) {
          acc[candidateField.id] = entry_v["value"];
          accValid = true;
        } else {
          console.error(`couldn't find a candidate field for title ${key}`);
        }
      }
      if (accValid) {
        form.entries.push(acc);
      }
    }

    forms = [form];
    formData = forms[0];
    console.log({ msg: "editTable", form });
    showFormInput = true;
  }

  function addDataFromSelectedTemplates(selevt) {
    // Get the labels & questions from each raw document
    let templateIds = selevt.detail.templateIds;
    let templates = selevt.detail.templates;
    // ask the backend to process the selection into a presudo
    // form that we can then display
    fetch(`/n/api/v1/recipient/${recipient.id}/data/form`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify({
        templates: templateIds,
      }),
    }).then(async (x) => {
      let p = await x.json();
      let proData = await profileData;
      formData = {
        id: 0,
        title: templates[0].name,
        description: templates[0].description,
        has_repeat_entries: false,
        has_repeat_vertical: false,
        repeat_label: "",
        formFields: p.basic_form.map((el) => {
          let f = proData.find((x) => x.label == el.label);
          if (f == undefined) {
            return el;
          } else {
            //console.log({msg: "f before", f, el});
            if (el.is_multiple) {
              el.values = f.value;
            } else {
              if (el.type == "radio") {
                el.value = f.value[0];
              } else {
                el.value = f.value;
              }
            }
            return el;
          }
        }),
      };
      forms[0] = formData;
      // add data into the repeat entry forms
      for (let i = 0; i < p.repeat_entry_forms.length; i++) {
        let tableData = proData.find(
          (x) => x.label == p.repeat_entry_forms[i].repeat_label
        );

        if (tableData == undefined) {
          // do nothing
          continue;
        }

        p.repeat_entry_forms[i].entries = [];
        for (let entry of tableData.value) {
          let acc = {};
          let accValid = false;
          for (let key in entry) {
            let entry_v = entry[key];
            let acc_key = entry_v["fieldId"];
            if (acc_key != undefined) {
              // this data is manual input
              acc[acc_key] = entry_v["value"];
              accValid = true;
            } else {
              // this data came straight from the client portal
              // HACK: this is not nice at all - let's find the field using its name.....
              let candidateField = p.repeat_entry_forms[i].formFields.find(
                (x) => x.title == key
              );
              if (candidateField != undefined) {
                acc[candidateField.id] = entry_v["value"];
                accValid = true;
              } else {
                console.error(
                  `couldn't find a candidate field for title ${key}`
                );
              }
            }
          }
          if (accValid) {
            p.repeat_entry_forms[i].entries.push(acc);
          }
        }
        console.log({
          msg: "repeatEntryFill",
          i,
          tableData,
          entries: p.repeat_entry_forms[i].entries,
        });
      }
      forms = forms.concat(p.repeat_entry_forms);
      showAddForm = false;
      if (addFormType == "send") {
        console.log({ forms });
        fetch(`/n/api/v1/recipient/${recipient.id}/data/verifyform`, {
          method: "POST",
          headers: {
            "content-type": "application/json",
          },
          credentials: "include",
          body: JSON.stringify({
            forms: forms,
            templateName: templates[0].name,
          }),
        }).then(async (resp) => {
          if (resp.ok) {
            let rep = await resp.json();
            window.location.href = `#recipient/${recipient.id}/assign/${rep.checklistId}`;
          }
        });
      } else {
        showFormInput = true;
        console.log({ p });
        console.log({ forms });
      }
    });
  }

  // Add a simple label to the profile data.
  function addNewDataPoint(label, value) {
    if (label == undefined || label == null || label.trim() == "") {
      alert("Please provide a non-empty label.");
      return;
    }

    profileData = profileData.then((x) => {
      let newObj = {
        id: Math.floor(Math.random() * 100000), // XXX
        label: label,
        value: value,
        updated: getJsDateString(), // XXX
        source: {
          type: "profile",
          origin: "manual",
        },
        type: "shortAnswer",
      };

      // Check if the label already exists
      let existingDataIdx = x.findIndex((y) => y.label == label);
      if (existingDataIdx != -1) {
        newObj.id = x[existingDataIdx].id;
        x[existingDataIdx] = newObj;
      } else {
        x.push(newObj);
      }
      recipientAddData(recipient.id, label, value);
      inputLabel = "";
      inputValue = "";
      showAddPoint = false;
      return x;
    });
  }

  // update an existing profile data
  function updateDataPoint(p, value, index) {
    // update locally
    p.value = value;
    p.updated = getJsDateString(); // XXX
    p.source = {
      type: "profile",
      origin: "manual",
    };
    profileData[index] = p;
    editingPID = undefined;

    recipientAddData(recipient.id, p.label, value);
  }

  async function showHistory(p) {
    let resp = await fetch(
      `/n/api/v1/recipient/${recipient.id}/data/label/history`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
        },
        credentials: "include",
        body: JSON.stringify({
          label: p.label,
        }),
      }
    );
    profileData = await resp.json();
    inHistoryView = true;
  }

  let showSendTemplate = false;
  export let showVerificationOptions = false;
  const verificationOptions = [
    {
      title: "Verify Single Template",
      callback: () => {
        addFormType = "send";
        showAddForm = true;
      },
      icon: "copy",
    },
  ];
  const addOptions = [
    {
      title: "Single Data Field",
      callback: () => (showAddPoint = true),
      icon: "plus",
    },
    {
      title: "List of fields to fill a PDF template",
      callback: () => {
        addFormType = "add";
        showAddForm = true;
      },
      icon: "plus",
    },
    //{
    //title: "Add Repeat Entry Data",
    //callback: () => {
    //alert("Not implemented yet");
    //},
    //icon: "plus",
    //},
  ];
</script>

<div class="container">
  {#if filterType != undefined}
    <span
      on:click={() => {
        filterType = undefined;
        inHistoryView = false;
        loadProfileData();
      }}
    >
      <Button text="Exit Filter: {filterShowText}" />
    </span>
  {/if}
  {#if inHistoryView}
    <span
      on:click={() => {
        loadProfileData();
        inHistoryView = false;
      }}
    >
      <Button text="Exit History View" />
    </span>
  {/if}
  <div class="card">
    {#await profileData then pd}
      <div class="row" style="border-bottom: 2px solid #aaaaaa">
        <div class="label">Label</div>
        <div class="source">Data Source</div>
        <div class="origin">Origin</div>
        <div class="value">Value</div>
        <div class="updated">Last Updated</div>
      </div>
      {#each pd as p, i}
        <div class="row">
          <div class="label">
            <span
              style="cursor: pointer;"
              on:click={() => {
                showHistory(p);
              }}
            >
              {p.label}
            </span>
            {#if editingPID != p.id && p.type != "checkbox" && p.type != "radio" && p.type != "decision"}
              {#if !inHistoryView}
                <span
                  class="edit-icon"
                  on:click={() => {
                    editingPID = p.id;
                    editingPVal = p.value;
                    if (p.source.type == "form_data_repeat") {
                      editTable(p);
                    }
                    console.log(p);
                  }}
                >
                  <FaIcon icon="edit" iconStyle="regular" />
                </span>
              {/if}
              {#if p.source.type == "form_data_repeat"}
                <span
                  class="edit-icon"
                  on:click={() => {
                    editingPID = p.id;
                    editingPVal = p.value;
                    showTableModal = true;
                    console.log(p);
                  }}
                >
                  <FaIcon icon="eye" iconStyle="regular" />
                </span>
              {/if}
            {:else}
              <!-- <span
                class="edit-icon"
                on:click={() => {
                  editingPID = undefined;
                }}
              >
                <FaIcon icon="circle-xmark" iconStyle="regular" />
              </span> -->
            {/if}
          </div>
          <div class="source">
            {#if p.source.type == "form_data"}
              Digital Form Input
            {:else if p.source.type == "form_data_repeat"}
              Repeat Entry Input
            {:else if p.source.type == "profile"}
              Manual Profile Data
            {:else}
              {p.source}
            {/if}
          </div>
          <div class="origin">
            {#if p.source.type == "form_data" || p.source.type == "form_data_repeat"}
              {p.source.origin}
            {:else if p.source.type == "profile"}
              Manual Input
            {:else}
              N/A
            {/if}
          </div>
          <div class="updated">
            <!-- TODO(lev/9490): Figure out how to format this with local changes appearing properly -->
            <span>{p.updated}</span>
          </div>
          <div class="value">
            {#if editingPID != p.id}
              {#if p.source.type == "form_data_repeat"}
                <i>Table</i> with {Object.keys(p.value).length}
                {Object.keys(p.value).length > 1 ? "entries" : "entry"}
              {:else}
                {p.value}
              {/if}
            {:else if p.source.type == "form_data_repeat"}
              <!-- edit for this is done in a modal -->
              <i>Table</i> with {Object.keys(p.value).length}
              {Object.keys(p.value).length > 1 ? "entries" : "entry"}
            {:else}
              <div class="edit-field">
                <div style="grid-area: field;">
                  <TextField bind:value={editingPVal} />
                </div>
                <div
                  style="grid-area: btn;"
                  on:click={() => {
                    updateDataPoint(p, editingPVal, i);
                  }}
                >
                  <Button icon="save" color="primary" text="Save" />
                </div>
                <div
                  style="grid-area: btn2;"
                  on:click={() => {
                    editingPID = undefined;
                  }}
                >
                  <Button icon="cancel" color="gray" text="Cancel" />
                </div>
              </div>
            {/if}
          </div>
        </div>
      {:else}
        {#if filterType != undefined && filterType != ""}
          <p>
            No data for this client yet or the filter didn't return any results.
          </p>
        {:else}
          <p>No data for this client yet.</p>
        {/if}
      {/each}
    {/await}
  </div>
</div>

{#if showAddPoint}
  <Modal
    maxWidth="32rem"
    title={"Add New Data Point"}
    on:close={() => {
      inputLabel = "";
      inputValue = "";
      showAddPoint = false;
    }}
  >
    <div style="margin-top: 1.4rem;">
      <!--
      <div>
        <AutoComplete
          onCreate={(e) => {
            labelCache.push(e);
            return e;
          }}
          searchFunction={getAllLabels}
          placeholder="Label for the data point"
          delay={300}
          create={true}
          bind:selectedItem={inputLabel}
        />
      </div>

      <div style="margin-top: 0.5rem;">
        <TextField text={"Value for the data point"} bind:value={inputValue} />
      </div>
      -->
      <label for="label">Label</label>
      <TextField text={"Label for the data point"} bind:value={inputLabel} />
      <label for="value">Value</label>
      <TextField text={"Value for the data point"} bind:value={inputValue} />

      <div
        style="margin-top: 2rem; display: flex; flex-flow: row nowrap; gap: 1rem; justify-content: space-between;"
      >
        <span
          on:click={() => {
            addNewDataPoint(inputLabel, inputValue);
          }}
        >
          <Button text="Add" color="primary" />
        </span>
        <span
          on:click={() => {
            inputLabel = "";
            inputValue = "";
            showAddPoint = false;
          }}
        >
          <Button text="Cancel" color="gray" />
        </span>
      </div>
    </div>
  </Modal>
{/if}

{#if showFormInput}
  <Modal
    maxWidth="48rem"
    on:close={() => {
      showFormInput = false;
      editingPID = undefined;
      editingPVal = undefined;
    }}
  >
    <FormFillDataTab bind:forms bind:formData {recipient} {profileData} />
  </Modal>
{/if}

{#if showAddForm}
  <ChooseTemplateModal
    fullScreenDisplay={false}
    showSelectionCount={false}
    customButtonText={true}
    buttonText={addFormType == "add"
      ? "Add Data From Form"
      : "Send Form for Verification"}
    templateFilter={"labelled"}
    on:selectionMade={(evt) => {
      addDataFromSelectedTemplates(evt);
      showAddForm = false;
    }}
    selectOne={true}
    title={"Select One"}
    on:close={() => {
      showAddForm = false;
    }}
  />
{/if}

{#if showVerificationOptions}
  <ConfirmationDialog
    title={"Choose Options"}
    question={""}
    hideText="Close"
    hideColor="white"
    hyperLinks={verificationOptions}
    hyperLinksColor="black"
    on:close={(event) => {
      showVerificationOptions = false;
    }}
    on:hide={(event) => {
      showVerificationOptions = false;

      if (event.detail) {
        const callbackHandler = event.detail.callback;
        callbackHandler();
      }
    }}
  />
{/if}

{#if showAddOptions}
  <ConfirmationDialog
    title={"Choose Data to Add for this Contact"}
    question={""}
    hideText="Close"
    hideColor="white"
    hyperLinks={addOptions}
    hyperLinksColor="black"
    on:close={(event) => {
      showAddOptions = false;
    }}
    on:hide={(event) => {
      showAddOptions = false;

      if (event.detail) {
        const callbackHandler = event.detail.callback;
        callbackHandler();
      }
    }}
  />
{/if}

{#if showTableModal}
  <Modal
    maxWidth="calc(100vw - 4em)"
    on:close={() => {
      showTableModal = false;
      editingPVal = undefined;
      editingPID = undefined;
    }}
  >
    <div style="margin-top: 2rem;">
      <table class="entry-table">
        <thead>
          <tr>
            {#each transformTableHeaders(editingPVal[0]) as field}
              <th>
                <div class="content">{field.name}</div>
              </th>
            {/each}
          </tr>
        </thead>
        <tbody>
          {#each editingPVal as entry}
            <tr>
              {#each transformTable(entry) as field}
                <td>
                  <div class="content">{field.value}</div>
                </td>
              {/each}
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </Modal>
{/if}

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
  * {
    box-sizing: border-box;
  }

  .edit-icon {
    cursor: pointer;
  }

  .container {
    max-width: 1000px;
    margin: 2em auto;
    padding: 0 1em;
  }

  .card {
    padding: 2em;
    box-shadow: rgba(0, 0, 0, 0.1) 0px 4px 12px;
    border-radius: 15px;
    position: relative;
  }

  .row {
    width: 100%;
    display: grid;
    grid-template-columns: 0.65fr 0.15fr 0.15fr;
    grid-template-rows: auto;
    grid-template-areas: "label source updated" "value origin updated";
    align-items: center;
    margin-bottom: 1rem;
    border-bottom: 0.5px solid #e0e2e3;
    padding-bottom: 0.5rem;
  }

  .row:last-child {
    margin-bottom: 0;
  }

  .row .label {
    font-weight: bold;
    grid-area: label;
    width: 95%;
    overflow-wrap: break-word;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .row .updated {
    grid-area: updated;
    font-size: 12px;
  }

  .row .source {
    grid-area: source;
    font-size: 12px;
  }

  .row .origin {
    grid-area: origin;
    font-size: 12px;
  }

  .row .value {
    grid-area: value;
    width: 95%;
    overflow-wrap: break-word;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .edit-field {
    width: 100%;
    display: grid;
    grid-template-columns: 0.4fr 0.1fr 0.4fr;
    grid-template-rows: 0.4fr 0.4fr;
    row-gap: 1rem;
    grid-template-areas: "field field field" "btn . btn2";
    align-items: center;

    margin-right: 1rem;
  }

  @media only screen and (max-width: 767px) {
    .container {
      padding: 0rem;
    }
  }
</style>
