/* 
  The Store of the Form Feature.
  forms stores the saved forms, question is the current form that user is editing.
  First element is always the title. Every form needs a title and a description.
  Structure of the store:
    questions: is a form with title and description with formFields(these are the question elements)
    forms: storage of the forms that the user created
  When user wants to add a new question, we are creating a blank object.
  Object MUST look like this:
   question: {
    title: "Formtitle",
    description: "formDescription",
    formFields: [{
            title: "",
            label: "",
            description: "",
            options: [""],
            required: false,
            is_multiple: false,
            is_numeric: false,
            type: "shortAnswer", <- default
    }]
   }
   There are 4 types of the form application, it will be extended in the future.
   Types are: 
    type: "shortAnswer"
    type: "longAnswer"
    type: "date"
    type: "checkbox"
    type: "radio"
    type: "decision"
    type: "number"
    Owner: MJ
*/
import { writable } from "svelte/store";
import { showToast } from "../helpers/ToastStorage.js";
import { isValidFormFields } from "../helpers/util.js";

function createStore() {
  const { subscribe, set, update } = writable({
    questions: {},
    forms: [],
  });

  return {
    subscribe,
    reset: () =>
      set({
        questions: {},
        forms: [],
      }),
    resetQuestions: () => {
      update((state) => {
        return (state = {
          ...state,
          questions: {},
        });
      });
    },
    addDetails: (
      title,
      description,
      has_repeat_entries = false,
      has_repeat_vertical = false,
      repeat_label
    ) => {
      update((state) => {
        state.questions = {
          ...state.questions,
          title: title,
          description: description,
          formFields: [],
          has_repeat_entries,
          has_repeat_vertical,
          repeat_label,
        };

        return state;
      });
    },
    //add question
    addQuestion: (index) => {
      update((state) => {
        if (!isValidFormFields(state.questions.formFields, showToast)) {
          return state;
        }
        const question = {
          title: "",
          label: "",
          description: "",
          options: [""],
          required: false,
          is_multiple: false,
          is_numeric: false,
          order_id: state.questions.formFields.length,
          type: "shortAnswer",
        };
        state.questions.formFields.splice(index + 1, 0, question); // push question into next index
        return state;
      });
    },
    //add item
    addInstruction: (index) => {
      update((state) => {
        if (!isValidFormFields(state.questions.formFields, showToast)) {
          return state;
        }
        const instruction = {
          title: "-",
          label: "",
          description: "",
          options: [""],
          required: false,
          is_multiple: false,
          is_numeric: false,
          order_id: state.questions.formFields.length,
          type: "instruction",
        };
        state.questions.formFields.splice(index + 1, 0, instruction); // push instruction into next index
        return state;
      });
    },
    //remove question
    handleRemove: (index) =>
      update((state) => {
        state.questions.formFields = [
          ...state.questions.formFields.slice(0, index),
          ...state.questions.formFields.slice(
            index + 1,
            state.questions.formFields.length
          ),
        ];

        return state;
      }),
    //handling type change(if check if value is multiple or number)
    handleChangeFormType: (type, formIndex) => {
      update((state) => {
        switch (type) {
          case "checkbox":
            state.questions.formFields[formIndex].is_multiple = true;
            state.questions.formFields[formIndex].is_numeric = false;
            state.questions.formFields[formIndex].options = [];
            break;
          case "number":
            state.questions.formFields[formIndex].is_multiple = false;
            state.questions.formFields[formIndex].is_numeric = true;
            state.questions.formFields[formIndex].options = [];
            break;
          case "decision":
            state.questions.formFields[formIndex].is_multiple = false;
            state.questions.formFields[formIndex].is_numeric = false;
            state.questions.formFields[formIndex].options = ["Yes", "No"];
            break;
          default:
            state.questions.formFields[formIndex].is_multiple = false;
            state.questions.formFields[formIndex].is_numeric = false;
            state.questions.formFields[formIndex].options = [];
        }

        return state;
      });
    },
    //add option
    addOption: (i) => {
      update((state) => {
        state.questions.formFields[i].options = [
          ...state.questions.formFields[i].options,
          "",
        ];
        return state;
      });
    },
    moveUp: (idx) => {
      update((state) => {
        if (idx == 0) {
          console.log("Can't move upwards if this is already the first");
          return state;
        }
        [state.questions.formFields[idx - 1], state.questions.formFields[idx]] =
          [
            state.questions.formFields[idx],
            state.questions.formFields[idx - 1],
          ];
        return state;
      });
    },
    moveDown: (idx) => {
      update((state) => {
        if (idx == state.questions.formFields.length - 1) {
          console.log("Can't move downwards if there are no more questions");
          return state;
        }
        [state.questions.formFields[idx], state.questions.formFields[idx + 1]] =
          [
            state.questions.formFields[idx + 1],
            state.questions.formFields[idx],
          ];
        return state;
      });
    },
    //remove option
    removeOption: (i, oIndex) => {
      update((state) => {
        state.questions.formFields[i].options = [
          ...state.questions.formFields[i].options.slice(0, oIndex),
          ...state.questions.formFields[i].options.slice(
            oIndex + 1,
            state.questions.formFields[i].options.length
          ),
        ];

        return state;
      });
    },
    //add form to the list
    addForm: () => {
      update((state) => {
        // save the ordering
        for (var i = 0; i < state.questions.formFields.length; i++) {
          state.questions.formFields[i].order_id = i;
        }

        let forms = [...state.forms, state.questions];

        return (state = {
          ...state,
          forms: forms,
        });
      });
    },
    removeForm: (index) => {
      update((state) => {
        let forms = [
          ...state.forms.slice(0, index),
          ...state.forms.slice(index + 1, state.forms.length),
        ];

        return (state = {
          ...state,
          forms: forms,
        });
      });
    },
    selectForm: (selectedIndex) => {
      update((state) => {
        let selectedForm = state.forms.filter((form, index) => {
          return index === selectedIndex;
        });

        //filter returns an array with ONLY one selected element
        if (selectedForm.length == 1) {
          state.questions = selectedForm[0];

          return state;
        } else {
          alert(
            `Multiple selection found, it is critical, something is working very bad in selectedForm method. SelectedForm: ${selectedForm}`
          );
          console.error(
            `Multiple selection found, it is critical, something is working very bad in selectedForm method. ${selectedForm}`
          );
          return state;
        }
      });
    },
    handleUpdateForm: (selectedIndex) => {
      update((state) => {
        // save the ordering
        for (var i = 0; i < state.questions.formFields.length; i++) {
          state.questions.formFields[i].order_id = i;
        }

        state.forms[selectedIndex] = state.questions;

        state.questions = [];

        return state;
      });
    },
    //loading from backend for edit
    loadForms: (forms) => {
      update((state) => {
        if (forms.length === 0) {
          return state;
        }

        state.forms = forms;

        return state;
      });
    },
    clearEmptyOptions: () => {
      update((state) => {
        state.questions.formFields.forEach((formField) => {
          formField.options =
            formField.options &&
            formField.options.filter((e) => {
              return e != "";
            });
        });
        return state;
      });
    },

    addExistingForm: (formPayload, loadAsSelectedQuestion = false) => {
      const { title, questions } = formPayload;

      update((state) => {
        let transformedQuestions = [];
        let order_id = 0;

        transformedQuestions = questions.map((question) => {
          return {
            title: question.title,
            label: question.label,
            description: "",
            options: [""],
            required: false,
            is_multiple: false,
            is_numeric: question.type === "number" ? true : false,
            type: question.type,
            order_id: order_id++,
          };
        });

        let transformedForm = {
          title: title,
          description: "",
          formFields: transformedQuestions,
          has_repeat_entries: false,
          has_repeat_vertical: false,
          repeat_label: "",
        };

        if (loadAsSelectedQuestion === false)
          state.forms = [...state.forms, transformedForm];
        else state.questions = transformedForm;
        console.log(state);
        return state;
      });
    },
  };
}

export const formStore = createStore();
