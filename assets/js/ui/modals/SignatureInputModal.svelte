<script>
  import { createEventDispatcher, onDestroy, onMount } from "svelte";
  import Button from "../atomic/Button.svelte";
  import LoadingButton from "../atomic/LoadingButton.svelte";
  import Checkbox from "../components/Checkbox.svelte";
  import SignaturePad from "signature_pad";
  import TextSignature from "text-signature";
  import Switch from "../components/Switch.svelte";
  import EditTextSignatureModal from "./EditTextSignatureModal.svelte";
  import { getTextSignature, addTextSignature } from "../../api/User";
  import { isMobile } from "../../helpers/util";

  const dispatch = createEventDispatcher();
  const close = () => {
    // lol wtf
    let container = document.getElementById("boilerplate-error-container");
    container.innerHTML = "";
    dispatch("close");
  };

  let modal;
  let canvas;
  let backgroundCanvas;
  let signaturePad;
  let showEmptySignature = false;
  let saveSignature = false;
  export let iacModel;
  export let fieldId;
  let textSignature = "";
  let useTypedName = false;
  let imageData;
  let showEditTextSignatureModal = false;
  let applySignatureDisabled = false;
  const handle_keydown = (e) => {
    if (e.key == "Escape") {
      close();
      return;
    }

    if (e.key === "Tab") {
      // trap focus
      const nodes = modal.querySelectorAll("*");
      const tabbable = Array.from(nodes).filter((n) => n.tabIndex >= 0);

      let index = tabbable.indexOf(document.activeElement);
      if (index === -1 && e.shiftKey) index = 0;

      index += tabbable.length + (e.shiftKey ? -1 : 1);
      index %= tabbable.length;

      tabbable[index].focus();
      e.preventDefault();
    }
  };

  const previously_focused =
    typeof document !== "undefined" && document.activeElement;

  if (previously_focused) {
    onDestroy(() => {
      previously_focused.focus();
    });
  }

  onMount(() => {
    let scrWidth = screen.width;
    let canWidth = scrWidth > 767 ? 600 : scrWidth - 40;
    let canHeight = scrWidth > 767 ? 150 : 200;
    canvas.width = canWidth;
    canvas.height = canHeight;
    backgroundCanvas.width = canWidth;
    backgroundCanvas.height = canHeight;
    var ctx = backgroundCanvas.getContext("2d");
    ctx.fillStyle = "rgba(107, 208, 255, 0.1)";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    signaturePad = new SignaturePad(canvas, {
      backgroundColor: "rgba(255, 255, 255, 0)",
      penColor: "rgba(0, 0, 0, 100)",
    });

    if (iacModel.esign.has_saved_sig) {
      signaturePad.fromDataURL(iacModel.esign.saved_sig, {
        width: 600,
        height: 150,
      });
    }

    getTextSignature().then((data) => {
      if (data.length) {
        textSignature = data;
      } else {
        textSignature = "";
      }

      if (textSignature.length) {
        convertTextToSignature();
      }
    });
  });

  function markActive(el) {
    el.focus();
  }

  function undo() {
    let data = signaturePad.toData();

    if (data) {
      data.pop();
      signaturePad.fromData(data);
    }
  }

  function clear() {
    signaturePad.clear();
  }

  function applySignature() {
    applySignatureDisabled = true;
    if (useTypedName) {
      signaturePad.fromDataURL(imageData, {
        width: 600,
        height: 150,
      });
      if (signaturePad.isEmpty()) {
        showEmptySignature = true;
        return;
      }

      let signature_data = {
        fieldId: fieldId,
        iacModel: iacModel,
        audit_start: Date.now(),
        audit_end: Date.now(),
        save_signature: saveSignature,
        data: signaturePad.toDataURL(),
      };

      dispatch("signatureApplied", signature_data);
      return;
    }

    if (signaturePad.isEmpty()) {
      showEmptySignature = true;
    } else {
      let signature_data = {
        fieldId: fieldId,
        iacModel: iacModel,
        audit_start: Date.now(),
        audit_end: Date.now(),
        save_signature: saveSignature,
        data: signaturePad.toDataURL(),
      };

      dispatch("signatureApplied", signature_data);
    }
    setTimeout(() => {
      applySignatureDisabled = false;
    }, 1000);
  }

  const loadTextSignature = () => {
    if (!signaturePad.isEmpty()) {
      clear();
    }
    var ctx = canvas.getContext("2d");
    //get base64 image source data and draw it on canvas
    var image = new Image();
    image.onload = function () {
      ctx.drawImage(image, 0, 0);
    };
    image.src = imageData;
  };

  const convertTextToSignature = () => {
    let fontSize = isMobile() ? "30px" : "40px";

    let paddingX =
      textSignature.length < 15
        ? canvas.width >= 600
          ? 170
          : 70
        : canvas.width >= 600
        ? 120
        : 20;
    var optionsParameter = {
      width: 600,
      height: 150,
      paddingX,
      paddingY: 100,
      canvasTargetDom: ".js-canvasTargetDom",
      font: [fontSize, "'Sacramento'"],
      color: "rgba(0, 0, 0, 100)",
      textString: textSignature,
      customFont: {
        name: "'Sacramento'",
        url: "//fonts.googleapis.com/css2?family=Sacramento",
      },
    };

    const signatureFactory = new TextSignature(optionsParameter);

    signatureFactory.generateImage(optionsParameter);
    imageData = signatureFactory.getImageData();
  };

  const switchAction = (checked) => {
    useTypedName = checked;

    if (useTypedName) {
      convertTextToSignature();
      loadTextSignature();
      return;
    }

    clear();
  };

  const handleEditTextSignature = (event) => {
    //read typed signature from input
    textSignature = event.detail.value;
    //converting the type signature to written signature
    convertTextToSignature();
    //update the backend
    addTextSignature(textSignature);

    if (useTypedName) {
      clear();
      loadTextSignature();
    }
  };
