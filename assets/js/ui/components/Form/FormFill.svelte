<script>
  import Papa from "papaparse"; //documentation: https://www.papaparse.com/docs
  import NavBar from "../NavBar.svelte";
  import FileUploadModal from "Modals/RecipientUploadFileModal.svelte";
  import { onMount } from "svelte";
  import {
    getFormSubmission,
    createFormSubmission,
    validateFormInput,
    FORM_EDITABLE_STATES,
    CSV_TEMPLATE_SAMPLE,
  } from "../../../api/Form";
  import FormElementRenderer from "./FormElementRenderer.svelte";
  import Loader from "../Loader.svelte";
  import FormTitleRenderer from "./FormTitleRenderer.svelte";
  import { getRecipient } from "../../../api/Recipient";
  import BottomBar from "../BottomBar.svelte";
  import { isToastVisible, showToast } from "../../../helpers/ToastStorage.js";
  import ToastBar from "../../atomic/ToastBar.svelte";
  import FormEntriesRenderer from "./FormEntriesRenderer.svelte";
  import FormEntriesInput from "./FormEntriesInput.svelte";
  import { csvDownloader } from "Helpers/util";
  import Instruction from "./Instruction.svelte";

  export let assignmentId;
  export let formId;
  export let recipientId;
  export let fillType;
  export let editableForm = false;
  export let avatarInitials = "LK";

  let formData = undefined;
  let showCSVModal = false;

  onMount(async () => {
    formData = await getFormSubmission(assignmentId, formId);
    if (formData.has_repeat_entries) {
      if (
        formData.repeat_entry_default_value != undefined &&
        !Array.isArray(formData.repeat_entry_default_value) &&
        Object.keys(formData.repeat_entry_default_value).length != 0
      ) {
        let new_entries = formData.entries.entries.map((entry) => {
          let acc = {};
          for (const key in entry) {
            acc[`${key}`] = entry[key];
          }
          return acc;
        });

        formData.entries = new_entries;
      }
      const _entries = formData.entries;
      if (_entries?.length) {
        const lastEntry = _entries[_entries.length - 1];
        formFillValues(lastEntry);

        entries =
          _entries.length > 1 ? _entries.slice(0, _entries.length - 1) : [];
      }
    }
    // TODO(lev): re-enable this later once debug is complete
    if (!FORM_EDITABLE_STATES.includes(formData.state.status)) {
      const hash = `#form/view/${formId}/${assignmentId}`;
      window.location.hash = hash;
    }

    window.__boilerplate_formData = formData;
    window.scroll(0, 0);
  });

  //checking requiredFields
  const isValidForm = () => {
    const formValues = getFormValues(formData.formFields);
    return validateFormInput(formData.formFields, formValues);
  };

  const validateEntries = () => {
    const { formFields } = formData;
    const invalidEntries = entries
      .map((entry, index) => {
        const isValid = validateFormInput(formFields, entry);
        if (isValid) return;
        return index + 1;
      })
      .filter((index) => index !== undefined);

    const invalidLen = invalidEntries.length;

    if (invalidLen > 0) {
      return {
        valid: false,
        message: "Fix Input error in entries: " + invalidEntries.join(),
      };
    } else {
      return {
        valid: true,
        message: "",
      };
    }
  };

  const downloadEntryTemplate = () => {
    const { formFields } = formData;
    const colrow = [];
    const samplerow = [];

    formFields.forEach((ff) => {
      colrow.push(ff.title);
      samplerow.push(CSV_TEMPLATE_SAMPLE[ff.type] || "");
    });
    const emptyRow = new Array(formFields.length).fill("");

    const csv = `${colrow.join(",")}\n${samplerow.join(",")}\n${emptyRow.join(
      ","
    )}\n`;
    csvDownloader(csv, formData.title.replaceAll(" ", "-") + "-Template.csv");
  };

  const processCSVUpload = (e) => {
    const files = e.detail.file;
    const csv = files[0];
    console.log(csv.type == "text/csv", csv);
    const conf = {
      sadworker: true,
      header: true,
      download: true,
      skipEmptyLines: true,
      transformHeader(h) {
        return h.trim();
      },
      complete(results, file) {
        const rows = results.data;
        console.log(rows);
        const { formFields } = formData;
        const titlesToId = formFields.reduce((acc, ff) => {
          acc[ff.title] = {
            id: ff.id,
            type: ff.type,
            is_multiple: ff.is_multiple,
            is_numeric: ff.is_numeric,
          };
          return acc;
        }, {});
        const allEntries = [];
        rows.forEach((entry) => {
          const formEntry = Object.entries(titlesToId).reduce(
            (acc, [title, ff]) => {
              const { id, is_multiple } = ff;
              const rawVal = entry[title];
              const val = is_multiple
                ? rawVal.replaceAll('"', "").split(",")
                : rawVal;

              acc[id] = val;
              return acc;
            },
            {}
          );
          allEntries.push(formEntry);
        });

        const currentInput = getFormValues(formData.formFields);
        if (Object.keys(currentInput).length && isValidForm()) {
          const lastEntry = allEntries[allEntries.length - 1];
          formFillValues(lastEntry);

          const _entries =
            allEntries.length > 1
              ? allEntries.slice(0, allEntries.length - 1)
              : [];
          entries = [...entries, currentInput, ..._entries];
        } else {
          entries = [...entries, ...allEntries];
        }

        showCSVModal = false;
        // const form_values = { entries: allEntries };
        // sendFormSubmission(form_values);
      },
    };

    Papa.parse(csv, conf);
  };

  // form submission stuff
  const clearFormValues = () => {
    const { formFields } = formData;
    const ff = formFields.map((field) => {
      const valueKey = field.is_multiple ? "values" : "value";
      const value = field.is_multiple ? [] : null;
      return {
        ...field,
        [valueKey]: value,
      };
    });

    formData = {
      ...formData,
      formFields: ff,
    };

    console.log(formData);
  };

  const formFillValues = (values) => {
    const newFields = formData.formFields.map((ff) => {
      const key = ff.is_multiple ? "values" : "value";
      const val = values[ff.id] ? values[ff.id] : ff.is_multiple ? [] : "";
      return {
        ...ff,
        [key]: val,
      };
    });

    formData.formFields = newFields;
  };

  const getFormValues = (formFields) => {
    return formFields.reduce((acc, field) => {
      const valueKey = field.is_multiple ? "values" : "value";
      const value = field[valueKey];
      if (value) acc[field.id] = field[valueKey];
      return acc;
    }, {});
  };

  let entries = [];
  let expandedEntries = {};

  const handleAddAnother = () => {
    if (!isValidForm()) {
      showToast(`Please fix the input errors!`, 3500, "error", "MM");
      return;
    }
    const newEntry = getFormValues(formData.formFields);
    clearFormValues();
    console.log(formData.formFields);
    entries = [...entries, newEntry];
    expandedEntries[entries.length - 1] = false;
    console.log({ entries });
  };

  let chevron_state = {};

  function handleChevronClick(index) {
    chevron_state[index] = !chevron_state[index];
  }

  const handleFormSubmit = async () => {
    const { formFields, has_repeat_entries } = formData;
    const currentInput = getFormValues(formFields);
    let form_values = {};
    if (has_repeat_entries) {
      // at this place, check all the entries are correct;
      const entriesValid = validateEntries();

      if (entriesValid.valid == false) {
        console.log(entriesValid);

        showToast(entriesValid.message, 3500, "error", "MM");
        return;
      }

      if (Object.keys(currentInput).length > 0) {
        form_values.entries = [...entries, currentInput];
      } else {
        // Nothing to add in the last entry
        form_values.entries = [...entries];
      }
    } else {
      form_values = currentInput;
    }

    console.log({ form_values });
    await sendFormSubmission(form_values);
  };

  const sendFormSubmission = async (form_values) => {
    const submissionData = {
      form_values,
      assignment_id: assignmentId,
      form_id: formData.id,
    };
    console.log(formData);
    console.log(submissionData);
    try {
      const res = await createFormSubmission(submissionData);
      console.log({ res });
      window.location = `/n/recipient#dashboard?a=${assignmentId}`;
    } catch (err) {
      console.error(err);
    }
  };
  // form submission stuff
