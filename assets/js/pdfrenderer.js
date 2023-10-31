function init() {
  var $canvas = document.getElementById("bp-render-pdf-canvas");
  if ($canvas == null) {
    return;
  }

  var url = $canvas.dataset.target;
  var pdfjsLib = window["pdfjs-dist/build/pdf"];

  // The workerSrc property shall be specified.
  pdfjsLib.GlobalWorkerOptions.workerSrc =
    "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/2.9.359/pdf.worker.min.js";

  var data = fetch(url).then((resp) => resp.arrayBuffer());

  // alert("got my fucking data");
  data
    .then((p) => pdfjsLib.getDocument(p).promise)
    .then(
      (pdf) => {
        // // alert('PDF loaded');

        // // Fetch the first page
        var pageNumber = 1;
        pdf.getPage(pageNumber).then(function (page) {
          console.log("Page loaded");

          var scale = 0.5;
          var viewport = page.getViewport({ scale: scale });

          // Prepare canvas using PDF page dimensions
          var canvas = $canvas;
          var context = canvas.getContext("2d");
          canvas.height = viewport.height;
          canvas.width = viewport.width;

          // Render PDF page into canvas context
          var renderContext = {
            canvasContext: context,
            viewport: viewport,
          };
          var renderTask = page.render(renderContext);
          renderTask.promise.then(function () {
            console.log("Page rendered");
          });
        });
      },
      function (reason) {
        // PDF loading error
        alert("pdfloading: " + reason);
      }
    );
}

var pdfrenderer = {
  init: () => {
    try {
      init();
    } catch (e) {
      // alert("pdfrenderer: " + e.message);
    }
  },
};

export default pdfrenderer;
