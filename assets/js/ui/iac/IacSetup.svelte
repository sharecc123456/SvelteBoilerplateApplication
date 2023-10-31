<script>
  import { iacLoadingState } from "./../../stores/iacStore.js";
  import {
    iacInitializeModel,
    iacStartLocationSelect,
    iacAddFieldClickHook,
    iacModelRemoveField,
    iacModelUpdateField,
    iacUndo,
    iacRedo,
    iacSwitchOperationMode,
    iacMapFieldsInOrder,
  } from "IAC/Model";
  import { iacSetup } from "IAC/Setup";
  import { iacRender, iacRenderLoadingScreen } from "IAC/Render";
  import {
    iacSetupFields,
    iacFieldTypes,
    getIacDocument,
    iacCommitLabels,
    iacGetLabelQuestion,
    iacSESCreateForm,
    iacGetLabelsAPI,
  } from "BoilerplateAPI/IAC";
  import {
    getTemplate,
    updateTemplate,
    updateTemplateName,
  } from "BoilerplateAPI/Template";
  import { onMount } from "svelte";
  import { featureEnabled } from "Helpers/Features";
  import NavBar from "../components/NavBar.svelte";
  import TextField from "../components/TextField.svelte";
  import Modal from "../components/Modal.svelte";
  import BottomBar from "../components/BottomBar.svelte";
  import Loader from "../components/Loader.svelte";
  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";
  import Panel from "../components/Panel.svelte";
  import Button from "../atomic/Button.svelte";
  import PdfPageNavigation from "../components/PdfPageNavigation.svelte";
  import Selector from "../components/Selector.svelte";
  import AutoComplete from "simple-svelte-autocomplete";
  import IACSetupFormEditor from "./IACSetupFormEditor.svelte";
  import Checkbox from "../components/Checkbox.svelte";

  export let documentId = 0;
  export let documentType = "rawdocument";
  export let isPrefill = false;
  export let isDirectSend = false;

  import { customizeDocument } from "BoilerplateAPI/Assignment";
  import UploadFileModal from "../modals/UploadFileModal.svelte";
  import ToastBar from "../atomic/ToastBar.svelte";
  import { isToastVisible, showToast } from "../../helpers/ToastStorage.js";
  import assignedChecklistInfo from "../../localStorageStore";
  import { searchParamObject } from "../../helpers/util";
  import FaIcon from "../atomic/FAIcon.svelte";
  import { inputBoxClicked } from "../../store.js";
  let checkIACGuideStatus = JSON.parse(
    localStorage.getItem("dontshowIACGuideDialog")
  );

  export let returnOffset = -1 * findRo();
  const requestParams = searchParamObject();
  let showEditModal = false;
  let currentDRText = "";
  let file_name;
  let canvas;
  let templateName = "[Template Name]";
  let templateDescription = "[Not set]";
  let isTemplateReviewEditType;
  let rawDocTemplateId;
  let doPrevPage = undefined;
  let doNextPage = undefined;
  let doPageForwarder = undefined;
  let resetup = undefined;
  let generateForm = undefined;
  let currentPage = 0;
  let pageCount = 1;
  let loaded = false;
  let mounted = false;
  let isIACRendered = false;
  let showIACGuideDialog = false;
  let guidePoints = [
    "Select an option from the left menu, then draw the field onto the document.",
    "To change a field, click on it, then use the left menu to change or delete.",
    "Click finish in the bottom right when you are done.",
  ];
  const MODE_SETUP = 1;
  let iacModel = null;
  let selectedModel = undefined;
  let selectedField = undefined;
  let showTableForm = false;
  $: cursor = !selectedField ? "default" : "crosshair";

  const FillOptionsArray = [
    { label: "Anyone", value: "0", order: 1 },
    { label: "Requester (pre-fill before send)", value: "1", order: 2 },
    {
      label: "Requester (during review/ after submission)",
      value: "2",
      order: 4,
    },
    { label: "Clients/ Recipients", value: "3", order: 3 },
  ];

  let fillOptions = FillOptionsArray.sort((a, b) => a["order"] - b["order"]);

  let showFinishSetupConfirmationBox = false;
  let showOnPrefillConfirmationBox = false;
  let showCustomizeModal = false;
  let types = {
    text: { fill_type: "" },
    checkbox: { fill_type: "" },
    signature: { fill_type: "" },
    table: { fill_type: "" },
  };
  let disabledField = false;
  let iacDeleteFieldButton = false;
  let iacDeselectFieldButton = false;
  let labelCache = undefined;
  let iacLabelFocus = false;
  let labelBlocked = false;
  let showLabelConfirmationDialog = false;

  function staticIACLabel(label, question = "", type = "custom") {
    return {
      value: label,
      question: question,
      type: type,
    };
  }

  async function iacGetLabels(keyword) {
    if (labelCache == undefined) {
      labelCache = await iacGetLabelsAPI();
    }

    // This is a hack for legacy IAC fields that do not have the new IACLabel model stored on the backend.
    // HACK(lev): clean this up
    if (
      selectedField &&
      selectedField.label != "" &&
      selectedField.label != null &&
      !labelCache.includes(selectedField.label)
    ) {
      const selectedModelLabel = staticIACLabel(selectedField.label);
      let newCache = [selectedModelLabel, ...labelCache];
      labelCache = newCache;
    }
    // For debug
    window.iacLabelCache = labelCache;
    const includesKeyword = labelCache.find((data) => data.value === keyword);
    if (includesKeyword) return labelCache;
    else return [staticIACLabel(keyword), ...labelCache];
  }

  function handleLabelCreate(newLabel) {
    let newLabelObj = staticIACLabel(newLabel);
    labelCache = [newLabelObj, ...labelCache];
    // For debug
    window.iacLabelCache = labelCache;
    return newLabelObj;
  }

  function deleteLabel() {
    selectedField.label = "";
    selectedField.label_value = "";
  }

  function applyLabelQuestionChange(field) {
    let label = field.label;
    let model = window.iacModel; // XXX: This is BAD - we should not use the debug stuff.

    if (label == "" || label == null) return;

    // find all fields that have this label in this document.
    for (let i = 0; i < model.fill.orderedSpecs.length; i++) {
      let orderedSpec = model.fill.orderedSpecs[i];
      let fieldId = orderedSpec[4];
      if (model.fieldState[fieldId].label == label) {
        console.log(
          `[IAC/Setup/applyLabelQuestionChange] applied label question change to field id ${fieldId}`
        );
        model.fieldState[fieldId].label_question = field.label_question;

        // XXX: bulk update API, please.
        updateField(model.fieldState[fieldId]);
      }
    }

    // TODO: now send this data to the backend to apply to all fields there, too.
  }

  /* Figure out a way to stop this from happening all the time */
  let iacDocument = iacSetup(documentType, documentId).then(async (x) => {
    return getIacDocument(x);
  });

  iacDocument.then((doc) => {
    switch (doc.document_type) {
      case "raw_document":
        rawDocTemplateId = doc.document_id;
        getTemplate(doc.document_id, "requestor").then((t) => {
          templateName = t?.name;
          templateDescription = t?.description;
          isTemplateReviewEditType = t?.allow_edits;
        });
        break;
      case "raw_document_customized":
        rawDocTemplateId = doc.template_id;
        getTemplate(doc.template_id, "requestor").then((t) => {
          templateName = t?.name;
          templateDescription = t?.description;
          isTemplateReviewEditType = t?.allow_edits;
        });
        break;
      default:
        "none";
    }
  });

  let windowInnerWidth,
    elmWidth = 0;
  onMount(() => {
    let body = document.querySelector("body");
    body.style.margin = "0px";
    windowInnerWidth = window.innerWidth;
    mounted = true;
    if (loaded) {
      init();
    }
  });

  function handleDRMsg(event) {
    currentDRText = event.detail.text;
    if (currentDRText.length >= 1) {
      iacDocument.then(async (doc) => {
        const template_id_to_fetch =
          doc.document_type == "raw_document"
            ? doc.document_id
            : doc.document_type == "raw_document_customized"
            ? doc.template_id
            : -1; // Unknown template type
        if (template_id_to_fetch > 0) {
          getTemplate(template_id_to_fetch, "requestor").then(async (t) => {
            let raw = {
              id: t?.id,
              name: currentDRText,
              description: t?.description,
              is_rspec: t?.s_rspec,
              is_info: t?.is_info,
              allow_edits: true,
            };
            let reply = await updateTemplateName(t?.id, raw.name);
            if (reply.ok) {
              getTemplate(template_id_to_fetch, "requestor").then(async (t) => {
                templateName = t?.name;
              });
              showToast(
                `Success! Template Name Updated.`,
                1000,
                "default",
                "MM"
              );
            } else {
              alert("Something went wrong while updating the template.");
            }
          });
        }
      });
    } else {
      showToast(`Please Input New Template Name.`, 2000, "error", "MM");
    }
    showEditModal = false;
  }

  function findRo() {
    var result = 2,
      tmp = [];
    if (location.hash.includes("?")) {
      location.hash
        .split("?")[1]
        .split("&")
        .forEach(function (item) {
          tmp = item.split("=");
          if (tmp[0] === "ro")
            result = parseInt(decodeURIComponent(tmp[1]), 10);
        });
    }
    console.log(`findRo = ${result}`);
    return result;
  }

  function init() {
    iacRenderLoadingScreen(canvas);
    iacModel = iacDocument.then((d) => {
      file_name = d?.file_name;
      let x = iacInitializeModel(d, MODE_SETUP);
      window.iacModel = x; // Easy access for debug purposes.

      // update field options based on doc version;
      if (d.version === 1) {
        console.log(" i ran ");
        const index = fillOptions.findIndex((opt) => opt.label === "Anyone");
        fillOptions = [
          ...fillOptions.slice(0, index),
          ...fillOptions.slice(index + 1, fillOptions.length),
        ];
      }

      iacAddFieldClickHook(x, showFieldInformation);
      x.showFieldInformation = showFieldInformation;

      doPrevPage = () => {
        if (selectedField != null && selectedField != undefined) {
          iacModelUpdateField(window.iacModel, selectedField);
          selectedField = undefined;
        }
        let previousCP = x.multipage.currentPage;
        x.multipage.currentPage =
          x.multipage.currentPage == 0
            ? x.multipage.currentPage
            : x.multipage.currentPage - 1;

        currentPage = x.multipage.currentPage;

        if (previousCP != x.multipage.currentPage)
          iacRender(x, x.render.canvas);
      };

      doNextPage = () => {
        if (selectedField != null && selectedField != undefined) {
          iacModelUpdateField(window.iacModel, selectedField);
          selectedField = undefined;
        }
        let previousCP = x.multipage.currentPage;
        x.multipage.currentPage =
          x.multipage.currentPage == x.multipage.pageCount - 1
            ? x.multipage.currentPage
            : x.multipage.currentPage + 1;

        currentPage = x.multipage.currentPage;

        if (previousCP != x.multipage.currentPage)
          iacRender(x, x.render.canvas);
      };

      doPageForwarder = (pageNumber) => {
        if (
          typeof pageNumber == "number" &&
          (pageNumber == 0 || pageNumber) &&
          pageNumber < pageCount
        ) {
          let previousCP = x.multipage.currentPage;
          x.multipage.currentPage = pageNumber;
          currentPage = x.multipage.currentPage;
          if (previousCP != x.multipage.currentPage)
            iacRender(x, x.render.canvas);
        }
      };

      // construct the JSON form data and hand it off to the rendering engine
      // XXX: send this to the backend maybe?
      generateForm = async () => {
        // create the fields first, note that `x` is the IAC Model in this context.
        let currentOrder = 0;
        let qvarkFields = iacMapFieldsInOrder(x, (f) => {
          if (
            f.label == null ||
            f.label == "" ||
            f.label_question == null ||
            f.label_question == ""
          )
            return null;

          currentOrder = currentOrder + 1;

          return {
            title: f.label_question,
            label: f.label,
            description: "",
            options: [f.label_value], // will be filled during the merge below
            required: false,
            type: f.label_question_type,
            is_multiple: f.label_question_type == "checkbox",
            is_numeric: f.label_question_type == "number",
            order_id: currentOrder - 1,
          };
        });
        let protoFields = qvarkFields.filter((x) => x != null);

        // Merge together the checkboxes
        let finalFields = [];
        let finalOrder = 0;
        let skipped = [];
        for (let i = 0; i < protoFields.length; i++) {
          let proto = protoFields[i];
          if (skipped.includes(i)) continue;

          finalOrder = finalOrder + 1;

          // These fields need no extra processing
          if (
            proto.type == "shortAnswer" ||
            proto.type == "longAnswer" ||
            proto.type == "number"
          ) {
            proto.order_id = finalOrder - 1;
            proto.options = [];
            finalFields.push(proto);
            continue;
          }

          // for all other types of fields, find everything with the same label
          let protoLabel = proto.label;
          let optionProtos = [];
          for (let j = 0; j < protoFields.length; j++) {
            if (protoFields[j].label != protoLabel) continue;

            skipped.push(j);
            optionProtos.push(protoFields[j].options[0]);
          }

          proto.options = optionProtos;
          proto.order_id = finalOrder - 1;
          finalFields.push(proto);
        }

        let form = {
          title: `Digital Form - ${templateName}`,
          has_repeat_entries: false,
          has_repeat_vertical: false,
          repeat_label: "",
          description: templateDescription,
          package_id: 0, // TODO
          formFields: finalFields,
        };

        let r = await iacSESCreateForm(rawDocTemplateId, form);
        if (r.ok) {
          let rt = await r.json();
          window.location.hash = `#checklist/${rt.package_id}?userGuide=true`;
        } else {
          alert("Failed to generate the form, see console.");
          console.log(r);
        }
      };

      resetup = () => {
        fetch(`/n/api/v1/iac/${d.id}/forcereset`).then(() => {
          window.location.reload();
        });
      };

      // render it
      iacRender(x, canvas).then(() => {
        pageCount = x.multipage.pageCount;
        currentPage = x.multipage.currentPage;
        console.log(`pageCount = ${pageCount} currentPage = ${currentPage}`);

        isIACRendered = true;
        showIACGuideDialog = true;
        $iacLoadingState = false;
      });
      x.debug.generateForm = generateForm;
      return x;
    });
  }

  function pdfJsLoaded() {
    console.log("pdfjs loaded");
    loaded = true;
    if (mounted) {
      init();
    }
  }

  function clearTypes() {
    types = {
      text: { fill_type: "" },
      checkbox: { fill_type: "" },
      signature: { fill_type: "" },
      table: { fill_type: "" },
    };
    disabledField = "";
  }

  function updateTypes(fieldType, fillType) {
    types = {
      text: { fill_type: "" },
      checkbox: { fill_type: "" },
      signature: { fill_type: "" },
      table: { fill_type: "" },
    };
    types[fieldType] = { fill_type: fillType };
  }

  async function addField(fieldType, fill_type) {
    let model = await iacModel;

    selectedField = {
      field_type: fieldType,
      fill_type: fill_type || 0,
      label_question_type:
        fieldType == 1
          ? "shortAnswer"
          : fieldType == 2
          ? "checkbox"
          : "shortAnswer",
      label: "",
    };
    console.log(
      `[IAC/setup/addField] fieldType: ${fieldType} fill_type: ${fill_type}`
    );
    console.log({ selectedField });

    model.selectedField = selectedField;
    iacDeselectFieldButton = true;

    let active_field = iacSetupFields.find(
      (x) => x.field_type == selectedField.field_type
    );

    if (iacFieldTypes.includes(selectedField.field_type)) {
      disabledField = active_field.name;
      updateTypes(active_field.name, selectedField.fill_type);
    }
    iacStartLocationSelect(model, fieldType);
  }

  function handleUpdateFillType(e, fieldType) {
    const { value } = e.target;
    if (value === "") {
      return;
    }

    addField(fieldType, value || 0);
  }

  function handleUpdateSelectField(e, type) {
    if (selectedField == undefined) {
      return;
    }
    selectedField = {
      ...selectedField,
      [type]: e.target.value,
    };
    updateField(selectedField);
  }

  async function deselectField() {
    let model = await iacModel;
    model.selectedField = undefined;
    model.setupActiveField = null;
    selectedField = undefined;
    iacSwitchOperationMode(model, 1);
    iacDeselectFieldButton = false;
    clearTypes();
  }

  async function iacUndoHistory() {
    let model = await iacModel;
    let fieldState = await iacUndo(model);
    if (fieldState) {
      if (fieldState == "removed") {
        deselectField();
      } else {
        selectedField = fieldState;
      }
    }
    iacDeselectFieldButton = true;
  }
  async function iacRedoHistory() {
    let model = await iacModel;
    let fieldState = await iacRedo(model);
    if (fieldState) {
      if (fieldState == "removed") {
        deselectField();
      } else {
        selectedField = fieldState;
      }
    }
    iacDeselectFieldButton = true;
  }

  async function showFieldInformation(model, fieldId) {
    selectedField = model.fieldState[fieldId];
    let r = await iacGetLabelQuestion(selectedField.label);
    if (r.type == "internal") {
      labelBlocked = true;
    } else {
      labelBlocked = false;
    }

    let autoCompleteSection = document.querySelector(
      "div.autocomplete input[type='text']"
    );
    autoCompleteSection.value = selectedField.label || "";

    selectedModel = model;
    iacDeselectFieldButton = true;

    let active_field = iacSetupFields.find(
      (x) => x.field_type == selectedField.field_type
    );

    disabledField = active_field?.name;
  }

  async function removeField(f) {
    await iacModelRemoveField(selectedModel, f);
    clearTypes();
    selectedField = undefined;
    iacDeselectFieldButton = true;
  }

  async function handleKeydown({ key, keyCode }) {
    if (
      selectedModel &&
      selectedField?.__field_id &&
      !iacLabelFocus &&
      !showTableForm &&
      (key == "Delete" ||
        keyCode == "46" ||
        key == "Backspace" ||
        keyCode == "8")
    ) {
      await iacModelRemoveField(selectedModel, selectedField);
      clearTypes();

      selectedField = undefined;
    } else if (
      selectedField.label != "" &&
      selectedField.label != null &&
      selectedField.field_type != 4 &&
      key == "Enter"
    ) {
      showLabelConfirmationDialog = true;
    }
  }

  function prevPage() {
    if (currentPage == 0) {
      //window.location.hash = `#template/${documentId}`;
      window.history.back(-1);
    } else {
      doPrevPage();
      pageCount = window.iacModel.multipage.pageCount;
      currentPage = window.iacModel.multipage.currentPage;
      console.log(`pageCount = ${pageCount} currentPage = ${currentPage}`);
      window.scrollTo(0, 0);
    }

    if (selectedModel) {
      selectedModel.locationSelect.pdfData = null;
    }
  }

  function updateField(f) {
    iacModelUpdateField(selectedModel, f);
  }

  async function nextPage() {
    if (currentPage != pageCount - 1) {
      doNextPage();
      pageCount = window.iacModel.multipage.pageCount;
      currentPage = window.iacModel.multipage.currentPage;
      console.log(`pageCount = ${pageCount} currentPage = ${currentPage}`);
      window.scrollTo(0, 0);
    } else {
      return finishSetup();
    }
    if (selectedModel) {
      selectedModel.locationSelect.pdfData = null;
    }
  }

  async function completeSetupProcess(doCounterSign) {
    if (doCounterSign) {
      await setupCounterSignature();
    }
    iacDocument.then((iacDoc) => {
      iacCommitLabels(iacDoc.id);
    });
  }

  async function finishSetup(doCounterSign = true) {
    await completeSetupProcess(doCounterSign);
    return redirectUserTo();
  }

  async function handleFinishSetup() {
    if (currentPage != pageCount - 1) {
      showFinishSetupConfirmationBox = true;
      return;
    } else {
      showFinishSetupConfirmationBox = false;
      return finishSetup();
    }
  }

  async function updateTemplateReviewEdits() {
    let rawDoc = await getTemplate(rawDocTemplateId, "requestor");
    let raw = {
      id: rawDoc?.id,
      name: rawDoc?.name,
      description: rawDoc?.description,
      is_rspec: rawDoc?.is_rspec,
      is_info: rawDoc?.is_info,
      allow_edits: true,
    };
    await updateTemplate(rawDoc?.id, raw);
  }

  async function containsFieldType(filltype) {
    const iacDoc = await iacSetup(documentType, documentId).then(async (x) => {
      return getIacDocument(x);
    });
    const { fields } = iacDoc;
    return fields.some((field) => field.fill_type === filltype);
  }

  const redirectTo = requestParams.redirectTo;
  const redirectUserTo = () => {
    setTimeout(() => {
      redirectTo
        ? (window.location.hash = redirectTo)
        : window.history.go(returnOffset);
    }, 1000);

    showToast(`Success! Template saved.`, 1000, "default", "MM");
  };

  async function setupCounterSignature() {
    if (!isTemplateReviewEditType) {
      const hasReviewFields = await containsFieldType(2);
      if (hasReviewFields) await updateTemplateReviewEdits();
    }
    return;
  }

  async function onPrefillTemplates() {
    showOnPrefillConfirmationBox = false;
    showToast(
      `Begin pre-filling the document for this recipient`,
      1000,
      "default",
      "MM"
    );
    await setupCounterSignature();
    window.setTimeout(() => {
      iacDocument.then((swappedDocu) => {
        const { id, contents_id, recipient_id } = swappedDocu;
        const { assigneeId, contentsId, recipientId } = $assignedChecklistInfo;
        completeSetupProcess(false);
        if (isDirectSend) {
          window.location.hash = `#iac/fill/${id}/${contentsId}/${recipientId}?directSend=true`;
        } else {
          window.location.hash = `#iac/fill/${id}/${contents_id}/${recipient_id}?assigneeId=${assigneeId}&onSetup=${true}`;
        }
      });
    }, 1000);
  }

  async function handleOnPrefill() {
    if (currentPage != pageCount - 1) {
      showOnPrefillConfirmationBox = true;
    } else {
      await onPrefillTemplates();
    }
  }

  function modifySetupCustomizationUrl(doc) {
    const newHash = `#iac/setup/rsd/${doc.customization_id}?ro=1&prefill=true`;
    window.location.hash = newHash;
    window.location.reload();
  }

  async function processCustomization(evt) {
    let detail = evt.detail;
    const iacDoc = await iacDocument;
    const docContent = { id: iacDoc.contents_id };
    const template = { id: iacDoc.template_id };

    let reply = await customizeDocument(docContent, template, detail.file);
    if (reply.ok) {
      showToast("Recreating Setup. please wait ...", 2000, "success", "MM");

      const reply = await fetch(`/n/api/v1/contents/${docContent.id}`);
      const contents = await reply.json();

      const { customizations } = contents;
      const customization = customizations[template.id];

      modifySetupCustomizationUrl(customization);
    } else {
      alert("Failed to customize this document");
    }

    showCustomizeModal = false;
  }

  $: {
    if (selectedField) {
      if (selectedField.__field_id && selectedModel) {
        iacDeleteFieldButton = true;
      }
    } else {
      iacDeleteFieldButton = false;
    }
  }

  $: pdfPageNavigationLeft = !isPrefill
    ? (windowInnerWidth - elmWidth) / 2 - 32
    : 100;

  const applyDefaultLabelSettings = (field) => {
    // No default settings for this.
    if (
      selectedField.label == "" ||
      selectedField.label == null ||
      selectedField.label == undefined
    ) {
      return;
    }

    // signature, ignore this
    if (field.field_type == 3) {
      return;
    }

    if (field.field_type == 1) {
      if (field.label_question_type == null) {
        field.label_question_type = "shortAnswer";
      }
      return;
    }
    if (field.field_type == 2) {
      if (field.label_question_type == null) {
        field.label_question_type = "checkbox";
      }
      return;
    }
  };

  const handleLabelChange = async (e) => {
    let model = window.iacModel; // XXX: This is BAD - we should not use the debug stuff.
    try {
      // Grab the question that is attached to this label.
      if (selectedField.label != "" && selectedField.label != null) {
        let done = false;
        // Check in the current IAC first
        for (let i = 0; i < model.fill.orderedSpecs.length; i++) {
          let orderedSpec = model.fill.orderedSpecs[i];
          let fieldId = orderedSpec[4];
          if (
            fieldId != selectedField.id &&
            model.fieldState[fieldId].label == selectedField.label
          ) {
            console.log(
              `[IAC/Setup/handleLabelChange] applied label question change from field id ${fieldId}`
            );
            selectedField.label_question =
              model.fieldState[fieldId].label_question;
            if (selectedField.label_question_type == null) {
              if (selectedField.field_type == 1) {
                selectedField.label_question_type = "shortAnswer";
              } else if (selectedField.field_type == 2) {
                selectedField.label_question_type = "checkbox";
              }
            }

            // XXX: bulk update API, please.
            iacModelUpdateField(window.iacModel, selectedField);
            done = true;
            break;
          }
        }

        // Else check in the wider DB
        if (!done) {
          let r = await iacGetLabelQuestion(selectedField.label);
          selectedField.label_question = r.question;
        } else if (
          selectedField.label_question == null &&
          selectedField?.label_obj?.type === "internal"
        ) {
          selectedField.label_question =
            selectedField.label_obj?.question || "";
        }
      }

      console.log(selectedField);
      iacModelUpdateField(window.iacModel, selectedField);
    } catch (err) {
      console.error(err);
      showToast("Operation failed, try again", 2000, "error", "MM");
    }
  };

  const handleLabelQuestionChange = async () => {
    try {
      console.log(selectedField);
      iacModelUpdateField(window.iacModel, selectedField);
    } catch (err) {
      console.error(err);
      showToast("Operation failed, try again", 2000, "error", "MM");
    }
  };
