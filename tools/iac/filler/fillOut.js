import { PDFDocument, PDFFont, StandardFonts, grayscale, rgb } from "pdf-lib";
import { createWriteStream, writeFile, readFileSync } from "fs";
import { dirname } from "path";
import { fileURLToPath } from "url";
import { execSync } from "child_process";
import handlebars from "handlebars";
import wkhtmltopdf from "wkhtmltopdf";

const __dirname = dirname(fileURLToPath(import.meta.url));

var args = process.argv.slice(2);
var pdftk_binary = process.env.PDFTK_RUN_CMD;

const PDF_LIB_FLATTEN = false;

// Uncompress the PDF
let rawStdin = readFileSync("/dev/stdin");
let output = execSync(
  `${pdftk_binary} - output /tmp/boilerplate-uncompressed.pdf uncompress`,
  {
    input: Buffer.from(rawStdin, "utf-8"),
  }
);

const existingPdfBytes = readFileSync("/tmp/boilerplate-uncompressed.pdf");
const pdfDoc = await PDFDocument.load(existingPdfBytes);
const pages = pdfDoc.getPages();
const firstPage = pages[0];
const { width, height } = firstPage.getSize();

var obj = JSON.parse(readFileSync(args[0]));
var debugSignatures = false;

console.error("[INFO] Work Descriptor Version: %s", obj["version"]);
console.error("[INFO] PDF Page size: W*H: %d * %d", width, height);
const helveticaFont = await pdfDoc.embedFont(StandardFonts.Helvetica);

const logoPdfBytes = readFileSync(__dirname + "/logo.pdf");
const [logoPage] = await pdfDoc.embedPdf(logoPdfBytes, [0]);

var fieldData = [];

function exportHtml(url, file, options) {
  return new Promise((resolve, reject) => {
    wkhtmltopdf(url, options, (err, stream) => {
      if (err) {
        console.error("[ERROR} Rendering Audit Trail: " + err);
        reject(err);
      } else {
        let fsStream = createWriteStream(file);
        fsStream.on("finish", function () {
          resolve();
        });
        stream.on("end", function () {
          fsStream.end();
        });
        stream.pipe(fsStream);
      }
    });
  });
}

function workaroundFlatten(form) {
  const fields = form.getFields();
  for (let i = 0, lenFields = fields.length; i < lenFields; i++) {
    const field = fields[i];
    form.acroForm.removeField(field.acroField);
    form.doc.context.delete(field.ref);
  }
}

function drawTextMultiLine(
  pageNo,
  textToWrite,
  startingFontSize,
  minFontSize,
  pixelWidth,
  pixelHeight,
  topPos,
  leftPos,
  anchorToBottom
) {
  var fontSize = startingFontSize;

  var finalX = Math.floor(width * leftPos);
  var finalY = 0;
  let textHeight = helveticaFont.heightAtSize(fontSize);
  if (anchorToBottom == false) {
    finalY = Math.floor(height * topPos) - textHeight;
  } else {
    finalY = Math.floor(height * topPos) - pixelHeight;
  }

  let words = textToWrite.split(" ");
  let line = "";
  for (const word of words) {
    if (helveticaFont.widthOfTextAtSize(line + word, fontSize) > pixelWidth) {
      pages[pageNo].drawText(line, {
        x: finalX,
        y: finalY,
        size: fontSize,
        lineHeight: textHeight,
      });
      console.error(`[DEBUG/multiline] Drawn line: ${line}`);

      finalY -= textHeight;
      line = "";
    }

    line += word + " ";
  }
  console.error(`[DEBUG/multiline] Final line: ${line}`);

  // draw the final line
  pages[pageNo].drawText(line, {
    x: finalX,
    y: finalY,
    size: fontSize,
    lineHeight: textHeight,
  });
}

