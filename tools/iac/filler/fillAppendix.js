import { readFileSync } from "fs";
import { dirname } from "path";
import { fileURLToPath } from "url";
import { jsPDF } from "jspdf";
import "jspdf-autotable";
import { faker } from "@faker-js/faker";

const doFake = false;

const __dirname = dirname(fileURLToPath(import.meta.url));
var args = process.argv.slice(2);
let input_data = {};
let target_file = "appendix.pdf";

if (doFake) {
  const times = 15;
  input_data = {
    checklist_title: "ACORD 125",
    form_title: "Drivers",
    recipient_name: faker.name.fullName(),
    recipient_company: faker.company.name(),
    requestor_name: faker.name.fullName(),
    requestor_company: faker.company.name(),
    submit_date: "2022-08-05 12:00 PM",
    prepare_date: "2022-08-05 12:01 PM",
    form_headers: Array.from({ length: times }, () => faker.word.noun()),
    form_values: Array.from({ length: 50 }, () => {
      return Array.from({ length: times }, () =>
        faker.random.alpha({ count: 4 + Math.floor(Math.random() * 36) })
      );
    }),
  };
} else {
  input_data = JSON.parse(readFileSync(args[0]));
  target_file = args[1];
  console.log(input_data);
}

const doc = new jsPDF("landscape");
var finalY = doc.lastAutoTable.finalY || 10;
var totalPagesExp = "{total_pages_count_string}";
doc.autoTable({
  margin: { top: 40 },
  didDrawPage: function (data) {
    // Header
    doc.setFontSize(20);
    doc.setTextColor(40);
    if (input_data.form_title != "") {
      doc.text(
        `${input_data.checklist_title} - ${input_data.form_title}`,
        data.settings.margin.left,
        22
      );
    } else {
      doc.text(`${input_data.checklist_title}`, data.settings.margin.left, 22);
    }
    doc.setFontSize(10);
    doc.text(
      `${input_data.recipient_name}, ${input_data.recipient_company}`,
      data.settings.margin.left,
      28
    );
    doc.text(
      `Report prepared by: ${input_data.requestor_name}, ${input_data.requestor_company}`,
      data.settings.margin.left,
      32
    );
    if (input_data.submit_date != "N/A") {
      doc.text(
        `Submitted on: ${input_data.submit_date}, prepared on: ${input_data.prepare_date}`,
        data.settings.margin.left,
        36
      );
    } else {
      doc.text(
        `Report prepared on: ${input_data.prepare_date}`,
        data.settings.margin.left,
        36
      );
    }

    // Footer
    var str = "Page " + doc.internal.getNumberOfPages();
    // Total page number plugin only available in jspdf v1.0+
    if (typeof doc.putTotalPages === "function") {
      str = str + " of " + totalPagesExp;
    }
    doc.setFontSize(10);

    // jsPDF 1.4+ uses getWidth, <1.4 uses .width
    var pageSize = doc.internal.pageSize;
    var pageHeight = pageSize.height ? pageSize.height : pageSize.getHeight();
    doc.text(str, data.settings.margin.left, pageHeight - 10);
  },
  head: [input_data.form_headers],
  headStyles: { fillColor: "#4a5158" },
  body: input_data.form_values,
  rowPageBreak: "auto",
  horizontalPageBreak: true,
  horizontalPageBreakRepeat: 0,
});
if (typeof doc.putTotalPages === "function") {
  doc.putTotalPages(totalPagesExp);
}
doc.save(target_file);
console.error(
  `[INFO] Appendix complete, generated as ${target_file}, adding it as a page`
);