</script>

{#await getRecipient(recipientId) then recipient}
  <NavBar
    backLink=" "
    showCompanyLogo={false}
    backLinkHref={`#`}
    navbar_spacer_classes="navbar_spacer_pb1_desktop navbar_spacer_pb1"
    windowType={fillType}
    {avatarInitials}
  />
{/await}

<main id="anchor-top" class="mainContainer">
  <div class="innerContent">
    {#if formData !== undefined}
      <FormTitleRenderer
        title={formData.title}
        description={formData.description}
      />
      {#if formData.has_repeat_entries && formData.entries?.length && !editableForm}
        <FormEntriesRenderer {formData} />
      {:else if formData.has_repeat_entries}
        <FormEntriesInput bind:formData bind:entries {expandedEntries} />
      {:else}
        {#each formData.formFields as question}
          <div class="cardSpacing">
            <FormElementRenderer {question} readOnly={!editableForm} />
          </div>
        {/each}
      {/if}
    {:else}
      <div><Loader loading={true} /></div>
    {/if}
  </div>
  <div class="desktop-only">
    <BottomBar
      IACDoc={false}
      rightButtons={[
        {
          button: "Add Another",
          color: "secondary",
          disabled: !editableForm,
          evt: "addAnother",
          ignore: !formData || !formData.has_repeat_entries,
        },
        {
          button: "Finish",
          color: "primary",
          evt: "finish",
          ignore: !editableForm,
        },
      ]}
      leftButtons={[
        {
          button: "Back",
          color: "primary",
          disabled: false,
          evt: "back",
        },
      ]}
      on:finish={() => {
        if (isValidForm()) {
          handleFormSubmit();
          const anchor = document.getElementById("anchor-top");
          window.scrollTo({
            top: anchor.offsetTop,
            behavior: "smooth",
          });
        } else {
          showToast(`Please fix the input errors!`, 3500, "error", "MM");
        }
      }}
      on:back={() => {
        window.history.go(-1);
      }}
      on:addAnother={handleAddAnother}
    />
  </div>

  <div class="mobile-only">
    <BottomBar
      IACDoc={true}
      rightButtons={[
        {
          button: "Add Another",
          color: "secondary",
          disabled: !editableForm,
          evt: "addAnother",
          ignore: !formData || !formData.has_repeat_entries,
        },
        {
          button: "Finish",
          color: "primary",
          evt: "finish",
          ignore: !editableForm,
        },
      ]}
      leftButtons={[]}
      on:finish={() => {
        if (isValidForm()) {
          handleFormSubmit();
        } else {
          showToast(`Please fix the input errors!`, 3500, "error", "MM");
        }
      }}
      on:back={() => {
        window.history.go(-1);
      }}
      on:addAnother={handleAddAnother}
    />
  </div>
</main>

{#if $isToastVisible}
  <ToastBar />
{/if}

{#if showCSVModal}
  <FileUploadModal
    requireIACwarning={false}
    multiple={false}
    on:close={() => {
      showCSVModal = false;
    }}
    on:done={processCSVUpload}
    specialText="Please upload your CSV here"
    uploadHeaderText="Upload CSV"
    requiredFileFormats=".csv"
    conditionalFileUploadAllowed=""
    checkForCustomFiletype={true}
  />
{/if}

<style>
  .mainContainer {
    display: flex;
    justify-content: center;
    padding: 70px;
  }

  .innerContent {
    width: 650px;
    font-family: "Nunito", sans-serif;
  }

  .cardSpacing {
    padding-top: 12px;
  }

  .mobile-only {
    display: none;
  }

  .mobile-only {
    display: none;
  }

  @media only screen and (max-width: 767px) {
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
    .mainContainer {
      padding: 70px 10px;
    }
    .innerContent {
      max-width: 100%;
    }
  }
</style>