function drawText(
  pageNo,
  textToWrite,
  startingFontSize,
  minFontSize,
  pixelWidth,
  pixelHeight,
  topPos,
  leftPos,
  anchorToBottom
) {
  var fontSize = startingFontSize;
  textToWrite = textToWrite.replace(/\r/g, " ");
  textToWrite = textToWrite.replace(/\t/g, " ");
  textToWrite = textToWrite.replace(/\n/g, " ");
  for (fontSize = startingFontSize; fontSize >= minFontSize; fontSize--) {
    if (
      helveticaFont.widthOfTextAtSize(textToWrite, fontSize) < pixelWidth &&
      helveticaFont.heightAtSize(fontSize) < pixelHeight
    ) {
      break;
    }
  }
  var textHeight = helveticaFont.heightAtSize(fontSize);
  if (textHeight >= pixelHeight) {
    fontSize = 6;
  }

  console.error(
    '[DEBUG] Writing "%s" fs %d th %f to t/l %f/%f',
    textToWrite,
    fontSize,
    textHeight,
    topPos,
    leftPos
  );

  var finalX = Math.floor(width * leftPos);
  var finalY = 0;
  if (anchorToBottom == false) {
    finalY = Math.floor(height * topPos) - textHeight;
  } else {
    finalY = Math.floor(height * topPos) - pixelHeight;
  }

  pages[pageNo].drawText(textToWrite, {
    x: finalX,
    y: finalY,
    size: fontSize,
    maxWidth: pixelWidth,
    lineHeight: pixelHeight,
  });

  /* add to verifier */
  fieldData.push({
    type: "text",
    location: {
      x: finalX,
      y: finalY,
    },
    text: textToWrite,
  });
}

function drawSignatureText(
  signatureTimestamp,
  signer,
  signatureId,
  pageNo,
  sigDims,
  sigX,
  sigY
) {
  var textToDraw = `Digitally Signed via Boilerplate on ${signatureTimestamp}: ${signatureId}`;
  let lineStartX = sigX - Math.floor(sigDims.width * 0.1);
  let lineEndX = sigX + Math.floor(sigDims.width * 1.1);
  //drawText(pageNo, textToDraw, 2, 1, Math.abs(lineEndX - lineStartX), pixelHeight, topPos, lineStartX / width, true);
  let textHeight = helveticaFont.heightAtSize(2);
  let defColor = rgb(75 / 255, 173 / 255, 243 / 255);
  let fontSize = 4;

  pages[pageNo].drawRectangle({
    x: sigX,
    y: sigY,
    width: sigDims.width,
    height: sigDims.height,
    borderWidth: 1,
    borderColor: defColor,
    color: defColor,
    opacity: 0,
    borderLineCap: 1,
    borderOpacity: 1,
  });

  // Background
  pages[pageNo].drawRectangle({
    x: sigX,
    y: sigY,
    width: sigDims.width,
    height: sigDims.height,
    color: defColor,
    opacity: 0.25,
  });

  // Thick Left Border
  pages[pageNo].drawRectangle({
    x: sigX,
    y: sigY,
    width: 4,
    height: sigDims.height,
    color: defColor,
    opacity: 1,
  });

  // Draw the text now
  pages[pageNo].drawText("Digitally Signed via Boilerplate", {
    x: sigX + 4,
    y: sigY + sigDims.height - 4,
    size: fontSize,
    color: rgb(0, 0, 0),
  });

  // Draw the signer
  pages[pageNo].drawText(`Signed by ${signer}`, {
    x: sigX + 4,
    y: sigY + 1,
    size: fontSize,
    color: rgb(0, 0, 0),
  });

  // Calculate the place of the Timestamp
  let tsWidth = helveticaFont.widthOfTextAtSize(signatureTimestamp, fontSize);
  pages[pageNo].drawText(signatureTimestamp, {
    x: sigX + sigDims.width - tsWidth,
    y: sigY + sigDims.height - 4,
    size: fontSize,
    color: rgb(0, 0, 0),
  });

  // Calculate the place of the Hash
  let hashWidth = helveticaFont.widthOfTextAtSize(signatureId, fontSize);
  pages[pageNo].drawText(signatureId, {
    x: sigX + sigDims.width - Math.ceil(hashWidth),
    y: sigY + 1,
    size: fontSize,
    color: rgb(0, 0, 0),
  });

  // Add the Boilerplate Logo
  pages[pageNo].drawPage(logoPage, {
    x: sigX + Math.floor(sigDims.width / 2) - Math.ceil(sigDims.height / 2),
    y: sigY,
    width: sigDims.height,
    height: sigDims.height,
    opacity: 0.25,
  });
}

// Flatten the PDF
if (PDF_LIB_FLATTEN) {
  const form = pdfDoc.getForm();
  const fields = form.getFields();
  fields.forEach((field) => {
    const type = field.constructor.name;
    const name = field.getName();
    if (type === "PDFTextField") {
      let tf = form.getTextField(name);
      tf.updateAppearances(helveticaFont);
    }
  });

  form.flatten({
    updateFieldAppearances: true,
  });
}

