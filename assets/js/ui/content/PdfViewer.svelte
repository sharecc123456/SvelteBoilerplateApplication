<script>
  import { onMount } from "svelte";
  import { createEventDispatcher } from "svelte";

  import Loader from "Components/Loader.svelte";
  import ConfirmationDialog from "../components/ConfirmationDialog.svelte";
  import { showErrorMessage } from "../../helpers/Error";

  const dispatch = createEventDispatcher();

  export let pageNumber = 1;
  export let url = "";
  export let singlePage = true;
  export let lastPage = false;
  export let firstPage = false;
  export let pageCount = 1;
  export let currentPage = 1;
  export let pdfRendered = false;
  export let setItemLoaded = () => {};

  let mounted = false;
  let loaded = false;
  let canvas;
  let thePdf;

  onMount(() => {
    mounted = true;
    if (loaded) {
      initializePdf();
    }
  });

  function pdfJsLoaded() {
    loaded = true;
    if (mounted) {
      initializePdf();
    }
  }

  let showPasswordProtectedWarning = false;
  let isPdfLoadingError = false;
  let errorMessage = "";
  function initializePdf() {
    let pdfjsLib = window["pdfjs-dist/build/pdf"];
    pdfjsLib.GlobalWorkerOptions.workerSrc =
      "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.9.359/pdf.worker.min.js";
    let loadingTask = pdfjsLib.getDocument(url);
    loadingTask.promise
      .then(function (pdf) {
        singlePage = pdf.numPages == 1;
        pageCount = pdf.numPages;
        thePdf = pdf;
        renderPage(pageNumber);
      })
      .catch((error) => {
        pdfRendered = true;
        const { name, message } = error;
        isPdfLoadingError = true;
        // Password Protected PDF Exception handling
        if (name === "PasswordException") {
          showPasswordProtectedWarning = true;
        } else {
          showErrorMessage("pdfRenderError", "generic");
        }
        dispatch("pdfException");
        errorMessage = message;
      });
  }

  function renderPage(no) {
    lastPage = no == thePdf.numPages ? true : false;
    firstPage = no == 1 ? true : false;

    thePdf.getPage(no).then(function (page) {
      let scale = 3;
      let viewport = page.getViewport({ scale: scale });
      let context = canvas.getContext("2d");
      canvas.height = viewport.height;
      canvas.width = viewport.width;

      let renderContext = {
        canvasContext: context,
        viewport: viewport,
      };
      page.render(renderContext);
      pdfRendered = true;
      currentPage = no;
      setItemLoaded(true);
      window.scrollTo(0, 0);
    });
  }

  export function nextPage() {
    if (currentPage >= thePdf.numPages) {
      return;
    }
    pdfRendered = true;
    setItemLoaded(false);
    currentPage++;
    renderPage(currentPage);
  }

  export function prevPage() {
    if (currentPage <= 1) {
      return;
    }
    pdfRendered = true;
    setItemLoaded(false);
    currentPage--;
    renderPage(currentPage);
  }

  export function pageForwarder(pageNumber = 1) {
    pageNumber = Number(pageNumber);
    if (
      typeof pageNumber == "number" &&
      pageNumber &&
      pageNumber <= pageCount &&
      thePdf
    ) {
      pdfRendered = true;
      setItemLoaded(false);
      renderPage(pageNumber);
    }
  }
</script>

<svelte:head>
  <script
    src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.9.359/pdf.min.js"
    on:load={pdfJsLoaded}></script>
</svelte:head>

<div class="container">
  {#if !pdfRendered}
    <Loader loading />
  {/if}
  {#if isPdfLoadingError}
    <div>{errorMessage}</div>
  {:else}
    <canvas class:canvas-wrapper={pdfRendered} bind:this={canvas} />
  {/if}
</div>

{#if showPasswordProtectedWarning}
  <ConfirmationDialog
    title={"Warning"}
    question={`This document cannot be previewed in Boilerplate because it is password protected. To view it, please use the download button and ask the person who sent you the file to provide the password`}
    yesText="Download"
    yesIcon="download"
    noText="Cancel"
    yesColor="secondary"
    noColor="gray"
    on:yes={() => dispatch("downloadFile")}
    on:close={() => {
      showPasswordProtectedWarning = false;
    }}
  />
{/if}

<style>
  .canvas-wrapper {
    border: 1px solid black;
    width: 80%;
  }

  @media only screen and (max-width: 767px) {
    canvas {
      width: 100%;
    }
    .canvas-wrapper {
      width: 100%;
    }
  }
</style>