</script>

<svelte:head>
  <script
    src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.9.359/pdf.min.js"
    on:load={pdfJsLoaded}></script>
</svelte:head>

<svelte:window on:keydown={handleKeydown} />

{#await iacDocument}
  <p>Loading template...</p>
{:catch error}
  <p>Failed to setup in-app completion: {error}</p>
{/await}

<div class="desktop-only">
  <NavBar
    backLink="  "
    backLinkHref="javascript:window.history.back(-1)"
    on:handleMiddleTextIcon={() => {
      showEditModal = true;
    }}
    hasMiddleTextIcon={true}
    middleTextIconProps={{
      icon: "edit",
      iconSize: "medium",
    }}
    middleText={`Setup: ${templateName}`}
    middleSubText={`${templateDescription ? templateDescription : ""}`}
  />
</div>

<div class="mobile-only">
  <NavBar
    backLink="  "
    backLinkHref="javascript:window.history.back(-1)"
    middleText={`Setup: ${templateName}`}
    middleSubText={`${templateDescription}`}
    hasMiddleTextIcon={true}
    middleTextIconProps={{
      icon: "edit",
      iconSize: "medium",
    }}
    on:handleMiddleTextIcon={() => {
      showEditModal = true;
    }}
    showCompanyLogo={false}
  />
</div>

<div class="container">
  <div class="controls left">
    <div class="fieldTypes">
      <div class="heading">
        <FaIcon icon="plus" iconStyle="regular" />
        Add New
      </div>
      {#if $iacLoadingState}
        <Loader loading />
      {/if}

      <span class:visiblityHidden={$iacLoadingState}>
        <div class="columns mb-1">
          {#each iacSetupFields as { field_type, label, name, icon }}
            <div class="field-group">
              <span
                class="font-container"
                on:click={() => {
                  addField(field_type);
                }}
                class:disabled={disabledField == false
                  ? false
                  : disabledField != name || iacLabelFocus}
              >
                <FaIcon {icon} iconStyle="regular" />
              </span>
              <span
                class="select is-fullwidth"
                class:disabled={disabledField == false
                  ? false
                  : disabledField != name || iacLabelFocus}
              >
                <select
                  bind:value={types[name].fill_type}
                  on:change={(e) => handleUpdateFillType(e, field_type)}
                >
                  <option value="">{label}</option>
                  {#each fillOptions as { value, label }}
                    <option {value}>{label}</option>
                  {/each}
                </select>
              </span>
            </div>
          {/each}
        </div>

        {#if selectedField && selectedField.__field_id}
          <Panel
            collapsed={true}
            innerContentClasses="m-0"
            style={`
            padding: 0rem 1rem 1rem;
            width: auto;
            border: 1px solid #000;
            `}
          >
            <div slot="top_title" class="heading pt-1">Edit</div>
            <div class="columns mt-0">
              <div class="panel-field-group">
                <label for="">Field Type</label>
                <span class="select is-fullwidth">
                  <select
                    class="rounded-border"
                    on:change={(e) => {
                      handleUpdateSelectField(e, "field_type");
                    }}
                    bind:value={selectedField.field_type}
                  >
                    {#each iacSetupFields as { field_type, label }}
                      <option value={field_type}>{label}</option>
                    {/each}
                  </select>
                </span>
              </div>
              <div class="panel-field-group">
                <label for="">Who Fills?</label>
                <span class="select is-fullwidth">
                  <select
                    class="rounded-border"
                    on:change={(e) => {
                      handleUpdateSelectField(e, "fill_type");
                    }}
                    bind:value={selectedField.fill_type}
                  >
                    {#each fillOptions as { value, label }}
                      <option value={Number(value)}>{label}</option>
                    {/each}
                  </select>
                </span>
              </div>
              {#if selectedField.field_type == 1}
                <div class="panel-field-group">
                  <label for="">Field Options</label>
                  <Checkbox
                    text={selectedField.allow_multiline
                      ? `Allow Multiline / Text Wrap (max: ${selectedField.maxRows})`
                      : "Allow Multiline / Text Wrap"}
                    bind:isChecked={selectedField.allow_multiline}
                    on:changed={() => {
                      iacModelUpdateField(selectedModel, selectedField);
                    }}
                  />
                </div>
              {/if}
              <!-- <div class="heading pt-1">Digital Form</div> -->
              <div class="panel-field-group">
                <label for="">
                  {selectedField.field_type != 4
                    ? "Question Label (optional)"
                    : "Repeat Entry Label"}
                </label>
                <div class="label-input" style="align-items: center;">
                  <AutoComplete
                    onChange={handleLabelChange}
                    onCreate={handleLabelCreate}
                    bind:selectedItem={selectedField.label_obj}
                    matchAllKeywords={true}
                    debug={true}
                    onFocus={() => {
                      iacLabelFocus = true;
                    }}
                    onBlur={() => {
                      iacLabelFocus = false;
                    }}
                    searchFunction={iacGetLabels}
                    delay={300}
                    create={true}
                    bind:value={selectedField.label}
                    valueFieldName="value"
                    labelFieldName="value"
                    labelFunction={(label) =>
                      label.value +
                      `${
                        label.type === "internal" ? " (Contact Details)" : ""
                      }`}
                  />
                  <span
                    class="font-container"
                    style="margin-left: 1rem;"
                    on:click={deleteLabel}
                  >
                    <FaIcon
                      icon="circle-xmark"
                      iconStyle="regular"
                      iconSize="large"
                    />
                  </span>
                </div>
              </div>
              {#if selectedField.field_type != 4 && selectedField.label != undefined && selectedField.label != null && selectedField.label != ""}
                <div class="panel-field-group">
                  <label for="">Question Type</label>
                  <div class="label-input">
                    <span class="select is-fullwidth">
                      <select
                        class="rounded-border"
                        on:change={(e) => {
                          handleUpdateSelectField(e, "label_question_type");
                        }}
                        bind:value={selectedField.label_question_type}
                      >
                        {#if selectedField.type == 2}
                          <option value="radio"
                            >Multiple Choice / Single Select</option
                          >
                          <option value="checkbox">Checkboxes</option>
                        {:else}
                          <option value="shortAnswer">Short Answer</option>
                          <option value="longAnswer">Long Answer</option>
                          <option value="number">Numeric</option>
                        {/if}
                      </select>
                    </span>
                  </div>
                </div>
              {/if}
              {#if selectedField.label != "" && selectedField.label != null && selectedField.field_type != 4}
                <div class="panel-field-group">
                  <label for="">Display Question</label>
                  <div class="label-input">
                    <input
                      type="text"
                      class="input rounded-border"
                      placeholder="Question to display in generated form"
                      bind:value={selectedField.label_question}
                      readonly={labelBlocked}
                      on:focus={() => {
                        iacLabelFocus = true;
                        applyDefaultLabelSettings(selectedField);
                      }}
                      on:blur={() => {
                        iacLabelFocus = false;
                        handleLabelQuestionChange();
                      }}
                    />
                    {#if labelBlocked == false}
                      <span
                        class="font-container"
                        style="margin-left: 1rem;"
                        on:click={() => {
                          showLabelConfirmationDialog = true;
                        }}
                      >
                        <FaIcon icon="save" iconStyle="regular" />
                      </span>
                    {/if}
                  </div>
                </div>
              {/if}
              {#if selectedField.type == 2}
                <div class="panel-field-group">
                  <label for="">Answer Option / Input Value For This</label>
                  <div class="label-input">
                    <input
                      type="text"
                      class="input rounded-border"
                      placeholder="Match this form field value"
                      bind:value={selectedField.label_value}
                      on:focus={() => {
                        iacLabelFocus = true;
                      }}
                      on:blur={() => {
                        iacLabelFocus = false;
                        applyDefaultLabelSettings(selectedField);
                        handleLabelChange();
                      }}
                    />
                  </div>
                </div>
              {/if}
              {#if selectedField.label != "" && selectedField.label != null && selectedField.type == 4}
                <div class="panel-field-group">
                  <div class="label-input">
                    <div
                      style="width: 100%;"
                      on:click={() => {
                        showTableForm = true;
                      }}
                    >
                      <Button icon="table" text="Edit Table" />
                    </div>
                  </div>
                </div>
              {/if}
              <div class="panel-field-group">
                <div class="label-input">
                  <div
                    style="width: 100%;"
                    on:click={() => {
                      if (selectedField.label) {
                        applyDefaultLabelSettings(selectedField);
                        if (!labelBlocked) {
                          showLabelConfirmationDialog = true;
                        } else {
                          applyLabelQuestionChange(selectedField);
                        }
                      }
                    }}
                  >
                    <Button
                      icon="save"
                      text="Save"
                      disabled={!selectedField.label}
                    />
                  </div>
                </div>
              </div>
            </div>
          </Panel>
        {/if}
        <hr />
        <div class="action-container">
          <span
            class="action-field"
            id="iac_undo_button"
            on:click={() => {
              iacUndoHistory();
            }}
          >
            <span><FaIcon icon="undo" iconStyle="regular" /></span>
            <span>Undo</span>
          </span>
          <span
            on:click={() => {
              removeField(selectedField);
            }}
            class="action-field"
            class:activeActionField={iacDeleteFieldButton}
          >
            <span><FaIcon icon="trash" iconStyle="regular" /></span>
            <span>Delete</span>
          </span>
        </div>
        <div class="action-container">
          <span
            class="action-field"
            id="iac_redo_button"
            on:click={() => {
              iacRedoHistory();
            }}
          >
            <span><FaIcon icon="redo" iconStyle="regular" /></span>
            <span>Redo</span>
          </span>
          <span
            class="action-field"
            on:click={deselectField}
            class:activeActionField={iacDeselectFieldButton}
          >
            <span />
            <span>Deselect</span>
          </span>
        </div>

        {#if featureEnabled("d2d_form_generation")}
          <span
            class="field"
            on:click={() => {
              generateForm();
            }}
          >
            <Button
              text="(Beta) Generate Form"
              color="primary"
              icon="rectangle-list"
              iconStyle="regular"
            />
          </span>
        {/if}

        {#if featureEnabled("internal_development")}
          <span
            class="field"
            on:click={() => {
              resetup();
            }}
          >
            <Button
              text="(INTERNAL) Force re-acro"
              color="primary"
              icon="signature"
              iconStyle="regular"
            />
          </span>
          <span
            class="field"
            on:click={() => {
              window.iacModel.debug.toggleFieldIds(window.iacModel);
            }}
          >
            <Button
              text="(INTERNAL) Toggle ID"
              color="primary"
              icon="signature"
              iconStyle="regular"
            />
          </span>
        {/if}
      </span>
    </div>
  </div>
  <div class="canvas">
    <canvas
      style="width: 100%; cursor:{cursor};"
      bind:this={canvas}
      id="bp-iac-canvas"
    />
  </div>
</div>

<span
  class="pdf-page-navigator-wrapper"
  style="left: {pdfPageNavigationLeft}px"
>
  <PdfPageNavigation
    currentPage={currentPage + 1}
    totalPage={pageCount}
    on:next={() => doNextPage()}
    on:prev={() => doPrevPage()}
    on:pageForwarder={({ detail: { pageNumber } }) => {
      doPageForwarder(pageNumber);
    }}
    bind:elmWidth
  />
</span>

{#if showTableForm}
  <Modal
    maxWidth="48rem"
    on:close={() => {
      showTableForm = false;
    }}
    showMinimizeModal={true}
    minimizeModalText={"Table Editor: " + selectedField.label}
  >
    <IACSetupFormEditor bind:iacField={selectedField} bind:showTableForm />
  </Modal>
{/if}

{#if showEditModal}
  <ConfirmationDialog
    title={"Edit Information"}
    question={`Please Input New Template Name.`}
    responseBoxEnable="true"
    responseBoxDemoText={templateName}
    responseBoxText={templateName}
    yesText="Save"
    noText="Cancel"
    yesColor="primary"
    noColor="gray"
    on:message={handleDRMsg}
    on:yes={""}
    on:close={() => {
      showEditModal = false;
    }}
  />
{/if}

{#if showFinishSetupConfirmationBox}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`You haven't made it to the last page of the document yet, are you sure you want to finish?`}
    yesText="Yes, I'm done"
    noText="No, go back to setup"
    yesColor="primary"
    noColor="white"
    on:yes={async () => {
      return finishSetup();
    }}
    on:close={() => {
      showFinishSetupConfirmationBox = false;
    }}
  />
{/if}

{#if showLabelConfirmationDialog}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`Warning: Changing this question will apply it to ALL questions across ALL your templates.`}
    yesText="Yes, Save"
    noText="No, Cancel"
    yesColor="primary"
    noColor="white"
    on:yes={async () => {
      applyLabelQuestionChange(selectedField);
      showLabelConfirmationDialog = false;
    }}
    on:close={() => {
      showLabelConfirmationDialog = false;
    }}
  />
{/if}

{#if showOnPrefillConfirmationBox}
  <ConfirmationDialog
    title={"Confirmation"}
    question={`You haven't made it to the last page of the document yet, are you sure you want to go to prefill document?`}
    yesText="Yes, I'm done"
    noText="No, go back to setup"
    yesColor="primary"
    noColor="white"
    on:yes={onPrefillTemplates}
    on:close={() => {
      showOnPrefillConfirmationBox = false;
    }}
  />
{/if}

{#if showIACGuideDialog}
  {#if checkIACGuideStatus !== true}
    <ConfirmationDialog
      title={"To setup online form filling:"}
      hideText={"Close"}
      hideColor={"white"}
      checkBoxEnable={"enable"}
      checkBoxText={"Don't ask me this again"}
      guidePointsEnable={"enable"}
      {guidePoints}
      on:yes={""}
      on:close={(event) => {
        if (event?.detail) {
          localStorage.setItem("dontshowIACGuideDialog", event?.detail);
        } else {
          localStorage.setItem("dontshowIACGuideDialog", false);
        }
        showIACGuideDialog = false;
      }}
      on:hide={(event) => {
        if (event?.detail) {
          localStorage.setItem("dontshowIACGuideDialog", event?.detail);
        } else {
          localStorage.setItem("dontshowIACGuideDialog", false);
        }
        showIACGuideDialog = false;
      }}
    />
  {/if}
{/if}

{#if showCustomizeModal}
  <UploadFileModal
    requireIACwarning={true}
    multiple={false}
    specialText={`Customize ${templateName}`}
    on:done={processCustomization}
    on:close={() => (showCustomizeModal = false)}
  />
{/if}

{#if $isToastVisible}
  <ToastBar />
{/if}

<BottomBar
  leftButtons={[
    {
      button: currentPage == 0 ? "Back" : "<< Previous Page",
      color: "white",
      disabled: false,
      ignore: !isIACRendered,
      evt: "prev",
    },
  ]}
  rightButtons={[
    {
      button: "Next Page >>",
      color: "white",
      disabled: currentPage == pageCount - 1,
      ignore: !isIACRendered,
      evt: "next",
    },
    {
      button: "Finish setup/ proceed to pre-fill",
      color: "secondary",
      disabled: false,
      ignore: !isPrefill || !isIACRendered,
      evt: "prefill",
    },
    {
      button: "Finish",
      color: currentPage == pageCount - 1 ? "white" : "primary",
      disabled: false,
      ignore: isPrefill || !isIACRendered,
      evt: "finish",
    },
  ]}
  centerButtons={[
    {
      button: "Replace",
      evt: "replace",
      color: "white",
      icon: "exchange",
      ignore: !isPrefill || !isIACRendered,
      leftMargin: false,
    },
  ]}
  on:prev={prevPage}
  on:next={nextPage}
  on:finish={handleFinishSetup}
  on:prefill={handleOnPrefill}
  on:download={() => {
    window.location = `/n/api/v1/dproxy/${file_name}?dispName=${templateName}`;
  }}
  on:replace={() => (showCustomizeModal = true)}
/>

<style>
  .label-input {
    display: flex;
    width: 100%;
  }

  .input {
    width: 100%;
    font-size: 1rem;
    padding: 0.5rem;
    box-sizing: border-box;
  }

  .columns {
    margin-top: 1rem;
    display: flex;
    flex-direction: column;
    gap: 0.8rem;
  }
  .mb-1 {
    margin-bottom: 1rem;
  }
  .mt-0 {
    margin-top: 0;
  }
  .visiblityHidden {
    visibility: hidden;
  }
  hr {
    background-color: #d9dcdf;
    border: 1px solid transparent;
    margin: 1rem 0 1.5rem;
  }
  .font-container {
    padding-bottom: calc(0.5em - 1px);
    padding-left: calc(0.75em - 1px);
    padding-right: calc(0.75em - 1px);
    padding-top: calc(0.5em - 1px);
    background-color: transparent;
    cursor: pointer;
    width: 30px;
    text-align: center;
  }

  .action-container {
    display: flex;
    justify-content: space-around;
    margin-bottom: 0.5rem;
    color: #606972;
  }
  .disabled {
    background-color: #b3c1d0;
    border-color: #b3c1d0;
    color: #fff;
  }
  .field-group {
    display: flex;
  }
  .panel-field-group {
    display: flex;
    flex-direction: column;
    justify-content: flex-start;
    align-items: flex-start;
  }
  .panel-field-group label {
    margin-bottom: 0.5rem;
    color: #76808b;
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
  .rounded-border {
    border-radius: 0.375rem !important;
  }
  .action-field {
    color: #b3c1d0;
    cursor: pointer;
  }
  .activeActionField {
    color: black;
  }
  .field-group:hover .font-container {
    background-color: #363636;
    color: #fff;
  }
  .field-group:hover .select select {
    color: #363636;
  }
  .field-group:hover .select::after {
    border-color: #000000;
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
  .select.disabled::after {
    border-color: #b3c1d0;
  }
  .select.disabled select {
    color: #b3c1d0;
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
    border-radius: 0 0.375em 0.375em 0;
    color: #363636;
  }
  .select select:not([multiple]) {
    padding-right: 2.5em;
  }
  .select select:hover {
    border-color: #b5b5b5;
  }

  .field {
    display: flex;
    flex-flow: row nowrap;
    align-items: center;
    justify-content: center;

    font-style: normal;
    font-weight: normal;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.25px;
    color: #606972;

    padding-top: 2rem;
  }

  .heading {
    font-style: normal;
    font-weight: bolder;
    font-size: 16px;
    line-height: 34px;
    color: #606972;
    text-align: center;
  }
  .pt-1 {
    padding-top: 0.5rem;
  }

  .fieldTypes {
    padding: 0.5rem;
    text-align: center;
  }

  .container {
    padding: 2rem;
    display: flex;
    flex-flow: row nowrap;
  }

  .controls {
    border-top: 0.5px solid #b3c1d0;
    margin-top: 1rem;
    height: 100%;
    background: #ffffff;
    box-shadow: 0px 4px 15px 2px rgba(23, 31, 70, 0.12);
    position: sticky;
    overflow-y: scroll;
    bottom: 10rem;
    top: 5rem;
  }

  .left {
    min-width: 350px;
    height: calc(100vh - 170px);
  }

  .canvas {
    width: 100%;
    margin-top: 1rem;
    margin-left: 1rem;
    border: 1px solid black;
  }
  .mobile-only {
    display: none;
  }

  .pdf-page-navigator-wrapper {
    position: fixed;
    z-index: 100;
    bottom: 1.2rem;
  }
  @media only screen and (max-width: 767px) {
    .desktop-only {
      display: none;
    }
    .mobile-only {
      display: block;
    }
  }
</style>