for (var object of obj["data"]) {
  if (
    object["type"] == "1" ||
    object["type"] == "2" ||
    object["type"] == "3" ||
    object["type"] == "4"
  ) {
    var textToWrite = object["text"];
    if (object["type"] == "2") {
      /* selection */
      if (object["text"] == "true") {
        textToWrite = "X";
      } else {
        continue;
      }
    }

    if (object["type"] == "4") {
      // table
      let success = false;
      if ("appendices" in obj) {
        // find the appendix related to this.
        let apxs = obj["appendices"];
        let label = object["label"];
        for (let apxsIdx = 0; apxsIdx < apxs.length; apxsIdx++) {
          let apx = apxs[apxsIdx];
          if (apx["label"] == label) {
            textToWrite = `See attached: ${apx["reference"]}`;
            success = true;
            break;
          }
        }
      }
      if (!success) {
        textToWrite = "N/A";
      }
    }
    if (textToWrite == null || textToWrite == "") {
      continue;
    }
    var leftPos = object["left"];
    var topPos = object["top"];
    var relWidth = Math.abs(object["width"]);
    var relHeight = Math.abs(object["height"]);
    var pageNo = object["page"];
    var multiline = object["multiline"];
    var pixelWidth = relWidth * width;
    var pixelHeight = relHeight * height;
    topPos = 1 - topPos;
    if (object["type"] == "3") {
      /* signature stuff */
      var dataurl = object["text"];
      /* embed the PNG */
      const jpgImage = await pdfDoc.embedPng(dataurl);
      var currentScale = 1.0;
      /* create a proper buffer */
      let bufferSize = 3 * helveticaFont.heightAtSize(4);
      let bufferCoeff = bufferSize / pixelHeight;
      console.error(`bufferCoeff: ${bufferCoeff}`);
      var boxDims = jpgImage.scaleToFit(pixelWidth, pixelHeight);
      var jpgDims = {
        width: boxDims.width * (1 - bufferCoeff),
        height: boxDims.height * (1 - bufferCoeff),
      };
      var signatureId = object["sighash"];
      var signer = object["signer"];
      var signatureTimestamp = object["sigts"];

      /* should we increase the boxdims? */
      let maxTextWidth = Math.max(
        helveticaFont.widthOfTextAtSize("Digitally Signed via Boilerplate", 4) +
          helveticaFont.widthOfTextAtSize(signatureTimestamp, 4),
        helveticaFont.widthOfTextAtSize(`Signed by ${signer}`, 4) +
          helveticaFont.widthOfTextAtSize(signatureId, 4)
      );
      let goodTextWidth = Math.ceil(maxTextWidth * 1.2);
      if (maxTextWidth > boxDims.width) {
        console.log("Text doesn't fit into Box, fitting box...");
        /* can't fit the text, try growing the width first */
        if (boxDims.width < pixelWidth && goodTextWidth <= pixelWidth) {
          console.log("Box can be expanded in width!");
          boxDims.width = goodTextWidth;
        } else {
          /* not enough space in the field */
        }
      }

      /* try to center based on the available space */
      var finalX = Math.floor(width * leftPos);
      var finalY = Math.floor(height * topPos) - pixelHeight;

      pages[pageNo].drawImage(jpgImage, {
        x: finalX + boxDims.width * (bufferCoeff / 2),
        y: finalY + boxDims.height * (bufferCoeff / 2),
        width: jpgDims.width,
        height: jpgDims.height,
      });

      /* draw the text */
      drawSignatureText(
        signatureTimestamp,
        signer,
        signatureId,
        pageNo,
        boxDims,
        finalX,
        finalY
      );

      if (debugSignatures) {
        pages[pageNo].drawRectangle({
          x: finalX + boxDims.width * (bufferCoeff / 2),
          y: finalY + boxDims.height * (bufferCoeff / 2),
          width: jpgDims.width,
          height: jpgDims.height,
          borderWidth: 1,
          borderColor: rgb(1, 0, 0),
          color: rgb(1, 0, 0),
          opacity: 0,
          borderOpacity: 1,
        });

        pages[pageNo].drawRectangle({
          x: width * leftPos,
          y: height * topPos - pixelHeight,
          width: pixelWidth,
          height: pixelHeight,
          borderWidth: 1,
          borderColor: rgb(0, 1, 0),
          color: rgb(0, 1, 0),
          opacity: 0,
          borderOpacity: 1,
        });
      }

      /* add to verifier */
      fieldData.push({
        type: "signature",
        location: {
          x: finalX + boxDims.width * (bufferCoeff / 2),
          y: finalY + boxDims.height * (bufferCoeff / 2),
        },
        signature_hash: signatureId,
        signature_signer: signer,
        signature_timestamp: signatureTimestamp,
      });
    } else if (object["type"] == "2") {
      // Checkbox
      // Draw two lines from topleft to bottomright and topright to bottomleft
      var finalX = Math.floor(width * leftPos);
      var finalY = Math.floor(height * topPos) - pixelHeight;
      pages[pageNo].drawLine({
        start: { x: finalX, y: finalY },
        end: { x: finalX + pixelWidth, y: finalY + pixelHeight },
        thickness: 1,
        color: rgb(0, 0, 0),
      });

      pages[pageNo].drawLine({
        start: { x: finalX + pixelWidth, y: finalY },
        end: { x: finalX, y: finalY + pixelHeight },
        thickness: 1,
        color: rgb(0, 0, 0),
      });
    } else {
      if (multiline) {
        drawTextMultiLine(
          pageNo,
          textToWrite,
          12,
          8,
          pixelWidth,
          pixelHeight,
          topPos,
          leftPos,
          false
        );
      } else {
        drawText(
          pageNo,
          textToWrite,
          16,
          8,
          pixelWidth,
          pixelHeight,
          topPos,
          leftPos,
          true
        );
      }
    }
  } else {
    console.error("UNKNOWN object.type = " + object["type"]);
  }
}

