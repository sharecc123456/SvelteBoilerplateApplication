import css from "../css/ironforge.scss";
import RequestorPortal from "./ui/RequestorPortal.svelte";
import RecipientCompanyChoice from "./ui/pages/RecipientCompanyChoice.svelte";
import { getEnabledFeatures } from "BoilerplateAPI/Features";

let role = document.getElementById("ironforge-page-role").dataset["role"];
let params = JSON.parse(
  document.getElementById("ironforge-page-params").dataset["params"]
);
console.log(
  `Boilerplate "Ironforge" boot: role=${role} startingHash=${
    window.location.hash
  } params=${JSON.stringify(params)}`
);

let app;
// cache the features
getEnabledFeatures()
  .then((ff) => {
    window.__boilerplate_features = ff;
  })
  .then(() => {
    if (role == "requestor") {
      app = new RequestorPortal({
        target: document.getElementById("ironforge-base-container"),
        props: {
          name: "Svelte + Elixir",
        },
      });
    } else if (role == "requestor_choose") {
      app = new RecipientCompanyChoice({
        target: document.getElementById("ironforge-base-container"),
        props: {
          type: "requestor",
        },
      });
    } else {
      alert(`BLPT \"ironForge\" failed to boot! EBADROLE: ${role}`);
      app = null;
    }

    window.app = app;
  });

export default app;