</script>

<svelte:window on:keydown={handle_keydown} />

<div class="modal-background" on:click={close} />

<div class="modal" role="dialog" aria-modal="true" bind:this={modal}>
  <div class="modal-content">
    <span class="modal-header">Signature Input</span>

    <span class="modal-message">
      <b>Desktop:</b> Click and hold mouse to draw your signature, or choose use
      printed name.
      <b>Mobile/tablet:</b> Use your finger to sign.
    </span>

    {#if showEmptySignature}
      <span class="modal-message error">
        Oops! Cannot apply an empty signature, please draw your signature or
        your typed name in the box below and try again.
      </span>
    {/if}

    <div class="container">
      <div>
        <span class="textTitle">Your full name: </span>
        <span>{textSignature}</span>
        <span
          class="link"
          on:click={() => {
            showEditTextSignatureModal = true;
          }}>edit</span
        >
      </div>
      <div>
        {#if textSignature.length}
          <Switch action={switchAction} text="Use typed name" />
        {/if}
      </div>
    </div>

    <div class="sig-box">
      <div
        class="signature-pad"
        style={useTypedName ? "z-index: -1;" : "z-index: 0;"}
      >
        <canvas
          bind:this={backgroundCanvas}
          class="bp-signature-pad"
          style="z-index: 0; position: absolute; pointer-events: none;"
        />
        <canvas
          bind:this={canvas}
          style="z-index: 100;"
          class="bp-signature-pad js-canvasTargetDom"
        />
      </div>
    </div>
    <div class="sm:hide save-box">
      <Checkbox
        text={"Save Signature for Future Use"}
        bind:isChecked={saveSignature}
      />
    </div>
    <div class="modal-buttons">
      <span style="grid-area: a;" on:click={close}
        ><Button color="white" text="Cancel" /></span
      >
      <span style="grid-area: b;" on:click={clear}
        ><Button color="white" text="Clear" disabled={useTypedName} /></span
      >
      <span style="grid-area: c;" on:click={undo}
        ><Button color="white" text="Undo" disabled={useTypedName} /></span
      >
      <div
        class="apply-btn"
        style="grid-area: d;"
        on:click={() => {
          !applySignatureDisabled && applySignature();
        }}
        use:markActive
      >
        <LoadingButton
          disabled={applySignatureDisabled}
          color="secondary"
          text="Apply Signature"
          isErr={showEmptySignature}
          fullWidth
        />
      </div>
    </div>

    <div on:click={close} class="modal-x">
      <i class="fas fa-times" />
    </div>
  </div>
</div>

{#if showEditTextSignatureModal}
  <EditTextSignatureModal
    on:close={() => {
      showEditTextSignatureModal = false;
    }}
    on:signature={handleEditTextSignature}
    title="Edit your text signature"
    placeholder="Type your FULL name..."
  />
{/if}

<style>
  .link {
    color: #32a1ce;
    text-decoration: underline;
    cursor: pointer;
  }
  .textTitle {
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    line-height: 21px;
    letter-spacing: 0.1px;
    color: #4a5158;
  }
  .container {
    display: flex;
    align-items: center;
    justify-content: space-around;
    margin-top: 15px;
  }
  @media only screen and (min-width: 640px) {
    .apply-btn {
      justify-self: center;
    }
  }
  .save-box {
    display: grid;
    grid-template-columns: 1fr;
    place-items: center;
    padding-top: 2rem;
  }

  .modal-buttons {
    display: grid;
    grid-template-areas: "a b c d";
    grid-template-columns: repeat(4, minmax(0, 1fr));
    column-gap: 0.5rem;

    justify-content: center;
    align-items: center;

    padding-top: 0.5rem;
  }
  canvas.bp-signature-pad {
    border: thick double #32a1ce;
  }

  .signature-pad {
    width: 600px;
    height: 150px;
    margin-left: auto;
    margin-right: auto;
    padding-top: 1rem;
  }

  /* .sig-box {
    display: flex;
    justify-content: center;
  } */

  .modal-message {
    text-align: center;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 400;
    font-size: 20px;
    line-height: 30px;
    color: #2a2f34;
  }

  .modal-message.error {
    padding-top: 2rem;
    color: red;
    font-size: 16px;
  }

  .modal-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.3);
  }

  .modal-header {
    margin-block-start: 0;
    margin-block-end: 1rem;
    text-align: center;
    font-family: "Nunito", sans-serif;
    font-style: normal;
    font-weight: 600;
    font-size: 24px;
    line-height: 34px;
    color: #2a2f34;
  }

  .modal {
    position: fixed;
    left: 50%;
    top: 50%;
    width: calc(100vw - 4em);
    max-width: 700px;
    max-height: calc(100vh - 2em);
    overflow: auto;
    transform: translate(-50%, -50%);
    padding: 1em;
    background: #ffffff;
    border-radius: 10px;
  }

  .modal-content {
    padding-left: 1rem;
    padding-right: 1rem;
    display: flex;
    flex-flow: column nowrap;
  }

  .modal-x {
    position: absolute;

    font-size: 24px;
    left: calc(100% - 2em);
    top: 0.85em;

    cursor: pointer;
  }
  @media only screen and (max-width: 767px) {
    .modal-x {
      position: absolute;

      font-size: 24px;
      left: calc(100% - 1em);
      top: 0.5em;

      cursor: pointer;
    }

    .modal {
      position: fixed;
      width: calc(100vw - 28px);
      height: calc(100vh - 64px);
      background: #ffffff;
      z-index: 100;
      overflow-x: hidden;
      overflow-y: auto;
      padding: 0.5rem;
    }

    .modal-buttons {
      bottom: 0px;
      width: 100%;
      /* height: 8rem; */
      display: grid;
      grid-template-areas: "d d d" "a b c";
      grid-template-columns: repeat(3, minmax(0, 1fr));
      /* grid-template-rows: repeat(1, minmax(0, 1fr)); */
      row-gap: 1rem;
    }
    .modal-content {
      padding: 0;
    }
    .modal-header {
      font-size: 18px;
      margin-bottom: 8px;
    }
    .modal-message {
      font-size: 14px;
      line-height: 18px;
    }
    .container {
      gap: 12px;
    }
    .signature-pad {
      width: 100%;
      display: flex;
      justify-content: center;
      height: 210px; /*10px extra for canvas double border line*/
      padding-top: 1rem;
    }
    .sm\:hide {
      display: none;
    }
  }
</style>