let verifierData = {
  boilerplate_version: "boilerplate-42",
  filler_version: "1",
  fields: fieldData,
};
let verifierJson = JSON.stringify(verifierData);
let verifierBuffer = Buffer.from(verifierJson, "utf-8");
let verifierString = verifierBuffer.toString("base64");

let shouldSignDocument = process.env.IAC_SIGN_DOCUMENT == "true";

if (shouldSignDocument) {
  // let's sign the buffer now
  let output = execSync(
    "gpg --homedir ~/src/boilerplate/gpg --sign --clear-sign",
    {
      input: verifierBuffer,
    }
  );

  await pdfDoc.attach(output, "__boilerplate_signature", {
    mimeType: "application/vnd.boilerplate.signature",
    description: "Information describing the authenticity of this document",
    creationDate: new Date(),
    modificationDate: new Date(),
  });
}

// Add any and all appendices
if ("appendices" in obj) {
  let apxs = obj["appendices"];
  console.error(`[INFO] Adding ${apxs.length} appendices to the document`);
  for (let apxsIdx = 0; apxsIdx < apxs.length; apxsIdx++) {
    let apx = apxs[apxsIdx]["path"];
    console.error(`[INFO] Adding Appendix ${apxsIdx}: ${apx}`);

    const apxPdfBytes = readFileSync(apx);
    const apxPdfDoc = await PDFDocument.load(apxPdfBytes);
    for (let pageIdx = 0; pageIdx < apxPdfDoc.getPageCount(); pageIdx++) {
      const [apxPage] = await pdfDoc.copyPages(apxPdfDoc, [pageIdx]);
      pdfDoc.addPage(apxPage);
    }
  }
  console.error(`[INFO] Added ${apxs.length} appendices to the document`);
} else {
  console.error(`[INFO] Skipping appendices as the object has no information.`);
}

// Generate the Audit Log as a HTML first
if ("audit_trail" in obj) {
  console.error("[INFO] Generating Audit Trail...");
  let auditLogTemplate = readFileSync(__dirname + "/audit_log.html.hbs");
  const template = handlebars.compile(auditLogTemplate.toString());
  const auditLogHtml = template({ audit_trail: obj["audit_trail"] });
  // write a pdf
  await exportHtml(auditLogHtml, __dirname + "/audit_trail_page.pdf", {
    pageSize: "a4",
  });
  console.error("[INFO] Audit Trail complete, adding it as a page");
  const auditPdfBytes = readFileSync(__dirname + "/audit_trail_page.pdf");
  const auditPdfDoc = await PDFDocument.load(auditPdfBytes);
  const [auditPage] = await pdfDoc.copyPages(auditPdfDoc, [0]);
  pdfDoc.addPage(auditPage);
} else {
  console.error(
    "[INFO] Skipping Audit Trail as the object has no information."
  );
}

const pdfBytes = await pdfDoc.save();

writeFile("/dev/stdout", pdfBytes, (err) => {
  if (err) {
    console.error("[CRITICAL] Error writing to stdout!");
    throw err;
  }
  console.error("[INFO] File written to stdout");
});
