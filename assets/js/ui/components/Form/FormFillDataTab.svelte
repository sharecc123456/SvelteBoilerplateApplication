<script>
  import { onMount } from "svelte";
  import FormElementRenderer from "./FormElementRenderer.svelte";
  import FormEntriesInput from "./FormEntriesInput.svelte";
  import Button from "../../atomic/Button.svelte";
  import FormTitleRenderer from "./FormTitleRenderer.svelte";

  export let editableForm = true;
  export let formData = undefined;
  export let forms = undefined;
  export let formIndex = 0;
  export let recipient = undefined;
  let entries = [];
  let expandedEntries = {};

  onMount(async () => {
    window.__boilerplate_formData = formData;

    if (formData.has_repeat_entries) {
      if (formData.has_repeat_entries) {
        const _entries = formData.entries;
        if (_entries?.length) {
          const lastEntry = _entries[_entries.length - 1];
          formFillValues(lastEntry);

          entries =
            _entries.length > 1 ? _entries.slice(0, _entries.length - 1) : [];
        }
      }
    }
  });

  const nextForm = () => {
    if (formIndex < forms.length - 1) {
      let currentInput = getFormValues(formData.formFields);
      if (Object.keys(currentInput).length > 0) {
        entries = [...entries, currentInput];
        formData.entries = entries;
      } else {
        // Nothing to add in the last entry
      }
      forms[formIndex].entries = entries;
      console.log({ msg: "nextForm/oldEntries", entries: formData.entries });

      formData = forms[++formIndex];
      // New Form
      entries = [];
      if (formData.has_repeat_entries) {
        const _entries = formData.entries;
        if (_entries?.length) {
          const lastEntry = _entries[_entries.length - 1];
          formFillValues(lastEntry);

          entries =
            _entries.length > 1 ? _entries.slice(0, _entries.length - 1) : [];
        }
      }
      console.log({ msg: "nextForm/newEntries", entries: entries });
      expandedEntries = [];
    }
  };

  const prevForm = () => {
    if (formIndex > 0) {
      let currentInput = getFormValues(formData.formFields);
      if (Object.keys(currentInput).length > 0) {
        entries = [...entries, currentInput];
        formData.entries = entries;
      } else {
        // Nothing to add in the last entry
      }
      forms[formIndex].entries = entries;
      console.log({ msg: "nextForm/oldEntries", entries: formData.entries });
      formData = forms[--formIndex];

      // new form
      entries = [];
      if (formData.has_repeat_entries) {
        const _entries = formData.entries;
        if (_entries?.length) {
          const lastEntry = _entries[_entries.length - 1];
          formFillValues(lastEntry);

          entries =
            _entries.length > 1 ? _entries.slice(0, _entries.length - 1) : [];
        }
      }
      console.log({ msg: "prevForm/newEntries", entries: entries });
      expandedEntries = [];
    }
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

  const handleAddAnother = () => {
    //if (!isValidForm()) {
    //showToast(`Please fix the input errors!`, 3500, "error", "MM");
    //return;
    //}
    const newEntry = getFormValues(formData.formFields);
    //console.log(formData.formFields);
    entries = [...entries, newEntry];
    expandedEntries[entries.length - 1] = false;
    //console.log({ entries });

    let thisEntry = formData.formFields.map((field) => {
      let val = undefined;
      if (field.is_multiple) {
        val = field.values;
      } else {
        val = field.value;
      }
      return { field_name: field.title, value: val };
    });
    console.log({ thisEntry });
    clearFormValues();
  };

  const getFormValues = (formFields) => {
    return formFields.reduce((acc, field) => {
      const valueKey = field.is_multiple ? "values" : "value";
      const value = field[valueKey];
      if (value) acc[field.id] = field[valueKey];
      return acc;
    }, {});
  };

  const sendAllFormSubmission = async () => {
    // send the basic form
    if (forms[0].has_repeat_entries == false) {
      await sendFormSubmission(forms[0]);
    }

    if (forms[0].has_repeat_entries || formIndex > 0) {
      // add this entry
      let currentInput = getFormValues(formData.formFields);
      if (Object.keys(currentInput).length > 0) {
        entries = [...entries, currentInput];
        formData.entries = entries;
      } else {
        // Nothing to add in the last entry
      }

      forms[formIndex].entries = entries;
    }

    if (forms[0].has_repeat_entries || forms.length > 1) {
      // there are repeat entry forms
      let startI = forms[0].has_repeat_entries ? 0 : 1;
      for (let i = startI; i < forms.length; i++) {
        await sendRepeatEntryForm(forms[i]);
      }
    }

    // close the window
    window.location.hash = `#recipient/${recipient.id}/details/data`;
    window.location.reload();
  };

  const sendRepeatEntryForm = async (form) => {
    let repeatSubmissionData = {
      form_id: form.id,
      repeat_label: form.repeat_label,
      form_title: form.title,
      data: form.entries.map((entry) => {
        let final = [];
        for (const fieldId in entry) {
          let field = form.formFields.find((field) => field.id == fieldId);
          if (field == undefined) {
            alert(`Field not found for field id fieldId`);
            break;
          }
          final.push({
            name: field.title,
            order_id: field.order_id,
            label: field.label,
            fieldId: fieldId,
            value: entry[fieldId],
          });
        }
        return final;
      }),
    };
    console.log({
      msg: "sendRepeatEntryForm/form",
      entries: form.entries,
      form,
      repeatSubmissionData,
    });

    return await fetch(`/n/api/v1/recipient/${recipient.id}/data/form`, {
      method: "PUT",
      headers: {
        "content-type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify({ repeat_data: repeatSubmissionData }),
    });
  };

  const sendFormSubmission = async (form) => {
    // submit the data to the backend so that it's added to the data tab for
    // the recipient
    const submissionData = form.formFields.map((e) => {
      let label = e.label;
      let value = undefined;

      console.log({ e });
      if (e.is_multiple) {
        value = e.values;
      } else {
        if (e.type == "radio") {
          value = [e.value];
        } else {
          value = e.value;
        }
      }

      return { label: label, value: value };
    });
    console.log({ submissionData });
    return await fetch(`/n/api/v1/recipient/${recipient.id}/data/form`, {
      method: "PUT",
      headers: {
        "content-type": "application/json",
      },
      credentials: "include",
      body: JSON.stringify({ data: submissionData }),
    });
  };
</script>

<main id="anchor-top" class="mainContainer">
  <div class="innerContent">
    {#if formData !== undefined}
      <FormTitleRenderer
        title={formData.title}
        description={formData.description}
      />
      {#if formData.has_repeat_entries}
        <FormEntriesInput bind:formData bind:entries {expandedEntries} />
      {:else}
        {#each formData.formFields as question}
          <div class="cardSpacing">
            <FormElementRenderer
              entryInput={false}
              {question}
              readOnly={!editableForm}
            />
          </div>
        {/each}
      {/if}
      <div class="button-container">
        {#if formData.has_repeat_entries}
          <div class="grid-area: add;" on:click={handleAddAnother}>
            <Button text={"Add Another"} />
          </div>
        {/if}
        <div style="grid-area: prev;" on:click={prevForm}>
          <Button disabled={formIndex <= 0} text={"Previous Form"} />
        </div>
        <div
          style="grid-area: submit;"
          on:click={(evt) => {
            if (formIndex == forms.length - 1) {
              sendAllFormSubmission(evt);
            }
          }}
        >
          <Button disabled={formIndex != forms.length - 1} text={"Save"} />
        </div>
        <div style="grid-area: next;" on:click={nextForm}>
          <Button disabled={formIndex >= forms.length - 1} text={"Next Form"} />
        </div>
      </div>
    {:else}
      <div>
        Something broke. Sorry! Please contact Support: support@boilerplate.co
      </div>
    {/if}
  </div>
</main>

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

  .button-container {
    display: grid;
    width: 100%;
    margin-top: 1rem;
    align-items: center;
    column-gap: 1rem;
    row-gap: 1rem;
    grid-template-rows: auto;
    grid-template-areas: "add add add" "prev submit next";
    justify-items: center;
  }

  @media only screen and (max-width: 767px) {
    .mainContainer {
      padding: 70px 10px;
    }
    .innerContent {
      max-width: 100%;
    }
  }
</style>
